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

    /// The date in a folder name. A second backup in the same minute is named "… 2~reason";
    /// without the trailing number it would not parse, and such a backup was invisible in the
    /// list and therefore never cleared out either.
    static func date(fromFolderPart part: String) -> Date? {
        if let date = formatter.date(from: part) { return date }
        guard let space = part.lastIndex(of: " "), Int(part[part.index(after: space)...]) != nil else { return nil }
        return formatter.date(from: String(part[part.startIndex..<space]))
    }

    static let formatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = folderFormat
        f.locale = Locale(identifier: "en_US_POSIX")
        return f
    }()
}

/// What a restore managed to put back. `failed` names the files that could not be written,
/// which are the ones still holding whatever was in the vault before.
public struct RestoreResult: Equatable, Sendable {
    public let written: Int
    public let failed: [String]

    public var isComplete: Bool { failed.isEmpty }

    public init(written: Int, failed: [String]) {
        self.written = written
        self.failed = failed
    }
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
            guard let date = VaultBackup.date(fromFolderPart: parts[0]) else { return nil }
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
        var skipped: [String] = []
        let wanted = try backedUpPaths()
        for relativePath in wanted {
            let destination = target.appendingPathComponent(relativePath)
            do {
                try fm.createDirectory(at: destination.deletingLastPathComponent(), withIntermediateDirectories: true)
                try? fm.removeItem(at: destination)
                try fm.copyItem(at: url(for: relativePath), to: destination)
            } catch {
                // A file that has just been deleted, or that this device cannot read, must not
                // cost every other note its backup.
                skipped.append(relativePath)
                continue
            }
            if relativePath.lowercased().hasSuffix(".md") { copied += 1 }
        }
        // A backup of nothing is not a backup; better to fail loudly than to leave an empty
        // folder looking like a safe copy.
        if copied == 0, wanted.contains(where: { $0.lowercased().hasSuffix(".md") }) {
            try? fm.removeItem(at: target)
            throw VaultError.backupFailed(skipped.count)
        }
        try signature.write(to: target.appendingPathComponent("signature.txt"), atomically: true, encoding: .utf8)
        if !skipped.isEmpty {
            // Written beside the notes so it is plain, later, what this copy does not hold.
            try? skipped.joined(separator: "\n").write(to: target.appendingPathComponent("skipped.txt"),
                                                       atomically: true, encoding: .utf8)
        }

        // Oldest first out.
        for old in backups().dropFirst(max(limit, 1)) {
            try? fm.removeItem(at: backupsURL.appendingPathComponent(old.folderName))
        }
        return VaultBackup(folderName: name, date: now, noteCount: copied, reason: reason)
    }

    /// Puts the notes from a backup back into the vault, after saving the current state as a
    /// backup of its own. Notes created since the backup are left where they are.
    @discardableResult
    func restore(_ backup: VaultBackup, now: Date = Date()) throws -> RestoreResult {
        let fm = FileManager.default
        let source = backupsURL.appendingPathComponent(backup.folderName, isDirectory: true)
        guard fm.fileExists(atPath: source.path) else { throw VaultError.noteNotFound(backup.folderName) }
        try makeBackup(reason: "before restore", now: now)

        var written = 0
        var failed: [String] = []
        let sourceComponents = source.standardizedFileURL.pathComponents
        guard let walker = fm.enumerator(at: source, includingPropertiesForKeys: [.isRegularFileKey]) else {
            return RestoreResult(written: 0, failed: [])
        }
        for case let fileURL as URL in walker {
            guard (try? fileURL.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile) == true else { continue }
            // From path components, so a symlinked or oddly spelled path cannot turn into a
            // relative path that escapes the vault.
            let components = fileURL.standardizedFileURL.pathComponents
            guard components.count > sourceComponents.count,
                  Array(components.prefix(sourceComponents.count)) == sourceComponents else { continue }
            let relative = components.dropFirst(sourceComponents.count).joined(separator: "/")
            guard relative != "signature.txt", relative != "skipped.txt", !relative.isEmpty else { continue }
            let destination = url(for: relative)
            do {
                try fm.createDirectory(at: destination.deletingLastPathComponent(), withIntermediateDirectories: true)
                try? fm.removeItem(at: destination)
                try fm.copyItem(at: fileURL, to: destination)
                written += 1
            } catch {
                // Half a restore is worse than a reported one: keep going and name the rest.
                failed.append(relative)
            }
        }
        reloadConfig()
        return RestoreResult(written: written, failed: failed)
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
            let values = try? url(for: path).resourceValues(forKeys: [.contentModificationDateKey, .fileSizeKey])
            let stamp = values?.contentModificationDate?.timeIntervalSince1970 ?? 0
            let size = values?.fileSize ?? 0
            return "\(path)@\(stamp)@\(size)"
        }.joined(separator: "\n")
    }
}
