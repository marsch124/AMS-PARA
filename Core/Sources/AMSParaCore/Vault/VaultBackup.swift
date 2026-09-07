import Foundation

/// One saved copy of the vault, kept in `.ams-para/Backups/<yyyy-MM-dd HHmm>`.
/// Plain folders, not archives, so a single note can be dragged back in Finder.
public struct VaultBackup: Identifiable, Equatable, Sendable {
    public var folderName: String
    public var date: Date
    public var noteCount: Int
    /// What triggered it: "sync", "daily", "restore" or "manual".
    public var reason: String

    public var id: String { folderName }

    public static let folderFormat = "yyyy-MM-dd HHmm"

    static let formatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = folderFormat
        f.locale = Locale(identifier: "en_US_POSIX")
        return f
    }()
}

public extension Vault {
    var backupsURL: URL { stateFolderURL.appendingPathComponent("Backups", isDirectory: true) }

    /// Saved copies, newest first.
    func backups() -> [VaultBackup] {
        let fm = FileManager.default
        guard let entries = try? fm.contentsOfDirectory(at: backupsURL, includingPropertiesForKeys: nil) else { return [] }
        return entries.compactMap { url -> VaultBackup? in
            var isDir: ObjCBool = false
            guard fm.fileExists(atPath: url.path, isDirectory: &isDir), isDir.boolValue else { return nil }
            let name = url.lastPathComponent
            let parts = name.split(separator: "~", maxSplits: 1).map(String.init)
            guard let date = VaultBackup.formatter.date(from: parts[0]) else { return nil }
            let count = (fm.enumerator(at: url, includingPropertiesForKeys: nil)?
                .compactMap { $0 as? URL }
                .filter { $0.pathExtension.lowercased() == "md" }
                .count) ?? 0
            return VaultBackup(folderName: name, date: date, noteCount: count,
                               reason: parts.count > 1 ? parts[1] : "manual")
        }
        .sorted { $0.date > $1.date }
    }

    /// Copies every note and the vault's settings into a new backup folder. Returns nil when
    /// nothing changed since the last backup, so repeated syncs do not pile up copies.
    @discardableResult
    func makeBackup(reason: String = "manual", keeping limit: Int = 10, now: Date = Date()) throws -> VaultBackup? {
        let fm = FileManager.default
        let signature = try contentSignature()
        let existing = backups()
        if let last = existing.first,
           let lastSignature = try? String(contentsOf: backupsURL.appendingPathComponent(last.folderName).appendingPathComponent("signature.txt"), encoding: .utf8),
           lastSignature == signature {
            return nil
        }

        var name = "\(VaultBackup.formatter.string(from: now))~\(reason)"
        var target = backupsURL.appendingPathComponent(name, isDirectory: true)
        var n = 2
        while fm.fileExists(atPath: target.path) {
            name = "\(VaultBackup.formatter.string(from: now)) \(n)~\(reason)"
            target = backupsURL.appendingPathComponent(name, isDirectory: true)
            n += 1
        }
        try fm.createDirectory(at: target, withIntermediateDirectories: true)

        var copied = 0
        for relativePath in try backedUpPaths() {
            let destination = target.appendingPathComponent(relativePath)
            try fm.createDirectory(at: destination.deletingLastPathComponent(), withIntermediateDirectories: true)
            try? fm.removeItem(at: destination)
            try fm.copyItem(at: url(for: relativePath), to: destination)
            if relativePath.lowercased().hasSuffix(".md") { copied += 1 }
        }
        try signature.write(to: target.appendingPathComponent("signature.txt"), atomically: true, encoding: .utf8)

        // Oldest first out.
        for old in backups().dropFirst(max(limit, 1)) {
            try? fm.removeItem(at: backupsURL.appendingPathComponent(old.folderName))
        }
        return VaultBackup(folderName: name, date: now, noteCount: copied, reason: reason)
    }

    /// Puts the notes from a backup back into the vault, after saving the current state as a
    /// backup of its own. Notes created since the backup are left where they are.
    /// Returns how many files were written.
    @discardableResult
    func restore(_ backup: VaultBackup, now: Date = Date()) throws -> Int {
        let fm = FileManager.default
        let source = backupsURL.appendingPathComponent(backup.folderName, isDirectory: true)
        guard fm.fileExists(atPath: source.path) else { throw VaultError.noteNotFound(backup.folderName) }
        try makeBackup(reason: "before restore", now: now)

        var written = 0
        guard let walker = fm.enumerator(at: source, includingPropertiesForKeys: [.isRegularFileKey]) else { return 0 }
        for case let fileURL as URL in walker {
            guard (try? fileURL.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile) == true else { continue }
            let relative = fileURL.path.replacingOccurrences(of: source.path + "/", with: "")
            guard relative != "signature.txt" else { continue }
            let destination = url(for: relative)
            try fm.createDirectory(at: destination.deletingLastPathComponent(), withIntermediateDirectories: true)
            try? fm.removeItem(at: destination)
            try fm.copyItem(at: fileURL, to: destination)
            written += 1
        }
        reloadConfig()
        return written
    }

    /// Copies the vault into an empty folder elsewhere, for the sync preview.
    func copyContents(to destination: URL) throws {
        let fm = FileManager.default
        try fm.createDirectory(at: destination, withIntermediateDirectories: true)
        for relativePath in try backedUpPaths() {
            let target = destination.appendingPathComponent(relativePath)
            try fm.createDirectory(at: target.deletingLastPathComponent(), withIntermediateDirectories: true)
            try? fm.removeItem(at: target)
            try fm.copyItem(at: url(for: relativePath), to: target)
        }
    }

    /// Every file worth copying: the notes, the config and the sync state. Backups are skipped.
    private func backedUpPaths() throws -> [String] {
        let fm = FileManager.default
        var paths: [String] = []
        guard let walker = fm.enumerator(at: rootURL, includingPropertiesForKeys: [.isRegularFileKey], options: [.skipsPackageDescendants]) else { return [] }
        for case let fileURL as URL in walker {
            let standardized = fileURL.standardizedFileURL.path
            if standardized.hasPrefix(backupsURL.standardizedFileURL.path) {
                walker.skipDescendants()
                continue
            }
            guard (try? fileURL.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile) == true,
                  let relative = relativePath(for: fileURL) else { continue }
            let ext = fileURL.pathExtension.lowercased()
            guard ext == "md" || ext == "json" || ext == "txt" else { continue }
            paths.append(relative)
        }
        return paths.sorted()
    }

    /// Path and modification date of everything that would be backed up, so an unchanged
    /// vault is not copied twice.
    private func contentSignature() throws -> String {
        try backedUpPaths().map { path in
            let stamp = modificationDate(of: path)?.timeIntervalSince1970 ?? 0
            return "\(path)@\(Int(stamp))"
        }.joined(separator: "\n")
    }
}
