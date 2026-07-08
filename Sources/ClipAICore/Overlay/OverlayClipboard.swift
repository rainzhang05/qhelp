import AppKit
import Foundation

enum OverlayClipboard {
    /// Copies plain text to the general pasteboard. Returns whether the write succeeded.
    @discardableResult
    static func copy(_ string: String) -> Bool {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()

        pasteboard.setString("true", forType: ClipboardPasteboardTypes.clipAIIgnore)
        return pasteboard.setString(string, forType: .string)
    }
}
