import Cocoa

final class HelpWindowController: NSWindowController {
    convenience init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 620, height: 620),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "AD-PLAYER — Mode d'emploi"
        window.minSize = NSSize(width: 480, height: 420)
        self.init(window: window)

        let scrollView = NSScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true

        let textView = NSTextView()
        textView.isEditable = false
        textView.isSelectable = true
        textView.drawsBackground = false
        textView.textContainerInset = NSSize(width: 22, height: 20)
        textView.font = NSFont.systemFont(ofSize: 13)
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        textView.minSize = NSSize(width: 0, height: 0)
        textView.string = Self.manualText
        textView.textStorage?.addAttribute(
            .foregroundColor,
            value: NSColor.labelColor,
            range: NSRange(location: 0, length: textView.string.utf16.count)
        )

        textView.frame = NSRect(x: 0, y: 0, width: 576, height: 1000)
        textView.autoresizingMask = [.width]
        scrollView.documentView = textView
        window.contentView = scrollView
        NSLayoutConstraint.activate([
            scrollView.leadingAnchor.constraint(equalTo: window.contentView!.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: window.contentView!.trailingAnchor),
            scrollView.topAnchor.constraint(equalTo: window.contentView!.topAnchor),
            scrollView.bottomAnchor.constraint(equalTo: window.contentView!.bottomAnchor)
        ])
    }

    private static let manualText = """
    AD-PLAYER — MODE D'EMPLOI

    1. Charger des médias

    Glissez-déposez des fichiers média ou un dossier dans la fenêtre Playlist.
    Le raccourci Cmd-O ouvre le sélecteur de dossier. Le dernier dossier utilisé
    est restauré au prochain lancement.

    Les fichiers vidéo, audio et image sont affichés dans la playlist. Un fichier
    vidéo et son fichier audio associé peuvent être regroupés automatiquement en
    un duo.

    2. Lire un média

    Cliquez sur le bouton PLAY d'une ligne pour lancer sa lecture. Le bouton
    devient PAUSE pendant la lecture. Pour une image, le bouton devient STOP.
    La barre colorée indique la progression du média en cours.

    Le bouton STOP général arrête la lecture et remet l'aperçu au noir.
    La barre d'espace agit sur le média sélectionné.

    3. Suivi des médias

    Le cercle situé à droite de chaque ligne devient vert lorsque le média a été
    lu jusqu'à la fin. Cliquez sur ce cercle pour le remettre à l'état non lu.
    Clear viewed efface tous les états lus. Clear list vide la playlist et oublie
    le dernier dossier chargé.

    4. Filtres et actualisation

    Filtrer Duos affiche uniquement les duos et les images autonomes.
    Auto-refresh surveille le dossier chargé et actualise la playlist.
    Refresh lance une actualisation immédiate.

    5. Réglages

    Ouvrez Réglages depuis le menu AD-PLAYER, ou avec Cmd-R. Le tiroir reste
    utilisable sans bloquer la fenêtre Playlist.

    Amorce titrée affiche le nom avant les vidéos. Afficher le titre des médias
    audio fait de même pour les fichiers MP3 et WAV autonomes.
    Les durées de titre, de noir et de fondu sont réglables. La normalisation
    ajuste le niveau vers la cible LUFS choisie.

    Passer automatiquement au clip suivant non lu sélectionne le prochain média
    non lu sans le lancer. Lancer automatiquement les clips pour une lecture
    continue enchaîne les médias dans l'ordre de la playlist.

    6. Fenêtre Preview

    Preview s'ouvre par défaut en plein écran. Le bouton Mode fenêtré permet de
    basculer vers une fenêtre normale sur le même écran. Le menu Fenêtre permet
    de rappeler Playlist ou Preview au premier plan.

    7. Export

    Export crée un fichier MP4 pour chaque duo vidéo/audio de la playlist, dans
    le dossier choisi. La normalisation active est appliquée à l'export.
    """
}
