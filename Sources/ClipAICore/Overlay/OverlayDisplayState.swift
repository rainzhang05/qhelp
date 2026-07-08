import SwiftUI

final class OverlayDisplayState: ObservableObject {
    @Published var text: String
    @Published var isError: Bool
    @Published var hasCopied = false

    private var hasCopiedCurrentEntry = false

    init(text: String, isError: Bool) {
        self.text = text
        self.isError = isError
    }

    func update(text: String, isError: Bool) {
        self.text = text
        self.isError = isError
        hasCopied = false
        hasCopiedCurrentEntry = false
    }

    func consumeCopyIfNeeded() -> Bool {
        guard !hasCopiedCurrentEntry else { return false }
        hasCopiedCurrentEntry = true
        return true
    }

    func markCopied() {
        hasCopied = true
    }
}
