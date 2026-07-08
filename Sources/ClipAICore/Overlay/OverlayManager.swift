import AppKit
import SwiftUI

/// Manages the floating overlay panel that displays AI responses.
///
/// The overlay appears in the bottom-right corner, fades in, and stays visible
/// until the user clicks the close button to dismiss. Text can be scrolled and copied.
/// The panel never activates the application or steals keyboard focus.
final class OverlayManager {

    private var panel: NSPanel?
    private var currentResponseText = ""
    private var displayState: OverlayDisplayState?

    // MARK: - Public Interface

    func show(text: String, isError: Bool = false) {
        if panel == nil {
            createPanel()
        }

        guard let panel = panel else { return }

        currentResponseText = text

        let displayText = text.isEmpty ? "(empty response)" : text
        let state: OverlayDisplayState
        let needsHostingView = displayState == nil || panel.contentView == nil
        if let displayState {
            displayState.update(text: displayText, isError: isError)
            state = displayState
        } else {
            state = OverlayDisplayState(text: displayText, isError: isError)
            displayState = state
        }

        let wasVisible = panel.isVisible

        if needsHostingView {
            let overlayView = OverlayView(
                displayState: state,
                onDismiss: { [weak self] in
                    self?.dismiss()
                },
                onCopy: { [weak self] in
                    self?.copyCurrentEntryIfNeeded()
                }
            )
            let hostingView = configureHostingView(rootView: overlayView)
            panel.contentView = hostingView
        }

        guard let contentView = panel.contentView else { return }
        contentView.layoutSubtreeIfNeeded()
        let contentSize = contentView.fittingSize
        contentView.setFrameSize(contentSize)
        positionPanel(panel, size: contentSize)

        if !wasVisible {
            panel.alphaValue = 0
            panel.orderFront(nil)

            NSAnimationContext.runAnimationGroup { context in
                context.duration = OverlayMetrics.animationDuration
                context.timingFunction = CAMediaTimingFunction(name: .easeOut)
                panel.animator().alphaValue = 1
            }
        } else {
            panel.alphaValue = 0.85
            NSAnimationContext.runAnimationGroup { context in
                context.duration = OverlayMetrics.contentReplaceDuration
                context.timingFunction = CAMediaTimingFunction(name: .easeOut)
                panel.animator().alphaValue = 1
            }
        }
    }

    // MARK: - Private

    private func dismiss() {
        guard let panel = panel, panel.isVisible else { return }

        NSAnimationContext.runAnimationGroup({ context in
            context.duration = OverlayMetrics.animationDuration
            context.timingFunction = CAMediaTimingFunction(name: .easeIn)
            panel.animator().alphaValue = 0
        }, completionHandler: { [weak self] in
            self?.panel?.orderOut(nil)
        })
    }

    private func copyCurrentEntryIfNeeded() {
        guard displayState?.consumeCopyIfNeeded() == true else { return }

        OverlayClipboard.copy(currentResponseText)
        displayState?.markCopied()
    }

    private func configureHostingView<Content: View>(rootView: Content) -> NSHostingView<Content> {
        let hostingView = NSHostingView(rootView: rootView)
        hostingView.wantsLayer = true
        hostingView.layer?.backgroundColor = NSColor.clear.cgColor
        hostingView.layer?.isOpaque = false
        return hostingView
    }

    private func createPanel() {
        let panel = NSPanel(
            contentRect: NSRect(origin: .zero, size: OverlayMetrics.initialPanelSize),
            styleMask: OverlayInteractionPolicy.panelStyleMask,
            backing: .buffered,
            defer: false
        )

        panel.isFloatingPanel = true
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.hidesOnDeactivate = false
        panel.isMovableByWindowBackground = false
        panel.ignoresMouseEvents = OverlayInteractionPolicy.ignoresMouseEvents
        panel.becomesKeyOnlyIfNeeded = OverlayInteractionPolicy.becomesKeyOnlyIfNeeded
        panel.animationBehavior = .utilityWindow

        self.panel = panel
    }

    private func positionPanel(_ panel: NSPanel, size: CGSize) {
        guard let screen = NSScreen.main else { return }

        let visibleFrame = screen.visibleFrame
        let x = visibleFrame.maxX - size.width - OverlayMetrics.screenMargin
        let y = visibleFrame.minY + OverlayMetrics.screenMargin

        panel.setFrame(
            NSRect(x: x, y: y, width: size.width, height: size.height),
            display: true
        )
    }
}
