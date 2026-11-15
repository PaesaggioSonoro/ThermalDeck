import AppKit
import Observation

@MainActor
final class MenuBarStatusController: NSObject, NSMenuDelegate {
    private let model: AppModel
    private let item: NSStatusItem
    private let showDashboard: () -> Void
    private let showSettings: () -> Void
    private var displayedValues: [String]?

    init(model: AppModel, showDashboard: @escaping () -> Void, showSettings: @escaping () -> Void) {
        self.model = model
        self.showDashboard = showDashboard
        self.showSettings = showSettings
        item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        super.init()
        let menu = NSMenu()
        menu.delegate = self
        menu.autoenablesItems = false
        item.menu = menu
        item.button?.imagePosition = .imageOnly
        refresh()
    }

    private func refresh() {
        let values = withObservationTracking {
            model.menuBarValues
        } onChange: { [weak self] in
            Task { @MainActor in self?.refresh() }
        }
        guard displayedValues != values else { return }
        displayedValues = values
        item.button?.image = MenuBarArtwork.image(values: values)
        item.button?.setAccessibilityLabel(([ThermalDeckApp.displayName] + values).joined(separator: ", "))
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()
        if model.snapshot.simulated { addInformation("Simulation", to: menu) }
        addInformation(model.snapshot.health.label, to: menu)
        for readout in model.preferences.menuBar.readouts {
            addInformation(model.menuBarDescription(readout), to: menu)
        }
        menu.addItem(.separator())
        addInformation("Cooling: " + model.coolingLabel, to: menu)
        addCommand("Use Automatic", action: #selector(useAutomatic), enabled: model.canUseAutomaticCooling, to: menu)
        addCommand("Max Fans", action: #selector(maxFans), enabled: model.canStartMaximumFans, to: menu)
        menu.addItem(.separator())
        addCommand("Open Dashboard", action: #selector(openDashboard), to: menu)
        addCommand("Settings…", action: #selector(openSettings), to: menu)
        menu.addItem(.separator())
        addCommand("Quit " + ThermalDeckApp.displayName, action: #selector(quit), to: menu)
    }

    private func addInformation(_ title: String, to menu: NSMenu) {
        let row = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        row.isEnabled = false
        menu.addItem(row)
    }

    private func addCommand(_ title: String, action: Selector, enabled: Bool = true, to menu: NSMenu) {
        let row = NSMenuItem(title: title, action: action, keyEquivalent: "")
        row.target = self
        row.isEnabled = enabled
        menu.addItem(row)
    }

    @objc private func openDashboard() { showDashboard() }
    @objc private func useAutomatic() { model.useAutomaticCooling() }
    @objc private func maxFans() {
        if model.canStartMaximumFans { model.toggleMaximumFans() }
    }
    @objc private func openSettings() { showSettings() }
    @objc private func quit() { NSApp.terminate(nil) }
}
