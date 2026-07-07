import Foundation

/// Presents AI responses in the overlay UI.
public protocol OverlayPresenting: AnyObject {
    func show(text: String, isError: Bool)
}

public extension OverlayPresenting {
    func show(text: String) {
        show(text: text, isError: false)
    }
}

extension OverlayManager: OverlayPresenting {}
