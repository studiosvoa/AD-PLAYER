import Cocoa

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var mainWindowController: MainWindowController!
    private var previewWindowController: PreviewWindowController!
    private var helpWindowController: HelpWindowController?
    private var settingsDrawer: NSDrawer?
    private var numericFields: [Int: NSTextField] = [:]
    private var settingsAppearancePopup: NSPopUpButton?
    private var settingsAutoAdvanceCheckbox: NSButton?
    private var settingsAutoPlayCheckbox: NSButton?
    private var settingsContinuousModePopup: NSPopUpButton?
    private var numericRanges: [Int: (min: Double, max: Double)] = [:]

    func applicationDidFinishLaunching(_ notification: Notification) {
        let engine = PlaybackEngine()
        applyAppearance(engine.settings.appearance)

        previewWindowController = PreviewWindowController()
        engine.previewView = previewWindowController.previewView

        mainWindowController = MainWindowController(
            engine: engine,
            toggleDisplayMode: { [weak self] in
                self?.previewWindowController.toggleDisplayMode()
            },
            openSettings: { [weak self] in
                self?.showOptions()
            }
        )

        previewWindowController.onDisplayModeChanged = { [weak self] mode in
            self?.mainWindowController.setDisplayModeButtonTitle(forWindowed: mode == .windowed)
        }

        previewWindowController.placeWindow()
        mainWindowController.showWindow(nil)
        mainWindowController.restoreLastPlaylist()
        mainWindowController.window?.makeKeyAndOrderFront(nil)
        installMainMenu()
        showOptions()

        NSApp.activate(ignoringOtherApps: true)

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(screenParametersChanged),
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil
        )
    }

    @objc private func screenParametersChanged() {
        previewWindowController.placeWindow()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }

    private func installMainMenu() {
        let menu = NSMenu()

        let appItem = NSMenuItem(title: "AD-PLAYER", action: nil, keyEquivalent: "")
        let appMenu = NSMenu()
        appMenu.addItem(withTitle: "Quitter AD-PLAYER", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        appItem.submenu = appMenu
        menu.addItem(appItem)

        let settingsItem = NSMenuItem(title: "Réglages…", action: #selector(showOptions), keyEquivalent: "r")
        settingsItem.target = self
        appMenu.addItem(settingsItem)

        let openItem = NSMenuItem(title: "Ouvrir…", action: #selector(MainWindowController.openPlaylistFromMenu), keyEquivalent: "o")
        openItem.target = mainWindowController
        appMenu.addItem(openItem)

        let helpItem = NSMenuItem(title: "Aide", action: #selector(showHelp), keyEquivalent: "")
        helpItem.target = self
        appMenu.addItem(helpItem)

        let windowItem = NSMenuItem()
        let windowMenu = NSMenu(title: "Fenêtre")
        let playlistItem = NSMenuItem(title: "Playlist", action: #selector(showMainWindow), keyEquivalent: "1")
        playlistItem.target = self
        let previewItem = NSMenuItem(title: "Preview", action: #selector(showPreviewWindow), keyEquivalent: "2")
        previewItem.target = self
        windowMenu.addItem(playlistItem)
        windowMenu.addItem(previewItem)
        windowItem.submenu = windowMenu
        menu.addItem(windowItem)

        NSApp.mainMenu = menu
    }

    @objc private func showMainWindow() {
        mainWindowController.showWindow(nil)
        mainWindowController.window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc private func showPreviewWindow() {
        previewWindowController.window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc private func showHelp() {
        if helpWindowController == nil {
            helpWindowController = HelpWindowController()
        }
        helpWindowController?.showWindow(nil)
        helpWindowController?.window?.center()
        helpWindowController?.window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc private func showOptions() {
        if let settingsDrawer = settingsDrawer {
            settingsDrawer.open()
            return
        }

        let settings = mainWindowController.engineSettings
        let titleControl = numericControl(index: 0, value: settings.titleDuration, min: 0.3, max: 5.0, step: 0.1, rangeText: "0,3 à 5,0")
        let blackControl = numericControl(index: 1, value: settings.blackDuration, min: 0.5, max: 2.0, step: 0.1, rangeText: "0,5 à 2,0")
        let fadeControl = numericControl(index: 2, value: settings.fadeDuration, min: 0.0, max: 2.0, step: 0.1, rangeText: "0,0 à 2,0")
        let lufsControl = numericControl(index: 3, value: settings.targetLUFS, min: -25.0, max: -13.0, step: 1.0, rangeText: "-25 à -13")
        let appearancePopup = NSPopUpButton()
        appearancePopup.addItems(withTitles: AppAppearance.allCases.map(\.rawValue))
        appearancePopup.selectItem(withTitle: settings.appearance.rawValue)
        appearancePopup.target = self
        appearancePopup.action = #selector(appearanceChanged(_:))
        let autoAdvanceCheckbox = NSButton(checkboxWithTitle: "Passer automatiquement au clip suivant non lu", target: nil, action: nil)
        autoAdvanceCheckbox.state = settings.autoAdvanceToUnread ? .on : .off
        autoAdvanceCheckbox.target = self
        autoAdvanceCheckbox.action = #selector(autoAdvanceChanged(_:))
        let autoPlayCheckbox = NSButton(checkboxWithTitle: "Lancer automatiquement les clips pour une lecture continue", target: nil, action: nil)
        autoPlayCheckbox.state = settings.autoPlayContinuous ? .on : .off
        autoPlayCheckbox.target = self
        autoPlayCheckbox.action = #selector(autoPlayChanged(_:))
        let continuousModePopup = NSPopUpButton()
        continuousModePopup.addItems(withTitles: ["Ignorer les clips déjà lus", "Lire tous les clips"])
        continuousModePopup.selectItem(at: settings.continuousSkipPlayed ? 0 : 1)
        continuousModePopup.isEnabled = settings.autoPlayContinuous
        continuousModePopup.target = self
        continuousModePopup.action = #selector(continuousModeChanged(_:))
        settingsAppearancePopup = appearancePopup
        settingsAutoAdvanceCheckbox = autoAdvanceCheckbox
        settingsAutoPlayCheckbox = autoPlayCheckbox
        settingsContinuousModePopup = continuousModePopup

        let stack = NSStackView(views: [
            optionRow("Durée du titre", titleControl),
            optionRow("Noir suivant", blackControl),
            optionRow("Cible LUFS", lufsControl),
            optionRow("Fondu au noir", fadeControl),
            optionRow("Style", appearancePopup),
            autoAdvanceCheckbox,
            autoPlayCheckbox,
            optionRow("Mode", continuousModePopup)
        ])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 10
        stack.translatesAutoresizingMaskIntoConstraints = false

        let closeButton = NSButton(title: "Fermer", target: self, action: #selector(settingsAccepted))
        let buttons = NSStackView(views: [closeButton])
        buttons.orientation = .horizontal
        buttons.spacing = 8
        buttons.alignment = .centerY
        buttons.translatesAutoresizingMaskIntoConstraints = false

        let emergencyStopButton = mainWindowController.emergencyStopButton()
        emergencyStopButton.translatesAutoresizingMaskIntoConstraints = false

        let content = NSView(frame: NSRect(x: 0, y: 0, width: 460, height: 390))
        content.addSubview(stack)
        content.addSubview(emergencyStopButton)
        content.addSubview(buttons)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: content.topAnchor, constant: 18),
            stack.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 18),
            stack.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -18),
            emergencyStopButton.topAnchor.constraint(equalTo: stack.bottomAnchor, constant: 28),
            emergencyStopButton.centerXAnchor.constraint(equalTo: content.centerXAnchor),
            emergencyStopButton.widthAnchor.constraint(equalToConstant: 88),
            emergencyStopButton.heightAnchor.constraint(equalToConstant: 72),
            buttons.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -18),
            buttons.topAnchor.constraint(greaterThanOrEqualTo: emergencyStopButton.bottomAnchor, constant: 18),
            buttons.bottomAnchor.constraint(equalTo: content.bottomAnchor, constant: -16)
        ])

        let drawer = NSDrawer(contentSize: NSSize(width: 460, height: 390), preferredEdge: .maxX)
        drawer.contentView = content
        drawer.parentWindow = mainWindowController.window
        settingsDrawer = drawer
        drawer.open()
    }

    private func numericControl(index: Int, value: Double, min: Double, max: Double, step: Double, rangeText: String) -> NSView {
        numericRanges[index] = (min, max)
        let boundedValue = Swift.min(Swift.max(value, min), max)
        let field = NSTextField(string: formatNumericValue(boundedValue))
        field.alignment = .right
        field.widthAnchor.constraint(equalToConstant: 70).isActive = true
        field.tag = index
        field.target = self
        field.action = #selector(numericFieldChanged(_:))
        numericFields[index] = field

        let stepper = NSStepper()
        stepper.doubleValue = boundedValue
        stepper.minValue = min
        stepper.maxValue = max
        stepper.increment = step
        stepper.autorepeat = false
        stepper.valueWraps = false
        stepper.tag = index
        stepper.target = self
        stepper.action = #selector(numericStepperChanged(_:))
        let rangeLabel = NSTextField(labelWithString: rangeText)
        rangeLabel.textColor = .secondaryLabelColor
        let row = NSStackView(views: [field, stepper, rangeLabel])
        row.orientation = .horizontal
        row.spacing = 6
        return row
    }

    @objc private func numericStepperChanged(_ sender: NSStepper) {
        numericFields[sender.tag]?.stringValue = formatNumericValue(sender.doubleValue)
        setNumericSetting(sender.tag, value: sender.doubleValue)
    }

    @objc private func numericFieldChanged(_ sender: NSTextField) {
        let value = boundedNumericValue(sender.tag, sender.doubleValue)
        sender.stringValue = formatNumericValue(value)
        setNumericSetting(sender.tag, value: value)
    }

    private func boundedNumericValue(_ index: Int, _ value: Double) -> Double {
        guard let range = numericRanges[index] else { return value }
        return Swift.min(range.max, Swift.max(range.min, value))
    }

    private func setNumericSetting(_ index: Int, value: Double) {
        let settings = mainWindowController.engineSettings
        switch index {
        case 0: settings.titleDuration = boundedNumericValue(index, value)
        case 1: settings.blackDuration = boundedNumericValue(index, value)
        case 2: settings.fadeDuration = boundedNumericValue(index, value)
        case 3: settings.targetLUFS = boundedNumericValue(index, value)
        default: break
        }
    }

    @objc private func appearanceChanged(_ sender: NSPopUpButton) {
        guard let selected = AppAppearance.allCases.first(where: { $0.rawValue == sender.titleOfSelectedItem }) else { return }
        mainWindowController.engineSettings.appearance = selected
        applyAppearance(selected)
    }

    @objc private func autoAdvanceChanged(_ sender: NSButton) {
        mainWindowController.engineSettings.autoAdvanceToUnread = sender.state == .on
    }

    @objc private func autoPlayChanged(_ sender: NSButton) {
        mainWindowController.engineSettings.autoPlayContinuous = sender.state == .on
        settingsContinuousModePopup?.isEnabled = sender.state == .on
    }

    @objc private func continuousModeChanged(_ sender: NSPopUpButton) {
        mainWindowController.engineSettings.continuousSkipPlayed = sender.indexOfSelectedItem == 0
    }

    private func formatNumericValue(_ value: Double) -> String {
        String(format: "%.1f", value)
    }

    @objc private func settingsAccepted() {
        guard settingsDrawer != nil else { return }
        let settings = mainWindowController.engineSettings
        settings.titleDuration = numericFields[0]?.doubleValue ?? settings.titleDuration
        settings.blackDuration = numericFields[1]?.doubleValue ?? settings.blackDuration
        settings.fadeDuration = numericFields[2]?.doubleValue ?? settings.fadeDuration
        settings.targetLUFS = numericFields[3]?.doubleValue ?? settings.targetLUFS
        settings.autoAdvanceToUnread = settingsAutoAdvanceCheckbox?.state == .on
        settings.autoPlayContinuous = settingsAutoPlayCheckbox?.state == .on
        settings.continuousSkipPlayed = settingsContinuousModePopup?.indexOfSelectedItem == 0
        if let selectedAppearance = AppAppearance.allCases.first(where: { $0.rawValue == settingsAppearancePopup?.titleOfSelectedItem }) {
            settings.appearance = selectedAppearance
            applyAppearance(selectedAppearance)
        }
        closeSettingsPanel()
    }

    @objc private func settingsCancelled() {
        closeSettingsPanel()
    }

    private func closeSettingsPanel() {
        settingsDrawer?.close()
        settingsDrawer = nil
        numericFields.removeAll()
        numericRanges.removeAll()
        settingsAppearancePopup = nil
        settingsAutoAdvanceCheckbox = nil
        settingsAutoPlayCheckbox = nil
        settingsContinuousModePopup = nil
    }

    private func optionRow(_ title: String, _ control: NSView) -> NSView {
        let label = NSTextField(labelWithString: title)
        label.widthAnchor.constraint(equalToConstant: 180).isActive = true
        let row = NSStackView(views: [label, control])
        row.orientation = .horizontal
        row.spacing = 12
        return row
    }

    private func applyAppearance(_ appearance: AppAppearance) {
        switch appearance {
        case .light:
            NSApp.appearance = NSAppearance(named: .aqua)
        case .dark:
            NSApp.appearance = NSAppearance(named: .darkAqua)
        case .system:
            NSApp.appearance = nil
        }
    }
}
