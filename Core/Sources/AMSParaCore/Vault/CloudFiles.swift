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
}

public extension Vault {
    /// Asks iCloud for every vault file this device does not have yet — notes and templates
    /// alike — and returns their relative paths. Called at launch, when a vault is opened and
    /// every now and then afterwards, because a file written on the Mac reaches the iPhone as
    /// a placeholder and nothing else would ever open it.
    @discardableResult
    func downloadCloudFiles() -> [String] {
        let fm = FileManager.default
        guard let walker = fm.enumerator(at: rootURL,
                                         includingPropertiesForKeys: [.isUbiquitousItemKey, .ubiquitousItemDownloadingStatusKey],
                                         options: [.skipsPackageDescendants]) else { return [] }
        var asked: [String] = []
        for case let fileURL as URL in walker {
            let name = fileURL.lastPathComponent
            // Backups and deleted notes live here and are none of this device's business.
            if name == Vault.stateFolderName {
                walker.skipDescendants()
                continue
            }
            if let real = CloudFiles.realName(ofPlaceholder: name) {
                let parent = fileURL.deletingLastPathComponent()
                CloudFiles.startDownload(parent.appendingPathComponent(real))
                CloudFiles.startDownload(fileURL)
                // From the folder, not the file: the file is not there yet, and a path that
                // does not exist does not resolve to the same place as the vault's own.
                let folder = relativePath(for: parent) ?? ""
                asked.append(folder.isEmpty ? real : "\(folder)/\(real)")
            } else if CloudFiles.isMissing(fileURL) {
                CloudFiles.startDownload(fileURL)
                asked.append(relativePath(for: fileURL) ?? name)
            }
        }
        return asked.sorted()
    }
}
