import UIKit
import SwiftUI
import UniformTypeIdentifiers
import AMSParaCore

/// iOS share extension: takes text or a link from the share sheet and drops it into the App Group outbox.
/// The app files it into the vault the next time it becomes active.
final class ShareViewController: UIViewController {
    static let appGroupID = "group.com.schabbauer.amspara"

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        loadInput { [weak self] text, url in
            guard let self else { return }
            let host = UIHostingController(rootView: ShareCaptureView(initialText: text, url: url,
                                                                       onSave: { [weak self] item in self?.save(item) },
                                                                       onCancel: { [weak self] in self?.cancel() }))
            self.addChild(host)
            host.view.frame = self.view.bounds
            host.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
            self.view.addSubview(host.view)
            host.didMove(toParent: self)
        }
    }

    private func loadInput(completion: @escaping (String, URL?) -> Void) {
        let providers = (extensionContext?.inputItems as? [NSExtensionItem])?.flatMap { $0.attachments ?? [] } ?? []
        var text = ""
        var url: URL?
        let group = DispatchGroup()
        for provider in providers {
            if provider.hasItemConformingToTypeIdentifier(UTType.url.identifier) {
                group.enter()
                provider.loadItem(forTypeIdentifier: UTType.url.identifier) { item, _ in
                    if let u = item as? URL { url = u } else if let d = item as? Data, let u = URL(dataRepresentation: d, relativeTo: nil) { url = u }
                    group.leave()
                }
            } else if provider.hasItemConformingToTypeIdentifier(UTType.plainText.identifier) {
                group.enter()
                provider.loadItem(forTypeIdentifier: UTType.plainText.identifier) { item, _ in
                    if let s = item as? String { text = s } else if let d = item as? Data, let s = String(data: d, encoding: .utf8) { text = s }
                    group.leave()
                }
            }
        }
        group.notify(queue: .main) {
            if text.isEmpty, let title = (self.extensionContext?.inputItems.first as? NSExtensionItem)?.attributedContentText?.string {
                text = title
            }
            completion(text.trimmingCharacters(in: .whitespacesAndNewlines), url)
        }
    }

    private var outboxURL: URL {
        let base = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: Self.appGroupID)
            ?? FileManager.default.temporaryDirectory
        return base.appendingPathComponent("capture-outbox.jsonl")
    }

    private func save(_ item: CaptureItem) {
        do {
            try CaptureOutbox(fileURL: outboxURL).append(item)
            extensionContext?.completeRequest(returningItems: nil)
        } catch {
            extensionContext?.cancelRequest(withError: error)
        }
    }

    private func cancel() {
        extensionContext?.cancelRequest(withError: NSError(domain: "AMSParaShare", code: NSUserCancelledError))
    }
}

struct ShareCaptureView: View {
    @State var text: String
    let url: URL?
    let onSave: (CaptureItem) -> Void
    let onCancel: () -> Void
    @State private var target: CaptureTarget = .inbox
    @State private var asNote = false

    init(initialText: String, url: URL?, onSave: @escaping (CaptureItem) -> Void, onCancel: @escaping () -> Void) {
        _text = State(initialValue: initialText)
        self.url = url
        self.onSave = onSave
        self.onCancel = onCancel
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Text", text: $text, axis: .vertical)
                        .lineLimit(2...8)
                    if let url {
                        Label(url.absoluteString, systemImage: "link")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }
                }
                Section("Save to") {
                    Picker("Save to", selection: $target) {
                        Text("Inbox").tag(CaptureTarget.inbox)
                        Text("Today's note").tag(CaptureTarget.today)
                    }
                    .pickerStyle(.segmented)
                    Toggle("As note, not task", isOn: $asNote)
                }
                Section {
                    Text("Filed into your vault the next time AMS PARA opens. Add >2026-09-10 for a date, !! for priority, #tags as usual.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("AMS PARA")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: onCancel)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        onSave(CaptureItem(text: text.trimmingCharacters(in: .whitespacesAndNewlines), url: url, target: target, asTask: !asNote))
                    }
                    .disabled(text.trimmingCharacters(in: .whitespaces).isEmpty && url == nil)
                }
            }
        }
    }
}
