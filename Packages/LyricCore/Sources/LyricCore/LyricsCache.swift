import Foundation

public protocol LyricsCaching: Sendable {
    func document(forKey key: String) -> LyricsDocument?
    func store(_ document: LyricsDocument, forKey key: String)
    func translations(forKey key: String, language: String) -> [String]?
    func storeTranslations(_ translations: [String], forKey key: String, language: String)
    func remove(forKey key: String)
    func removeAll()
}

/// In-memory cache, mostly for tests and previews.
public final class MemoryLyricsCache: LyricsCaching, @unchecked Sendable {
    private let lock = NSLock()
    private var documents: [String: LyricsDocument] = [:]
    private var translated: [String: [String]] = [:]

    public init() {}

    public func document(forKey key: String) -> LyricsDocument? {
        lock.lock(); defer { lock.unlock() }
        return documents[key]
    }

    public func store(_ document: LyricsDocument, forKey key: String) {
        lock.lock(); defer { lock.unlock() }
        documents[key] = document
    }

    public func translations(forKey key: String, language: String) -> [String]? {
        lock.lock(); defer { lock.unlock() }
        return translated["\(key)#\(language)"]
    }

    public func storeTranslations(_ translations: [String], forKey key: String, language: String) {
        lock.lock(); defer { lock.unlock() }
        translated["\(key)#\(language)"] = translations
    }

    public func remove(forKey key: String) {
        lock.lock(); defer { lock.unlock() }
        documents[key] = nil
        translated = translated.filter { !$0.key.hasPrefix("\(key)#") }
    }

    public func removeAll() {
        lock.lock(); defer { lock.unlock() }
        documents.removeAll()
        translated.removeAll()
    }
}

/// JSON-file cache, one file per song (and one per song+language for translations).
public final class FileLyricsCache: LyricsCaching, @unchecked Sendable {
    public let directory: URL
    private let lock = NSLock()
    private let fileManager = FileManager.default

    public init(directory: URL) {
        self.directory = directory
        try? fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    public func document(forKey key: String) -> LyricsDocument? {
        read(LyricsDocument.self, from: url(prefix: "lyrics", key: key))
    }

    public func store(_ document: LyricsDocument, forKey key: String) {
        write(document, to: url(prefix: "lyrics", key: key))
    }

    public func translations(forKey key: String, language: String) -> [String]? {
        read([String].self, from: url(prefix: "tr-\(language)", key: key))
    }

    public func storeTranslations(_ translations: [String], forKey key: String, language: String) {
        write(translations, to: url(prefix: "tr-\(language)", key: key))
    }

    public func remove(forKey key: String) {
        lock.lock(); defer { lock.unlock() }
        let stem = Self.fileStem(for: key)
        let files = (try? fileManager.contentsOfDirectory(atPath: directory.path)) ?? []
        for file in files where file.hasSuffix("-\(stem).json") {
            try? fileManager.removeItem(at: directory.appendingPathComponent(file))
        }
    }

    public func removeAll() {
        lock.lock(); defer { lock.unlock() }
        let files = (try? fileManager.contentsOfDirectory(atPath: directory.path)) ?? []
        for file in files where file.hasSuffix(".json") {
            try? fileManager.removeItem(at: directory.appendingPathComponent(file))
        }
    }

    /// Total size of cached files, for the Settings screen.
    public func sizeOnDisk() -> Int {
        let files = (try? fileManager.contentsOfDirectory(atPath: directory.path)) ?? []
        return files.reduce(0) { total, file in
            let attrs = try? fileManager.attributesOfItem(atPath: directory.appendingPathComponent(file).path)
            return total + ((attrs?[.size] as? Int) ?? 0)
        }
    }

    // MARK: -

    private func url(prefix: String, key: String) -> URL {
        directory.appendingPathComponent("\(prefix)-\(Self.fileStem(for: key)).json")
    }

    /// FNV-1a 64 over the UTF-8 key, so file names are short, stable and filesystem safe.
    static func fileStem(for key: String) -> String {
        var hash: UInt64 = 0xcbf29ce484222325
        for byte in key.utf8 {
            hash ^= UInt64(byte)
            hash = hash &* 0x100000001b3
        }
        return String(hash, radix: 16)
    }

    private func read<T: Decodable>(_ type: T.Type, from url: URL) -> T? {
        lock.lock(); defer { lock.unlock() }
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(T.self, from: data)
    }

    private func write<T: Encodable>(_ value: T, to url: URL) {
        lock.lock(); defer { lock.unlock() }
        guard let data = try? JSONEncoder().encode(value) else { return }
        try? data.write(to: url, options: .atomic)
    }
}
