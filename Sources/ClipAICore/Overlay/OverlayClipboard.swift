import AppKit
import Foundation

enum OverlayClipboard {
    /// Copies plain text to the general pasteboard. Returns whether the write succeeded.
    @discardableResult
    static func copy(_ string: String) -> Bool {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()

        let markerType = NSPasteboard.PasteboardType("com.clipai.ignore")
        pasteboard.setString("true", forType: markerType)
        return pasteboard.setString(string, forType: .string)
    }
}
