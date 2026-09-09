import Foundation

/// iCloud keeps a file it has not needed yet as a placeholder: nothing but a stub named
/// ".Note.md.icloud" beside where the file belongs. The stub is hidden and does not end in
/// ".md", so every listing in this package walks straight past it and the file looks as if it
/// never arrived. Asking for it is the only way it is ever fetched.
public enum CloudFiles {
    /// The real name behind a placeholder (".Note.md.icloud" → "Note.md"), or nil for an
    /// ordinary file.
    public static func realName(ofPlaceholder name: String) -> String? {
        let suffix = ".icloud"
        guard name.hasPrefix("."), name.hasSuffix(suffix), name.count > suffix.count + 1 else { return nil }
        return String(name.dropFirst().dropLast(suffix.count))
    }

    /// The stub iCloud leaves where a file belongs until it is fetched.
    public static func placeholderURL(for url: URL) -> URL {
        url.deletingLastPathComponent().appendingPathComponent(".\(url.lastPathComponent).icloud")
    }

    /// True when the file is there, even if its contents have not arrived: a placeholder beside
    /// it counts. Everything that decides whether to write a file asks this, or a note or
    /// template that exists but is still on its way would be written over with a fresh one and
    /// the two would collide in iCloud.
    public static func exists(_ url: URL) -> Bool {
        let fm = FileManager.default
        return fm.fileExists(atPath: url.path) || fm.fileExists(atPath: placeholderURL(for: url).path)
    }

    /// True when the file belongs to iCloud and this device does not have its contents.
    public static func isMissing(_ url: URL) -> Bool {
        guard let values = try? url.resourceValues(forKeys: [.isUbiquitousItemKey, .ubiquitousItemDownloadingStatusKey]),
              values.isUbiquitousItem == true,
              let status = values.ubiquitousItemDownloadingStatus else { return false }
        return status != .current
    }

    /// Asks iCloud to fetch the file. Does nothing for a file that is not in iCloud, and
    /// returns without waiting: the download lands some seconds later and the app's own
    /// change check notices it.
    public static func startDownload(_ url: URL) {
        try? FileManager.default.startDownloadingUbiquitousItem(at: url)
    }

    /// Reads a file the way TextEdit does.
    ///
    /// iCloud keeps a file's contents off the device until something asks for them, and a
    /// plain `Data(contentsOf:)` of such a file simply fails — which is why a note opened in
    /// TextEdit while this app called it unreadable and drew an empty vault (build 101).
    /// A coordinated read makes iCloud materialise the file first and waits for it, so it is
    /// used as the second attempt: the fast path stays fast for a file that is already here.
    public static func read(_ url: URL) throws -> Data {
        do {
            return try Data(contentsOf: url)
        } catch let first {
            startDownload(url)
            var data: Data?
            var readError: Error?
            var coordinationError: NSError?
            NSFileCoordinator().coordinate(readingItemAt: url, options: [], error: &coordinationError) { actual in
                do { data = try Data(contentsOf: actual) } catch { readError = error }
            }
            if let data { return data }
            throw readError ?? coordinationError ?? first
        }
    }

    /// Every file under `root` that iCloud has not sent to this device, asked for as it goes.
    /// Free of `Vault` on purpose: the walk touches every file and must be runnable off the
    /// main thread, where an app cannot carry a non-Sendable object (build 101).
    public static func downloadMissing(under root: URL, skipping skipped: String) -> [String] {
        let fm = FileManager.default
        guard let walker = fm.enumerator(at: root,
                                         includingPropertiesForKeys: [.isUbiquitousItemKey, .ubiquitousItemDownloadingStatusKey],
                                         options: [.skipsPackageDescendants]) else { return [] }
        let rootPath = root.standardizedFileURL.resolvingSymlinksInPath().path
        var asked: [String] = []
        func relative(_ url: URL) -> String? {
            let path = url.standardizedFileURL.resolvingSymlinksInPath().path
            let prefix = rootPath.hasSuffix("/") ? rootPath : rootPath + "/"
            guard path.hasPrefix(prefix) else { return nil }
            return String(path.dropFirst(prefix.count))
        }
        for case let fileURL as URL in walker {
            let name = fileURL.lastPathComponent
            if name == skipped {
                walker.skipDescendants()
                continue
            }
            if let real = realName(ofPlaceholder: name) {
                let parent = fileURL.deletingLastPathComponent()
                startDownload(parent.appendingPathComponent(real))
                startDownload(fileURL)
                let folder = relative(parent) ?? ""
                asked.append(folder.isEmpty ? real : "\(folder)/\(real)")
            } else if isMissing(fileURL) {
                startDownload(fileURL)
                asked.append(relative(fileURL) ?? name)
            }
        }
        return asked.sorted()
    }
}

public extension Vault {
    /// Asks iCloud for every vault file this device does not have yet — notes and templates
    /// alike — and returns their relative paths. Called at launch, when a vault is opened and
    /// every now and then afterwards, because a file written on the Mac reaches the iPhone as
    /// a placeholder and nothing else would ever open it.
    @discardableResult
    func downloadCloudFiles() -> [String] {
        // Backups and deleted notes are none of this device's business, so the state folder
        // is skipped.
        CloudFiles.downloadMissing(under: rootURL, skipping: Vault.stateFolderName)
    }
}
