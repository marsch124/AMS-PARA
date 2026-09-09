import Foundation
import AMSParaCore

/// Watches the vault's files in iCloud and says when something arrives.
///
/// Until build 106 the app found out that a note had come down by re-reading the vault every
/// ten seconds, because a file materialising does not change its modification date and nothing
/// else would notice. This is the way macOS means it to be done: a metadata query over the
/// vault's folder reports what iCloud is doing with each file, so the app is told rather than
/// asking. The poll stays as a backstop — a query that never reports (an external folder iCloud
/// declines to index, an old system) must not leave the app blind, and it is cheap.
@MainActor
final class CloudWatcher {
    /// Called when iCloud has changed something in the vault: a file downloaded, added or gone.
    var onChange: (() -> Void)?

    private var query: NSMetadataQuery?
    private var observers: [NSObjectProtocol] = []
    private var lastReport: Date?

    /// Reports no more often than this: a download of many files fires an update per file, and
    /// each report costs a re-read of the vault.
    private static let quietFor: TimeInterval = 2

    func watch(_ root: URL) {
        stop()
        let query = NSMetadataQuery()
        // The vault is a folder the user chose, not the app's own iCloud container, so it is an
        // "external" ubiquitous document as far as the system is concerned.
        query.searchScopes = [NSMetadataQueryAccessibleUbiquitousExternalDocumentsScope,
                              NSMetadataQueryUbiquitousDocumentsScope]
        query.predicate = NSPredicate(format: "%K BEGINSWITH %@", NSMetadataItemPathKey, root.path)
        query.valueListAttributes = [NSMetadataUbiquitousItemDownloadingStatusKey,
                                     NSMetadataUbiquitousItemPercentDownloadedKey]
        for name in [Notification.Name.NSMetadataQueryDidFinishGathering,
                     Notification.Name.NSMetadataQueryDidUpdate] {
            let observer = NotificationCenter.default.addObserver(forName: name, object: query,
                                                                 queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.report() }
            }
            observers.append(observer)
        }
        self.query = query
        query.start()
    }

    func stop() {
        query?.stop()
        query = nil
        observers.forEach(NotificationCenter.default.removeObserver)
        observers = []
        lastReport = nil
    }

    private func report() {
        if let last = lastReport, Date().timeIntervalSince(last) < Self.quietFor { return }
        lastReport = Date()
        onChange?()
    }

}
