import Foundation
@testable import ClipAICore

enum OverlayInteractionTests: TestCase {
    static let name = "OverlayInteractionTests"

    static func run() throws {
        try assertFalse(OverlayInteractionPolicy.hasAutoDismiss)
        try assertFalse(OverlayInteractionPolicy.ignoresMouseEvents)
        try assertFalse(OverlayInteractionPolicy.becomesKeyOnlyIfNeeded)
        try assertTrue(OverlayInteractionPolicy.panelStyleMask.contains(.nonactivatingPanel))

        var dismissed = false
        let view = OverlayView(text: "hello", isError: false, onDismiss: {
            dismissed = true
        })
        view.triggerDismiss()
        try assertTrue(dismissed)

        var copied = false
        let copyView = OverlayView(text: "hello", isError: false, onCopy: {
            copied = true
        })
        copyView.triggerCopy()
        try assertTrue(copied)

        let displayState = OverlayDisplayState(text: "first", isError: false)
        try assertFalse(displayState.hasCopied)
        try assertTrue(displayState.consumeCopyIfNeeded())
        try assertFalse(displayState.consumeCopyIfNeeded())
        displayState.markCopied()
        try assertTrue(displayState.hasCopied)
        displayState.update(text: "second", isError: true)
        try assertEqual(displayState.text, "second")
        try assertTrue(displayState.isError)
        try assertFalse(displayState.hasCopied)
        try assertTrue(displayState.consumeCopyIfNeeded())
    }
}
