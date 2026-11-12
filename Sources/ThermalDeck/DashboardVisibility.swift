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
        private var observers: [NSObjectProtocol] = []

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            removeObservers()
            if let window {
                observe(NSWindow.didChangeOcclusionStateNotification, object: window)
                observe(NSApplication.didBecomeActiveNotification, object: NSApp)
                observe(NSApplication.didResignActiveNotification, object: NSApp)
            }
            report()
        }

        func detach() {
            removeObservers()
            let callback = change
            change = nil
            Task { callback?(false) }
        }

        private func report() {
            // The attachment may occur during a SwiftUI view update.
            Task { [weak self] in
                guard let self else { return }
                let visible = self.window?.occlusionState.contains(.visible) ?? false
                self.change?(visible && NSApp.isActive)
            }
        }

        private func observe(_ name: Notification.Name, object: AnyObject?) {
            let observer = NotificationCenter.default.addObserver(forName: name, object: object, queue: .main) {
                [weak self] _ in MainActor.assumeIsolated { self?.report() }
            }
            observers.append(observer)
        }

        private func removeObservers() {
            for observer in observers { NotificationCenter.default.removeObserver(observer) }
            observers.removeAll()
        }
    }
}
