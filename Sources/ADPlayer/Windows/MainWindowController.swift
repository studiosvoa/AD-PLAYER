import Cocoa

final class MainWindowController: NSWindowController {
    private let engine: PlaybackEngine
    private let toggleDisplayMode: () -> Void
    private let openSettings: () -> Void

    private var playlist: [PlaylistEntry] = []
    private var visibleIndices: [Int] = []
    private var displayFilterEnabled = false
    private var currentIndex: Int?
    private var latestProgress: Double = 0
    private var loadedFolderURL: URL?
    private var autoRefreshTimer: Timer?
    private var localKeyMonitor: Any?
    private let lastPlaylistURLKey = "ADPlayer.lastPlaylistURL"
    private let playedEntriesKey = "ADPlayer.playedEntries"
    private var playedEntryKeys = Set<String>()
    private var automaticTransitionScheduledForIndex: Int?

    var engineSettings: PlaybackSettings { engine.settings }
    var isTitleCardEnabled: Bool { engine.showsTitleCardBeforePlayback }

    private let tableView = PlaylistTableView()
    private let statusLabel = NSTextField(labelWithString: "Aucun dossier chargé")
    private let refreshButton = NSButton(title: "Refresh", target: nil, action: nil)
    private let autoRefreshCheckbox = NSButton(checkboxWithTitle: "Auto", target: nil, action: nil)
    private let exportButton = NSButton(title: "Export", target: nil, action: nil)
    private let displayModeButton = NSButton(title: "Mode fenêtré", target: nil, action: nil)
    private let clearListButton = NSButton(title: "Clear list", target: nil, action: nil)
    private let clearViewedButton = NSButton(title: "Clear viewed", target: nil, action: nil)
    private let stopButton = NSButton(title: "", target: nil, action: nil)
    private let filterCheckbox = NSButton(checkboxWithTitle: "Filtrer Duos", target: nil, action: nil)
    private let titleCardCheckbox = NSButton(checkboxWithTitle: "Amorce titrée", target: nil, action: nil)
    private let audioTitleCheckbox = NSButton(checkboxWithTitle: "Audio seul compris", target: nil, action: nil)
    private let loudnessCheckbox = NSButton(checkboxWithTitle: "Normaliser le LUFS", target: nil, action: nil)
    private let settingsTabButton = NSButton(title: "", target: nil, action: nil)
    private let emptyListLabel = NSTextField(labelWithString: "Glisser-déposer des médias ou un dossier de médias")

    private static let mediaColumnID = NSUserInterfaceItemIdentifier("media")
    private static let cellID = NSUserInterfaceItemIdentifier("mediaCell")
    private static let playButtonID = NSUserInterfaceItemIdentifier("playButton")
    private static let playedButtonID = NSUserInterfaceItemIdentifier("playedButton")

    init(engine: PlaybackEngine, toggleDisplayMode: @escaping () -> Void, openSettings: @escaping () -> Void) {
        self.engine = engine
        self.toggleDisplayMode = toggleDisplayMode
        self.openSettings = openSettings
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 760, height: 600),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "AD-PLAYER — Playlist"
        window.minSize = NSSize(width: 360, height: 320)
        super.init(window: window)
        engine.delegate = self
        playedEntryKeys = Set(UserDefaults.standard.stringArray(forKey: playedEntriesKey) ?? [])
        buildUI()
        localKeyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard event.keyCode == 53 else { return event }
            self?.stopButtonClicked()
            return nil
        }
    }

    deinit {
        if let localKeyMonitor = localKeyMonitor {
            NSEvent.removeMonitor(localKeyMonitor)
        }
    }

    /// Reflects the preview window's current display mode on the toggle button.
    func setDisplayModeButtonTitle(forWindowed windowed: Bool) {
        displayModeButton.title = windowed ? "Plein écran" : "Mode fenêtré"
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - UI construction

    private func buildUI() {
        guard let window = window else { return }

        let root = RootDropView(frame: window.contentView!.bounds)
        root.autoresizingMask = [.width, .height]
        root.onFolderDropped = { [weak self] url in self?.loadFolder(url) }
        window.contentView = root

        refreshButton.bezelStyle = .rounded
        refreshButton.widthAnchor.constraint(equalToConstant: 140).isActive = true
        refreshButton.target = self
        refreshButton.action = #selector(refreshButtonClicked)
        refreshButton.translatesAutoresizingMaskIntoConstraints = false

        autoRefreshCheckbox.title = "Auto-refresh"
        autoRefreshCheckbox.target = self
        autoRefreshCheckbox.action = #selector(autoRefreshToggled)
        autoRefreshCheckbox.translatesAutoresizingMaskIntoConstraints = false

        exportButton.bezelStyle = .rounded
        exportButton.target = self
        exportButton.action = #selector(exportButtonClicked)
        exportButton.translatesAutoresizingMaskIntoConstraints = false

        displayModeButton.bezelStyle = .rounded
        displayModeButton.target = self
        displayModeButton.action = #selector(displayModeButtonClicked)
        displayModeButton.translatesAutoresizingMaskIntoConstraints = false

        clearListButton.bezelStyle = .rounded
        clearListButton.target = self
        clearListButton.action = #selector(clearListButtonClicked)
        clearListButton.translatesAutoresizingMaskIntoConstraints = false

        clearViewedButton.bezelStyle = .rounded
        clearViewedButton.target = self
        clearViewedButton.action = #selector(clearViewedButtonClicked)
        clearViewedButton.translatesAutoresizingMaskIntoConstraints = false

        stopButton.bezelStyle = .regularSquare
        let stopSymbolConfiguration = NSImage.SymbolConfiguration(pointSize: 28, weight: .bold)
        stopButton.image = NSImage(systemSymbolName: "stop.fill", accessibilityDescription: "Stop")?.withSymbolConfiguration(stopSymbolConfiguration)
        stopButton.imagePosition = .imageOnly
        stopButton.toolTip = "Stop"
        stopButton.controlSize = .large
        stopButton.title = ""
        stopButton.imagePosition = .imageOnly
        stopButton.toolTip = "STOP D’URGENCE (Échap)"
        stopButton.contentTintColor = .systemRed
        stopButton.wantsLayer = true
        stopButton.layer?.borderWidth = 2
        stopButton.layer?.borderColor = NSColor.systemRed.cgColor
        stopButton.layer?.cornerRadius = 0
        stopButton.setButtonType(.momentaryPushIn)
        stopButton.target = self
        stopButton.action = #selector(stopButtonClicked)
        stopButton.translatesAutoresizingMaskIntoConstraints = false

        filterCheckbox.target = self
        filterCheckbox.action = #selector(filterToggled)
        filterCheckbox.translatesAutoresizingMaskIntoConstraints = false

        titleCardCheckbox.target = self
        titleCardCheckbox.action = #selector(titleCardToggled)
        titleCardCheckbox.state = engine.showsTitleCardBeforePlayback ? .on : .off
        titleCardCheckbox.translatesAutoresizingMaskIntoConstraints = false

        audioTitleCheckbox.target = self
        audioTitleCheckbox.action = #selector(audioTitleToggled)
        audioTitleCheckbox.state = engine.settings.showAudioTitle ? .on : .off
        audioTitleCheckbox.isEnabled = engine.showsTitleCardBeforePlayback
        audioTitleCheckbox.translatesAutoresizingMaskIntoConstraints = false

        loudnessCheckbox.target = self
        loudnessCheckbox.action = #selector(loudnessToggled)
        loudnessCheckbox.state = engine.loudnessNormalizationEnabled ? .on : .off
        loudnessCheckbox.translatesAutoresizingMaskIntoConstraints = false

        settingsTabButton.image = NSImage(systemSymbolName: "gearshape", accessibilityDescription: "Réglages")
        settingsTabButton.imagePosition = .imageOnly
        settingsTabButton.bezelStyle = .texturedRounded
        settingsTabButton.toolTip = "Réglages"
        settingsTabButton.target = self
        settingsTabButton.action = #selector(settingsTabClicked)
        settingsTabButton.translatesAutoresizingMaskIntoConstraints = false

        let scrollView = NSScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true

        let column = NSTableColumn(identifier: Self.mediaColumnID)
        column.title = "Média"
        column.width = 400
        tableView.addTableColumn(column)
        tableView.headerView = nil
        tableView.usesAlternatingRowBackgroundColors = false
        tableView.rowHeight = 28
        tableView.dataSource = self
        tableView.delegate = self
        tableView.allowsMultipleSelection = false
        tableView.allowsEmptySelection = true
        tableView.onSpace = { [weak self] in self?.spacePressed() }
        scrollView.documentView = tableView

        statusLabel.translatesAutoresizingMaskIntoConstraints = false
        statusLabel.font = NSFont.systemFont(ofSize: 11)
        statusLabel.textColor = .secondaryLabelColor
        statusLabel.lineBreakMode = .byTruncatingMiddle

        let statusBarSeparator = NSBox()
        statusBarSeparator.boxType = .separator
        statusBarSeparator.translatesAutoresizingMaskIntoConstraints = false

        root.addSubview(refreshButton)
        root.addSubview(autoRefreshCheckbox)
        root.addSubview(exportButton)
        root.addSubview(displayModeButton)
        root.addSubview(clearListButton)
        root.addSubview(clearViewedButton)
        root.addSubview(filterCheckbox)
        root.addSubview(titleCardCheckbox)
        root.addSubview(audioTitleCheckbox)
        root.addSubview(loudnessCheckbox)
        root.addSubview(settingsTabButton)
        root.addSubview(scrollView)
        emptyListLabel.translatesAutoresizingMaskIntoConstraints = false
        emptyListLabel.textColor = .tertiaryLabelColor
        emptyListLabel.alignment = .center
        emptyListLabel.maximumNumberOfLines = 1
        emptyListLabel.font = NSFont.systemFont(ofSize: 13)
        emptyListLabel.isHidden = true
        root.addSubview(emptyListLabel)
        root.addSubview(statusBarSeparator)
        root.addSubview(statusLabel)

        NSLayoutConstraint.activate([
            refreshButton.topAnchor.constraint(equalTo: root.topAnchor, constant: 12),
            refreshButton.leadingAnchor.constraint(equalTo: root.leadingAnchor, constant: 12),

            autoRefreshCheckbox.centerYAnchor.constraint(equalTo: refreshButton.centerYAnchor),
            autoRefreshCheckbox.leadingAnchor.constraint(equalTo: refreshButton.trailingAnchor, constant: 6),

            displayModeButton.centerYAnchor.constraint(equalTo: refreshButton.centerYAnchor),
            displayModeButton.trailingAnchor.constraint(equalTo: root.trailingAnchor, constant: -12),

            exportButton.centerYAnchor.constraint(equalTo: refreshButton.centerYAnchor),
            exportButton.trailingAnchor.constraint(equalTo: displayModeButton.leadingAnchor, constant: -8),

            clearViewedButton.topAnchor.constraint(equalTo: refreshButton.bottomAnchor, constant: 8),
            clearViewedButton.trailingAnchor.constraint(equalTo: root.trailingAnchor, constant: -12),
            clearViewedButton.heightAnchor.constraint(equalToConstant: 36),

            clearListButton.centerYAnchor.constraint(equalTo: clearViewedButton.centerYAnchor),
            clearListButton.trailingAnchor.constraint(equalTo: clearViewedButton.leadingAnchor, constant: -8),

            filterCheckbox.centerYAnchor.constraint(equalTo: clearListButton.centerYAnchor),
            filterCheckbox.leadingAnchor.constraint(equalTo: root.leadingAnchor, constant: 12),

            titleCardCheckbox.centerYAnchor.constraint(equalTo: filterCheckbox.centerYAnchor),
            titleCardCheckbox.leadingAnchor.constraint(equalTo: filterCheckbox.trailingAnchor, constant: 12),

            audioTitleCheckbox.centerYAnchor.constraint(equalTo: titleCardCheckbox.centerYAnchor),
            audioTitleCheckbox.leadingAnchor.constraint(equalTo: titleCardCheckbox.trailingAnchor, constant: 12),

            loudnessCheckbox.centerYAnchor.constraint(equalTo: filterCheckbox.centerYAnchor),
            loudnessCheckbox.leadingAnchor.constraint(equalTo: audioTitleCheckbox.trailingAnchor, constant: 12),

            settingsTabButton.trailingAnchor.constraint(equalTo: root.trailingAnchor),
            settingsTabButton.centerYAnchor.constraint(equalTo: root.centerYAnchor),
            settingsTabButton.widthAnchor.constraint(equalToConstant: 30),
            settingsTabButton.heightAnchor.constraint(equalToConstant: 84),

            scrollView.topAnchor.constraint(equalTo: clearListButton.bottomAnchor, constant: 10),
            scrollView.leadingAnchor.constraint(equalTo: root.leadingAnchor, constant: 12),
            scrollView.trailingAnchor.constraint(equalTo: root.trailingAnchor, constant: -12),
            scrollView.bottomAnchor.constraint(equalTo: statusBarSeparator.topAnchor, constant: -8),

            emptyListLabel.centerXAnchor.constraint(equalTo: scrollView.centerXAnchor),
            emptyListLabel.centerYAnchor.constraint(equalTo: scrollView.centerYAnchor),
            emptyListLabel.widthAnchor.constraint(equalTo: scrollView.widthAnchor, constant: -40),
            emptyListLabel.heightAnchor.constraint(equalToConstant: 22),

            statusBarSeparator.leadingAnchor.constraint(equalTo: root.leadingAnchor),
            statusBarSeparator.trailingAnchor.constraint(equalTo: root.trailingAnchor),
            statusBarSeparator.bottomAnchor.constraint(equalTo: statusLabel.topAnchor, constant: -6),

            statusLabel.leadingAnchor.constraint(equalTo: root.leadingAnchor, constant: 12),
            statusLabel.trailingAnchor.constraint(equalTo: root.trailingAnchor, constant: -12),
            statusLabel.bottomAnchor.constraint(equalTo: root.bottomAnchor, constant: -10)
        ])
    }

    // MARK: - Toggles

    @objc private func displayModeButtonClicked() {
        toggleDisplayMode()
    }

    @objc private func settingsTabClicked() {
        openSettings()
    }

    @objc private func stopButtonClicked() {
        engine.stop()
    }

    func emergencyStopButton() -> NSButton {
        stopButton
    }

    @objc private func clearListButtonClicked() {
        engine.stop()
        playlist.removeAll()
        visibleIndices.removeAll()
        currentIndex = nil
        latestProgress = 0
        loadedFolderURL = nil
        UserDefaults.standard.removeObject(forKey: lastPlaylistURLKey)
        statusLabel.stringValue = "Aucun dossier chargé"
        tableView.reloadData()
        tableView.deselectAll(nil)
        updateEmptyListState()
    }

    @objc private func clearViewedButtonClicked() {
        playedEntryKeys.removeAll()
        UserDefaults.standard.removeObject(forKey: playedEntriesKey)
        tableView.reloadData()
    }

    @objc private func filterToggled() {
        displayFilterEnabled = (filterCheckbox.state == .on)
        recomputeVisibleIndices()
        tableView.reloadData()
        updateEmptyListState()
        if let currentIndex = currentIndex, let visualRow = visibleIndices.firstIndex(of: currentIndex) {
            tableView.selectRowIndexes(IndexSet(integer: visualRow), byExtendingSelection: false)
        }
    }

    @objc private func titleCardToggled() {
        engine.showsTitleCardBeforePlayback = (titleCardCheckbox.state == .on)
        audioTitleCheckbox.isEnabled = titleCardCheckbox.state == .on
        NotificationCenter.default.post(name: .titleCardSettingChanged, object: nil)
    }

    @objc private func audioTitleToggled() {
        engine.settings.showAudioTitle = audioTitleCheckbox.state == .on
    }

    @objc private func loudnessToggled() {
        engine.loudnessNormalizationEnabled = (loudnessCheckbox.state == .on)
    }

    /// Filtered view keeps only paired (red) entries and .jpg/.jpeg images,
    /// hiding plain unpaired video/audio files.
    private func matchesDisplayFilter(_ entry: PlaylistEntry) -> Bool {
        if entry.isPaired { return true }
        if case .single(let item) = entry, item.type == .image { return true }
        return false
    }

    private func recomputeVisibleIndices() {
        visibleIndices = displayFilterEnabled
            ? playlist.indices.filter { matchesDisplayFilter(playlist[$0]) }
            : Array(playlist.indices)
    }

    // MARK: - Folder loading

    @objc func openPlaylistFromMenu() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.prompt = "Ouvrir"
        panel.beginSheetModal(for: window!) { [weak self] response in
            guard response == .OK, let url = panel.url else { return }
            self?.loadFolder(url)
        }
    }

    private func loadFolder(_ url: URL) {
        engine.stop()
        playlist = PlaylistEntry.buildEntries(fromFolder: url)
        recomputeVisibleIndices()
        currentIndex = nil
        latestProgress = 0
        loadedFolderURL = url
        UserDefaults.standard.set(url.path, forKey: lastPlaylistURLKey)
        statusLabel.stringValue = url.path
        tableView.reloadData()
        updateEmptyListState()
    }

    private func updateEmptyListState() {
        emptyListLabel.isHidden = !visibleIndices.isEmpty
    }

    func restoreLastPlaylist() {
        guard let path = UserDefaults.standard.string(forKey: lastPlaylistURLKey) else { return }
        let url = URL(fileURLWithPath: path)
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: path, isDirectory: &isDirectory), isDirectory.boolValue else {
            UserDefaults.standard.removeObject(forKey: lastPlaylistURLKey)
            return
        }
        loadFolder(url)
    }

    // MARK: - Refresh (rescans without interrupting current playback)

    @objc private func refreshButtonClicked() {
        refreshPlaylist()
    }

    @objc private func autoRefreshToggled() {
        if autoRefreshCheckbox.state == .on {
            autoRefreshTimer?.invalidate()
            autoRefreshTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
                self?.refreshPlaylist()
            }
        } else {
            autoRefreshTimer?.invalidate()
            autoRefreshTimer = nil
        }
    }

    /// Rescans the loaded folder and merges new/removed files into the playlist.
    /// Never touches the playback engine's player, only remaps its row index
    /// so an in-progress playback keeps its correct PLAY/STOP icon and ring.
    private func refreshPlaylist() {
        guard let folder = loadedFolderURL else { return }

        let currentKey = currentIndex.flatMap { playlist.indices.contains($0) ? playlist[$0].identityKey : nil }
        let playingKey = engine.playingIndex.flatMap { playlist.indices.contains($0) ? playlist[$0].identityKey : nil }

        let newPlaylist = PlaylistEntry.buildEntries(fromFolder: folder)
        guard newPlaylist.map(\.identityKey) != playlist.map(\.identityKey) else { return }

        playlist = newPlaylist
        recomputeVisibleIndices()
        currentIndex = currentKey.flatMap { key in playlist.firstIndex { $0.identityKey == key } }
        engine.remapPlayingIndex(to: playingKey.flatMap { key in playlist.firstIndex { $0.identityKey == key } })

        tableView.reloadData()
        updateEmptyListState()
        if let currentIndex = currentIndex, let visualRow = visibleIndices.firstIndex(of: currentIndex) {
            tableView.selectRowIndexes(IndexSet(integer: visualRow), byExtendingSelection: false)
        } else {
            tableView.deselectAll(nil)
        }
    }

    // MARK: - Export (paired/red entries -> single .mp4 per entry)

    @objc private func exportButtonClicked() {
        guard playlist.contains(where: { $0.isPaired }) else {
            let alert = NSAlert()
            alert.messageText = "Aucun fichier composé (liseré rouge) à exporter."
            alert.alertStyle = .informational
            alert.beginSheetModal(for: window!)
            return
        }

        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.prompt = "Exporter ici"
        panel.beginSheetModal(for: window!) { [weak self] response in
            guard response == .OK, let folder = panel.url else { return }
            self?.beginExport(to: folder)
        }
    }

    private func beginExport(to folder: URL) {
        exportButton.isEnabled = false
        let restoredStatus = loadedFolderURL?.path ?? statusLabel.stringValue

        PlaylistExporter.exportPairedEntries(
            playlist,
            to: folder,
            loudnessNormalizationEnabled: loudnessCheckbox.state == .on,
            targetLUFS: engine.settings.targetLUFS,
            progress: { [weak self] name, completed, total, error in
                guard let self = self else { return }
                if let error = error {
                    self.statusLabel.stringValue = "Export \(completed)/\(total) — erreur sur \(name) : \(error.localizedDescription)"
                } else {
                    self.statusLabel.stringValue = "Export \(completed)/\(total) — \(name) terminé"
                }
            }, completion: { [weak self] in
                guard let self = self else { return }
                self.exportButton.isEnabled = true
                self.statusLabel.stringValue = restoredStatus
            }
        )
    }

    // MARK: - Playback control

    private func spacePressed() {
        guard let index = currentIndex, playlist.indices.contains(index) else { return }
        engine.toggle(entry: playlist[index], at: index)
    }

    @objc private func playButtonClicked(_ sender: NSButton) {
        let index = sender.tag
        guard playlist.indices.contains(index) else { return }
        if let visualRow = visibleIndices.firstIndex(of: index), tableView.selectedRow != visualRow {
            tableView.selectRowIndexes(IndexSet(integer: visualRow), byExtendingSelection: false)
        }
        engine.toggle(entry: playlist[index], at: index)
    }

    @objc private func playedButtonClicked(_ sender: NSButton) {
        let index = sender.tag
        guard playlist.indices.contains(index) else { return }
        let key = playlist[index].identityKey
        if playedEntryKeys.contains(key) {
            playedEntryKeys.remove(key)
        } else {
            playedEntryKeys.insert(key)
        }
        UserDefaults.standard.set(Array(playedEntryKeys), forKey: playedEntriesKey)
        reloadRow(index)
    }

    private func reloadRow(_ index: Int) {
        guard let visualRow = visibleIndices.firstIndex(of: index) else { return }
        tableView.reloadData(forRowIndexes: IndexSet(integer: visualRow), columnIndexes: IndexSet(integer: 0))
    }
}

// MARK: - NSTableViewDataSource / Delegate

extension MainWindowController: NSTableViewDataSource, NSTableViewDelegate {
    func numberOfRows(in tableView: NSTableView) -> Int {
        visibleIndices.count
    }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let actualIndex = visibleIndices[row]
        let entry = playlist[actualIndex]

        let cell: NSTableCellView
        if let reused = tableView.makeView(withIdentifier: Self.cellID, owner: self) as? NSTableCellView {
            cell = reused
        } else {
            cell = MediaCellView()
            cell.identifier = Self.cellID

            let textField = NSTextField(labelWithString: "")
            textField.translatesAutoresizingMaskIntoConstraints = false
            textField.lineBreakMode = .byTruncatingMiddle
            textField.textColor = .labelColor
            cell.addSubview(textField)
            cell.textField = textField

            let playButton = NSButton(title: "", target: nil, action: nil)
            playButton.identifier = Self.playButtonID
            playButton.translatesAutoresizingMaskIntoConstraints = false
            playButton.bezelStyle = .rounded
            playButton.imagePosition = .imageOnly
            cell.addSubview(playButton)

            let playedButton = NSButton(title: "", target: nil, action: nil)
            playedButton.identifier = Self.playedButtonID
            playedButton.translatesAutoresizingMaskIntoConstraints = false
            playedButton.isBordered = false
            playedButton.imagePosition = .imageOnly
            cell.addSubview(playedButton)

            NSLayoutConstraint.activate([
                textField.leadingAnchor.constraint(equalTo: cell.leadingAnchor, constant: 8),
                textField.centerYAnchor.constraint(equalTo: cell.centerYAnchor),

                playedButton.trailingAnchor.constraint(equalTo: cell.trailingAnchor, constant: -8),
                playedButton.centerYAnchor.constraint(equalTo: cell.centerYAnchor),
                playedButton.widthAnchor.constraint(equalToConstant: 22),

                playButton.trailingAnchor.constraint(equalTo: playedButton.leadingAnchor, constant: -8),
                playButton.centerYAnchor.constraint(equalTo: cell.centerYAnchor),
                playButton.widthAnchor.constraint(equalToConstant: 32),

                textField.trailingAnchor.constraint(lessThanOrEqualTo: playButton.leadingAnchor, constant: -8)
            ])
        }

        cell.textField?.stringValue = entry.displayName

        if let button = cell.subviews.first(where: { $0.identifier == Self.playButtonID }) as? NSButton {
            let isThisRowPlaying = engine.playingIndex == actualIndex && engine.isPlaying
            let isImageEntry: Bool = {
                if case .single(let item) = entry, item.type == .image { return true }
                return false
            }()
            let symbolName: String
            let description: String
            switch (isThisRowPlaying, isImageEntry) {
            case (true, true):
                symbolName = "stop.fill"
                description = "Stop"
            case (true, false):
                symbolName = "pause.fill"
                description = "Pause"
            case (false, _):
                symbolName = "play.fill"
                description = "Play"
            }
            button.image = NSImage(systemSymbolName: symbolName, accessibilityDescription: description)
            button.tag = actualIndex
            button.target = self
            button.action = #selector(playButtonClicked(_:))
        }

        if let playedButton = cell.subviews.first(where: { $0.identifier == Self.playedButtonID }) as? NSButton {
            let played = playedEntryKeys.contains(entry.identityKey)
            playedButton.image = NSImage(
                systemSymbolName: played ? "circle.fill" : "circle",
                accessibilityDescription: played ? "Lu" : "Non lu"
            )
            playedButton.contentTintColor = played ? .systemGreen : .secondaryLabelColor
            playedButton.tag = actualIndex
            playedButton.target = self
            playedButton.action = #selector(playedButtonClicked(_:))
        }

        return cell
    }

    func tableView(_ tableView: NSTableView, rowViewForRow row: Int) -> NSTableRowView? {
        let actualIndex = visibleIndices[row]
        let rowView = HighlightRowView()
        rowView.isCurrent = (actualIndex == currentIndex)
        rowView.isPairedEntry = playlist[actualIndex].isPaired
        rowView.progress = (actualIndex == engine.playingIndex) ? CGFloat(latestProgress) : 0
        return rowView
    }

    func tableViewSelectionDidChange(_ notification: Notification) {
        let previous = currentIndex
        let selectedRow = tableView.selectedRow
        currentIndex = (selectedRow >= 0 && visibleIndices.indices.contains(selectedRow)) ? visibleIndices[selectedRow] : nil
        if let previous = previous { reloadRowView(forPlaylistIndex: previous) }
        if let current = currentIndex { reloadRowView(forPlaylistIndex: current) }
    }

    private func reloadRowView(forPlaylistIndex index: Int) {
        guard let visualRow = visibleIndices.firstIndex(of: index),
              let rowView = tableView.rowView(atRow: visualRow, makeIfNecessary: false) as? HighlightRowView else { return }
        rowView.isCurrent = (index == currentIndex)
    }
}

// MARK: - PlaybackEngineDelegate

extension MainWindowController: PlaybackEngineDelegate {
    func playbackEngine(_ engine: PlaybackEngine, didUpdateIndex index: Int?) {
        if let index = index {
            automaticTransitionScheduledForIndex = nil
            reloadRow(index)
        }
    }

    func playbackEngine(_ engine: PlaybackEngine, didUpdateProgress progress: Double, for index: Int) {
        guard engine.playingIndex == index || progress == 0 else { return }
        latestProgress = progress
        if engine.playingIndex == index {
            engine.previewView?.updateAudioProgress(progress)
        }
        if progress >= 1.0, playlist.indices.contains(index) {
            playedEntryKeys.insert(playlist[index].identityKey)
            UserDefaults.standard.set(Array(playedEntryKeys), forKey: playedEntriesKey)
            reloadRow(index)

            guard automaticTransitionScheduledForIndex != index else { return }
            automaticTransitionScheduledForIndex = index

            let nextIndex: Int?
            if engine.settings.autoPlayContinuous {
                nextIndex = engine.settings.continuousSkipPlayed
                    ? nextUnreadIndex(after: index)
                    : nextSequentialIndex(after: index)
            } else if engine.settings.autoAdvanceToUnread {
                nextIndex = nextUnreadIndex(after: index)
            } else {
                nextIndex = nil
            }
            if let nextIndex = nextIndex, let visualRow = visibleIndices.firstIndex(of: nextIndex) {
                let delay = engine.settings.autoPlayContinuous ? engine.settings.fadeDuration : 0
                DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
                    guard let self = self else { return }
                    self.tableView.selectRowIndexes(IndexSet(integer: visualRow), byExtendingSelection: false)
                    if self.engine.settings.autoPlayContinuous {
                        self.engine.play(entry: self.playlist[nextIndex], at: nextIndex)
                    }
                }
            }
        }
        guard let visualRow = visibleIndices.firstIndex(of: index),
              let rowView = tableView.rowView(atRow: visualRow, makeIfNecessary: false) as? HighlightRowView else { return }
        rowView.progress = CGFloat(progress)
    }

    private func nextUnreadIndex(after index: Int) -> Int? {
        guard let currentVisualIndex = visibleIndices.firstIndex(of: index), !visibleIndices.isEmpty else { return nil }
        let orderedVisualIndices = Array(visibleIndices.dropFirst(currentVisualIndex + 1)) + Array(visibleIndices.prefix(currentVisualIndex + 1))
        let orderedIndices = orderedVisualIndices.filter { $0 != index }
        return orderedIndices.first { !playedEntryKeys.contains(playlist[$0].identityKey) }
    }

    private func nextSequentialIndex(after index: Int) -> Int? {
        guard let currentVisualIndex = visibleIndices.firstIndex(of: index) else { return nil }
        let nextVisualIndex = currentVisualIndex + 1
        guard visibleIndices.indices.contains(nextVisualIndex) else { return nil }
        return visibleIndices[nextVisualIndex]
    }
}
