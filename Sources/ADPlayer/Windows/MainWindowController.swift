import Cocoa

final class MainWindowController: NSWindowController {
    private let engine: PlaybackEngine
    private let toggleDisplayMode: () -> Void

    private var playlist: [PlaylistEntry] = []
    private var currentIndex: Int?
    private var loadedFolderURL: URL?
    private var autoRefreshTimer: Timer?

    private let tableView = PlaylistTableView()
    private let statusLabel = NSTextField(labelWithString: "Aucun dossier chargé")
    private let openButton = NSButton(title: "OPEN", target: nil, action: nil)
    private let refreshButton = NSButton(title: "Refresh", target: nil, action: nil)
    private let autoRefreshCheckbox = NSButton(checkboxWithTitle: "Auto", target: nil, action: nil)
    private let exportButton = NSButton(title: "Export", target: nil, action: nil)
    private let displayModeButton = NSButton(title: "Mode fenêtré", target: nil, action: nil)

    private static let mediaColumnID = NSUserInterfaceItemIdentifier("media")
    private static let cellID = NSUserInterfaceItemIdentifier("mediaCell")

    init(engine: PlaybackEngine, toggleDisplayMode: @escaping () -> Void) {
        self.engine = engine
        self.toggleDisplayMode = toggleDisplayMode
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 460, height: 600),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "AD-PLAYER — Playlist"
        window.minSize = NSSize(width: 360, height: 320)
        super.init(window: window)
        engine.delegate = self
        buildUI()
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

        openButton.bezelStyle = .rounded
        openButton.target = self
        openButton.action = #selector(openButtonClicked)
        openButton.translatesAutoresizingMaskIntoConstraints = false

        refreshButton.bezelStyle = .rounded
        refreshButton.target = self
        refreshButton.action = #selector(refreshButtonClicked)
        refreshButton.translatesAutoresizingMaskIntoConstraints = false

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

        root.addSubview(openButton)
        root.addSubview(refreshButton)
        root.addSubview(autoRefreshCheckbox)
        root.addSubview(exportButton)
        root.addSubview(displayModeButton)
        root.addSubview(scrollView)
        root.addSubview(statusBarSeparator)
        root.addSubview(statusLabel)

        NSLayoutConstraint.activate([
            openButton.topAnchor.constraint(equalTo: root.topAnchor, constant: 12),
            openButton.leadingAnchor.constraint(equalTo: root.leadingAnchor, constant: 12),

            refreshButton.centerYAnchor.constraint(equalTo: openButton.centerYAnchor),
            refreshButton.leadingAnchor.constraint(equalTo: openButton.trailingAnchor, constant: 8),

            autoRefreshCheckbox.centerYAnchor.constraint(equalTo: openButton.centerYAnchor),
            autoRefreshCheckbox.leadingAnchor.constraint(equalTo: refreshButton.trailingAnchor, constant: 6),

            displayModeButton.centerYAnchor.constraint(equalTo: openButton.centerYAnchor),
            displayModeButton.trailingAnchor.constraint(equalTo: root.trailingAnchor, constant: -12),

            exportButton.centerYAnchor.constraint(equalTo: openButton.centerYAnchor),
            exportButton.trailingAnchor.constraint(equalTo: displayModeButton.leadingAnchor, constant: -8),

            scrollView.topAnchor.constraint(equalTo: openButton.bottomAnchor, constant: 10),
            scrollView.leadingAnchor.constraint(equalTo: root.leadingAnchor, constant: 12),
            scrollView.trailingAnchor.constraint(equalTo: root.trailingAnchor, constant: -12),
            scrollView.bottomAnchor.constraint(equalTo: statusBarSeparator.topAnchor, constant: -8),

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

    // MARK: - Folder loading

    @objc private func openButtonClicked() {
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
        currentIndex = nil
        loadedFolderURL = url
        statusLabel.stringValue = url.path
        tableView.reloadData()
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
        currentIndex = currentKey.flatMap { key in playlist.firstIndex { $0.identityKey == key } }
        engine.remapPlayingIndex(to: playingKey.flatMap { key in playlist.firstIndex { $0.identityKey == key } })

        tableView.reloadData()
        if let currentIndex = currentIndex {
            tableView.selectRowIndexes(IndexSet(integer: currentIndex), byExtendingSelection: false)
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

        PlaylistExporter.exportPairedEntries(playlist, to: folder, progress: { [weak self] name, completed, total, error in
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
        })
    }

    // MARK: - Playback control

    private func spacePressed() {
        guard let index = currentIndex, playlist.indices.contains(index) else { return }
        engine.toggle(entry: playlist[index], at: index)
    }

    @objc private func playButtonClicked(_ sender: NSButton) {
        let index = sender.tag
        guard playlist.indices.contains(index) else { return }
        if tableView.selectedRow != index {
            tableView.selectRowIndexes(IndexSet(integer: index), byExtendingSelection: false)
        }
        engine.toggle(entry: playlist[index], at: index)
    }

    private func reloadRow(_ index: Int) {
        guard playlist.indices.contains(index) else { return }
        tableView.reloadData(forRowIndexes: IndexSet(integer: index), columnIndexes: IndexSet(integer: 0))
    }
}

// MARK: - NSTableViewDataSource / Delegate

extension MainWindowController: NSTableViewDataSource, NSTableViewDelegate {
    func numberOfRows(in tableView: NSTableView) -> Int {
        playlist.count
    }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let entry = playlist[row]

        let cell: NSTableCellView
        if let reused = tableView.makeView(withIdentifier: Self.cellID, owner: self) as? NSTableCellView {
            cell = reused
        } else {
            cell = NSTableCellView()
            cell.identifier = Self.cellID

            let textField = NSTextField(labelWithString: "")
            textField.translatesAutoresizingMaskIntoConstraints = false
            textField.lineBreakMode = .byTruncatingMiddle
            cell.addSubview(textField)
            cell.textField = textField

            let button = NSButton(title: "", target: nil, action: nil)
            button.translatesAutoresizingMaskIntoConstraints = false
            button.bezelStyle = .rounded
            button.imagePosition = .imageOnly
            cell.addSubview(button)

            NSLayoutConstraint.activate([
                textField.leadingAnchor.constraint(equalTo: cell.leadingAnchor, constant: 8),
                textField.centerYAnchor.constraint(equalTo: cell.centerYAnchor),

                button.trailingAnchor.constraint(equalTo: cell.trailingAnchor, constant: -8),
                button.centerYAnchor.constraint(equalTo: cell.centerYAnchor),
                button.widthAnchor.constraint(equalToConstant: 32),

                textField.trailingAnchor.constraint(lessThanOrEqualTo: button.leadingAnchor, constant: -8)
            ])
        }

        cell.textField?.stringValue = entry.displayName

        if let button = cell.subviews.compactMap({ $0 as? NSButton }).first {
            let isThisRowPlaying = engine.playingIndex == row && engine.isPlaying
            let symbolName = isThisRowPlaying ? "stop.fill" : "play.fill"
            let description = isThisRowPlaying ? "Stop" : "Play"
            button.image = NSImage(systemSymbolName: symbolName, accessibilityDescription: description)
            button.tag = row
            button.target = self
            button.action = #selector(playButtonClicked(_:))
        }

        return cell
    }

    func tableView(_ tableView: NSTableView, rowViewForRow row: Int) -> NSTableRowView? {
        let rowView = HighlightRowView()
        rowView.isCurrent = (row == currentIndex)
        rowView.isPairedEntry = playlist[row].isPaired
        return rowView
    }

    func tableViewSelectionDidChange(_ notification: Notification) {
        let previous = currentIndex
        currentIndex = tableView.selectedRow >= 0 ? tableView.selectedRow : nil
        if let previous = previous { reloadRowView(previous) }
        if let current = currentIndex { reloadRowView(current) }
    }

    private func reloadRowView(_ row: Int) {
        guard let rowView = tableView.rowView(atRow: row, makeIfNecessary: false) as? HighlightRowView else { return }
        rowView.isCurrent = (row == currentIndex)
    }
}

// MARK: - PlaybackEngineDelegate

extension MainWindowController: PlaybackEngineDelegate {
    func playbackEngine(_ engine: PlaybackEngine, didUpdateIndex index: Int?) {
        if let index = index {
            reloadRow(index)
        }
    }
}
