import SwiftUI
import AMSParaCore
#if os(macOS)
import AppKit
#else
import UIKit
#endif

/// Turning the map into something you can keep: a PDF that prints and zooms cleanly, a PNG
/// for pasting, or the same tree as indented text.
@MainActor
enum MapExport {
    /// The map drawn at its natural size on white, ready to be rendered off screen.
    private static func renderer(for map: LinkMap) -> ImageRenderer<some View> {
        let layout = MapLayout(map: map, zoom: 1)
        let content = MapCanvas(layout: layout, lit: nil, selectedID: nil, select: { _ in })
            .frame(width: layout.size.width, height: layout.size.height)
            .padding(28)
            .background(Color.white)
        let renderer = ImageRenderer(content: content)
        renderer.scale = 2
        return renderer
    }

    static func pngData(for map: LinkMap) -> Data? {
        let renderer = renderer(for: map)
        #if os(macOS)
        guard let image = renderer.nsImage,
              let tiff = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiff) else { return nil }
        return bitmap.representation(using: .png, properties: [:])
        #else
        return renderer.uiImage?.pngData()
        #endif
    }

    static func pdfData(for map: LinkMap) -> Data? {
        let renderer = renderer(for: map)
        let data = NSMutableData()
        var produced: Data?
        renderer.render { size, draw in
            guard let consumer = CGDataConsumer(data: data) else { return }
            var box = CGRect(origin: .zero, size: size)
            guard let context = CGContext(consumer: consumer, mediaBox: &box, nil) else { return }
            context.beginPDFPage(nil)
            draw(context)
            context.endPDFPage()
            context.closePDF()
            produced = data as Data
        }
        return produced
    }

    /// A suggested file name: "PARAGON map 2026-09-09".
    static func fileName(date: Date = Date()) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return "PARAGON map \(formatter.string(from: date))"
    }

    /// Writes the data into a temporary file, which is what both the save dialog on the Mac
    /// and the share sheet on the phone want.
    static func temporaryFile(_ data: Data, extension ext: String) -> URL? {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("\(fileName()).\(ext)")
        do {
            try data.write(to: url, options: .atomic)
            return url
        } catch {
            return nil
        }
    }

    static func copyToPasteboard(_ text: String) {
        #if os(macOS)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
        #else
        UIPasteboard.general.string = text
        #endif
    }

    static func copyImage(for map: LinkMap) {
        #if os(macOS)
        guard let image = renderer(for: map).nsImage else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.writeObjects([image])
        #else
        guard let image = renderer(for: map).uiImage else { return }
        UIPasteboard.general.image = image
        #endif
    }

    #if os(macOS)
    /// Asks where to put the file and writes it there.
    static func save(_ data: Data, extension ext: String) {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = "\(fileName()).\(ext)"
        panel.canCreateDirectories = true
        panel.begin { response in
            guard response == .OK, let url = panel.url else { return }
            try? data.write(to: url, options: .atomic)
        }
    }
    #endif
}

#if !os(macOS)
/// The phone's share sheet, so an exported map can go wherever the phone can send a file.
struct ShareSheet: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: [url], applicationActivities: nil)
    }

    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}

/// A file waiting to be shared. Identifiable so one `.sheet(item:)` can present it.
struct SharedFile: Identifiable {
    let url: URL
    var id: String { url.path }
}
#endif
