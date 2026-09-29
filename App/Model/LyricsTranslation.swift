import LyricCore
import NaturalLanguage
import SwiftUI
import Translation

/// A batch of lyric lines waiting for Apple's on-device translation.
///
/// The `Translation` framework only hands out a `TranslationSession` inside SwiftUI's `translationTask`
/// modifier (iOS 18), so `AppModel` publishes a job and `TranslationHostView` performs it.
struct TranslationJob: Identifiable, Equatable {
    let id = UUID()
    let trackKey: String
    /// One entry per lyric line, blank for instrumental gaps.
    let lines: [String]
    /// BCP-47 source language, or nil to let the framework detect it.
    let source: String?
    let target: String
}

enum LanguageDetector {
    /// Dominant language of the lyrics mapped onto our supported list, or nil when unsure.
    static func dominantLanguage(of lines: [String]) -> String? {
        let text = lines.filter { !$0.isEmpty }.joined(separator: "\n")
        guard !text.isEmpty else { return nil }
        let recognizer = NLLanguageRecognizer()
        recognizer.processString(text)
        guard let language = recognizer.dominantLanguage, language != .undetermined else { return nil }
        let confidence = recognizer.languageHypotheses(withMaximum: 1)[language] ?? 0
        guard confidence > 0.6 else { return nil }
        return TranslationLanguages.match(identifier: language.rawValue)
    }
}

/// Invisible view that runs pending translation jobs. Mount it once near the root (iOS 18+).
@available(iOS 18.0, *)
struct TranslationHostView: View {
    @EnvironmentObject private var model: AppModel
    @State private var configuration: TranslationSession.Configuration?

    var body: some View {
        Color.clear
            .frame(width: 0, height: 0)
            .translationTask(configuration) { session in
                let job = await MainActor.run { model.translationJob }
                guard let job else { return }
                await run(job, with: session)
            }
            .onChange(of: model.translationJob) { _, job in
                guard let job else {
                    configuration = nil
                    return
                }
                let source = job.source.map { Locale.Language(identifier: $0) }
                let target = Locale.Language(identifier: job.target)
                if configuration?.source == source, configuration?.target == target {
                    configuration?.invalidate()
                } else {
                    configuration = TranslationSession.Configuration(source: source, target: target)
                }
            }
    }

    private func run(_ job: TranslationJob, with session: TranslationSession) async {
        let requests = job.lines.enumerated()
            .filter { !$0.element.isEmpty }
            .map { TranslationSession.Request(sourceText: $0.element, clientIdentifier: String($0.offset)) }

        do {
            let responses = try await session.translations(from: requests)
            var results = [String](repeating: "", count: job.lines.count)
            for response in responses {
                if let identifier = response.clientIdentifier, let index = Int(identifier), results.indices.contains(index) {
                    results[index] = response.targetText
                }
            }
            await MainActor.run { model.finishTranslation(job, results: results) }
        } catch {
            let message = error.localizedDescription
            await MainActor.run { model.failTranslation(job, message: message) }
        }
    }
}
