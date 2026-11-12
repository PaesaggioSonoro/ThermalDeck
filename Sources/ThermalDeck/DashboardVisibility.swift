import AppKit
import SwiftUI

struct DashboardVisibility: NSViewRepresentable {
    let change: @MainActor (Bool) -> Void

    func makeNSView(context: Context) -> Tracker {
        let tracker = Tracker()
        tracker.change = change
        return tracker
    }

    func updateNSView(_ view: Tracker, context: Context) { view.change = change }

    static func dismantleNSView(_ view: Tracker, coordinator: ()) { view.detach() }

    final class Tracker: NSView {
        var change: (@MainActor (Bool) -> Void)?
        private var observer: NSObjectProtocol?

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            removeObserver()
            if let window {
                observer = NotificationCenter.default.addObserver(
                    forName: NSWindow.didChangeOcclusionStateNotification, object: window, queue: .main
                ) { [weak self] _ in
                    MainActor.assumeIsolated { self?.report() }
                }
            }
            report()
        }

        func detach() {
            removeObserver()
            let callback = change
            change = nil
            Task { callback?(false) }
        }

        private func report() {
            // The attachment may occur during a SwiftUI view update.
            Task { [weak self] in
                guard let self else { return }
                self.change?(self.window?.occlusionState.contains(.visible) ?? false)
            }
        }

        private func removeObserver() {
            if let observer { NotificationCenter.default.removeObserver(observer) }
            observer = nil
        }
    }
}
