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

    1. Raccourcis clavier

    Cmd-O       Ouvre le sélecteur de dossier média.
    Cmd-R       Ouvre le tiroir Réglages.
    Échap       Déclenche le STOP d'urgence.
    Espace      Lance, met en pause ou reprend le média sélectionné.
    Cmd-Q       Quitte AD-PLAYER.

    2. Fenêtre Playlist

    La fenêtre Playlist est le centre de contrôle de l'application. Elle liste
    les vidéos, les audios et les images du dossier chargé. Une ligne contient
    le nom du média, un bouton PLAY/PAUSE/STOP et un cercle d'état de lecture.
    La bordure colorée et son remplissage indiquent le média actif et sa durée.

    3. Charger des médias

    Glissez-déposez des fichiers ou un dossier dans la fenêtre Playlist.
    Vous pouvez aussi utiliser Cmd-O. Le dernier dossier utilisé est mémorisé
    et restauré au prochain lancement. Clear list arrête la lecture, vide la
    Playlist et oublie le dernier dossier chargé.

    4. Les deux lignes de commandes

    Première ligne :
    Refresh          Rescanne immédiatement le dossier chargé.
    Auto-refresh     Actualise automatiquement la Playlist lorsque le dossier change.
    Export           Ouvre le choix du dossier de destination, puis exporte
                     chaque duo vidéo/audio en fichier MP4.
    Mode fenêtré     Bascule Preview entre plein écran et fenêtre normale.

    Deuxième ligne :
    Filtrer Duos     Affiche les duos et les images autonomes.
    Amorce titrée    Affiche le nom du média avant une vidéo ou un duo.
    Audio seul compris
                     Autorise le nom des MP3/WAV seuls dans l'amorce.
    Normaliser le LUFS
                     Active la correction de niveau pendant la lecture.
    Clear viewed     Remet tous les cercles verts à l'état non lu.
    Clear list       Vide la Playlist et efface son dossier mémorisé.

    Le gros bouton STOP du tiroir Réglages arrête immédiatement la lecture.
    Il est centré sous les réglages et possède un cadre rouge pour être repéré
    rapidement. Échap déclenche la même commande.

    5. Nommer et utiliser les duos

    Les DUOS sont des fichiers MP4, MOV, WAV et MP3 nommés de manière identique.
    Exemple :
    Groupe 1.mov
    Groupe 1.wav

    Quand ces fichiers sont reconnus par l'application, ils sont considérés
    comme un DUO. Le flux vidéo MOV ou MP4 est projeté et l'audio WAV ou MP3 est
    synchronisé avec la vidéo. Le bouton Export assemble la vidéo et le son en
    un seul fichier MP4, avec correction LUFS si elle est activée.

    Les extensions prises en charge sont MP4, MOV, WAV, MP3, JPG, JPEG et PNG.

    6. Commandes de lecture

    Cliquez sur PLAY pour lancer un média. Le bouton devient PAUSE pendant la
    lecture. Pour une image, il devient STOP. Lancer un autre média arrête le
    précédent avant de commencer le nouveau.

    Le cercle à droite devient vert lorsque le média est lu jusqu'à la fin.
    Cliquez dessus pour le repasser manuellement à l'état non lu.

    Pour un audio seul, Preview affiche une barre de progression horizontale.
    Pour une image ou une vidéo, le fondu visuel suit la valeur réglée dans le
    tiroir Réglages. L'audio suit également une rampe de volume.

    7. Réglages

    Ouvrez le tiroir avec le bouton engrenage situé sur la fenêtre Playlist,
    le menu AD-PLAYER > Réglages… ou Cmd-R. Le bouton Fermer referme le tiroir.
    Le tiroir reste non modal : la Playlist reste utilisable pendant les réglages.

    Durée du titre       Durée de l'amorce, de 0,3 à 5,0 secondes.
    Noir suivant          Durée du noir après le titre, de 0,5 à 2,0 secondes.
    Cible LUFS            Niveau cible, de -25 à -13 LUFS.
    Fondu au noir         Fondu des médias, de 0,0 à 2,0 secondes.
    Style                 Clair, Sombre ou Système.

    Le fondu des titres est fixe à 0,5 seconde. Le réglage Fondu au noir ne
    concerne que les médias et reste indépendant de l'amorce.

    Sélectionner automatiquement le clip non lu suivant sélectionne le prochain
    média non lu sans lancer sa lecture.

    Lancer automatiquement les clips pour une lecture continue enchaîne les
    médias. Le menu Mode permet alors de choisir Ignorer les clips déjà lus ou
    Lire tous les clips. Tous ces réglages sont mémorisés après fermeture.

    8. Fenêtre Preview et export

    Preview s'ouvre par défaut en plein écran. Mode fenêtré conserve l'écran
    courant. Le menu Fenêtre rappelle Playlist ou Preview au premier plan.

    Export ouvre d'abord un sélecteur de dossier. Après validation, un MP4 est
    créé pour chaque duo vidéo/audio dans le dossier choisi. La normalisation
    active est appliquée à l'export.
    """
}
