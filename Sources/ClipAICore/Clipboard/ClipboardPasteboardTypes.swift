import AppKit

enum ClipboardPasteboardTypes {
    static let clipAIIgnore = NSPasteboard.PasteboardType("com.clipai.ignore")
    static let heic = NSPasteboard.PasteboardType("public.heic")
    static let heif = NSPasteboard.PasteboardType("public.heif")
    static let jpeg = NSPasteboard.PasteboardType("public.jpeg")
}
