import ActivityKit
import Foundation

/// Owns the single lyrics Live Activity. Updates are chained so they can never be applied out of order.
@MainActor
final class LiveActivityManager {
    private var activity: Activity<LyricActivityAttributes>?
    private var chain: Task<Void, Never>?

    init() {
        activity = Activity<LyricActivityAttributes>.activities.first
    }

    var areActivitiesEnabled: Bool {
        ActivityAuthorizationInfo().areActivitiesEnabled
    }

    var isRunning: Bool { activity != nil }

    /// Starts the activity if needed, otherwise updates it. Starting only works while the app is in the foreground;
    /// if it fails we simply try again on the next update.
    func show(_ state: LyricActivityAttributes.ContentState) {
        guard areActivitiesEnabled else { return }
        enqueue { [weak self] in
            guard let self else { return }
            let content = ActivityContent(state: state, staleDate: nil)
            if let activity = self.activity, activity.activityState == .active {
                await activity.update(content)
            } else {
                self.activity = nil
                do {
                    self.activity = try Activity.request(
                        attributes: LyricActivityAttributes(startedAt: Date()),
                        content: content,
                        pushType: nil
                    )
                } catch {
                    // Not allowed right now (background, disabled or too many activities).
                }
            }
        }
    }

    func end() {
        enqueue { [weak self] in
            guard let self else { return }
            for running in Activity<LyricActivityAttributes>.activities {
                await running.end(nil, dismissalPolicy: .immediate)
            }
            self.activity = nil
        }
    }

    private func enqueue(_ work: @escaping @MainActor () async -> Void) {
        let previous = chain
        chain = Task { @MainActor in
            await previous?.value
            await work()
        }
    }
}
