import Cocoa
import WebKit

final class HelpWindowController: NSWindowController {
    private var webView: WKWebView?

    convenience init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 620, height: 620),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "AD Player 26.09 — Mode d'emploi"
        window.minSize = NSSize(width: 480, height: 420)
        self.init(window: window)

        let contentView = NSView()
        contentView.translatesAutoresizingMaskIntoConstraints = false

        let webView = WKWebView()
        self.webView = webView
        webView.translatesAutoresizingMaskIntoConstraints = false
        if let html = try? String(contentsOf: Self.helpURL, encoding: .utf8) {
            webView.loadHTMLString(html, baseURL: nil)
        } else {
            webView.loadHTMLString(Self.fallbackHTML, baseURL: nil)
        }
        contentView.addSubview(webView)
        window.contentView = contentView
        NSLayoutConstraint.activate([
            webView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            webView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            webView.topAnchor.constraint(equalTo: contentView.topAnchor),
            webView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor)
        ])

    }

    private static let manualText = """
    AD-PLAYER — BIENVENUE

    AD-PLAYER est un lecteur de playlist pensé pour enchaîner simplement des
    vidéos, des sons et des images. Cette page vous accompagne dans les gestes
    essentiels. Les commandes sont regroupées par usage, afin de retrouver
    rapidement ce dont vous avez besoin.

    RACCOURCIS

    Cmd-O       Choisir un dossier ou un ou plusieurs fichiers de médias.
    Cmd-R       Ouvrir le tiroir Réglages.
    Échap       Arrêter immédiatement la lecture.
    Espace      Lire, mettre en pause ou reprendre la ligne sélectionnée.
    Cmd-Q       Quitter l'application.

    LA PLAYLIST

    La fenêtre Playlist rassemble les médias du dossier actuellement chargé.
    Chaque ligne affiche un nom, un bouton de lecture et un cercle de suivi.
    La bordure colorée accompagne le média actif; son remplissage indique sa
    progression. Un seul média est lu à la fois : lancer une autre ligne arrête
    la précédente avant de démarrer la nouvelle.

    CHARGER UN DOSSIER

    Déposez un dossier ou des fichiers directement dans la Playlist. Vous pouvez
    aussi utiliser Cmd-O. Les fichiers MP4, MOV, WAV, MP3, JPG, JPEG et PNG sont
    acceptés. Le dernier dossier utilisé est mémorisé et restauré au prochain
    lancement. Si aucun dossier n'est chargé, déposez simplement vos médias.

    LES COMMANDES DE LA PLAYLIST

    Première ligne :
    Refresh          Relire immédiatement le contenu du dossier.
    Auto-refresh     Surveiller le dossier et actualiser la liste automatiquement.
    Export           Choisir un dossier puis créer les fichiers MP4 exportés.
    Mode fenêtré     Passer Preview du plein écran à une fenêtre normale.

    Deuxième ligne :
    Filtrer Duos     N'afficher que les duos et les images autonomes.
    Amorce titrée    Afficher le nom avant le démarrage d'une vidéo ou d'un duo.
    Audio seul compris
                     Autoriser le nom des WAV/MP3 seuls dans l'amorce.
    Normaliser le LUFS
                     Activer la correction de niveau pendant la lecture et l'export.
    Clear viewed     Effacer tous les cercles verts, sans supprimer la liste.
    Clear list       Arrêter la lecture, vider la liste et oublier le dossier.
    Suppr / Delete   Retirer le média sélectionné; l'icône poubelle fait de même.

    Le gros bouton STOP, placé dans le tiroir Réglages, arrête immédiatement
    le média en cours et remet Preview au noir. Échap déclenche la même action.

    LES DUOS

    Un duo associe une vidéo et son fichier audio séparé. Pour qu'ils soient
    reconnus, les deux fichiers doivent partager exactement le même nom de base :

    Groupe 1.mov
    Groupe 1.wav

    Les extensions vidéo acceptées sont MOV et MP4; les extensions audio sont
    WAV et MP3. La vidéo est projetée, tandis que l'audio séparé est synchronisé
    avec elle. Un duo apparaît comme une seule ligne dans la Playlist.

    Avec Export, AD-PLAYER assemble la vidéo et l'audio dans un fichier MP4.
    La correction LUFS choisie est appliquée si Normaliser le LUFS est activé.

    LECTURE ET SUIVI

    Cliquez sur PLAY pour lancer un média. Le bouton devient PAUSE pendant la
    lecture. Pour une image, il devient STOP. Le cercle situé à droite devient
    vert lorsque le média arrive à sa fin. Cliquez sur le cercle pour le remettre
    à l'état non lu; Clear viewed les remet tous à zéro.

    Pour un audio seul, Preview affiche une barre de progression. Pour une image
    ou une vidéo, le fondu suit la valeur choisie dans Réglages, et le son suit
    la même transition. Les images PNG, JPG et JPEG sont acceptées.

    LE TIROIR RÉGLAGES

    Ouvrez-le avec le bouton engrenage de la Playlist, AD-PLAYER > Réglages…
    ou Cmd-R. Il reste non modal : vous pouvez continuer à utiliser la Playlist.
    Fermer referme le tiroir.

    Durée du titre       Durée de l'amorce, de 0,3 à 5,0 secondes.
    Noir suivant          Durée du noir après l'amorce, de 0,5 à 2,0 secondes.
    Cible LUFS            Niveau visé, de -25 à -13 LUFS.
    Fondu au noir         Fondu des médias, de 0,0 à 2,0 secondes.
    Style                 Clair, Sombre ou Système.

    Le fondu des titres est fixe à 0,5 seconde. Le réglage Fondu au noir ne
    change que le fondu des médias. Les réglages sont mémorisés après fermeture.

    Sélectionner automatiquement le clip non lu suivant sélectionne le prochain
    clip non lu, sans démarrer sa lecture. Lancer automatiquement les clips pour
    une lecture continue enchaîne les médias. Vous pouvez alors choisir Ignorer
    les clips déjà lus ou Lire tous les clips.

    PREVIEW ET EXPORT

    Preview s'ouvre par défaut en plein écran. Mode fenêtré conserve l'écran
    utilisé. Le menu Fenêtre permet de rappeler Playlist ou Preview au premier
    plan.

    Export ouvre un sélecteur de destination qui permet de créer un dossier.
    L'application avertit avant de remplacer un fichier existant. Le niveau
    LUFS choisi est appliqué à l'export lorsque Normaliser le LUFS est activé.

    À PROPOS DE CETTE AIDE

    Cette première version est volontairement simple. Elle sera transformée
    en guide à sections cliquables, avec une table des matières et des liens
    vers les explications détaillées.
    """

    private static var helpURL: URL {
        Bundle.main.url(forResource: "Help", withExtension: "html") ?? URL(fileURLWithPath: "/dev/null")
    }

    private static let fallbackHTML = """
    <!doctype html><html lang="fr"><meta charset="utf-8"><body>
    <h1>AD-PLAYER - Mode d'emploi</h1>
    <p>Le fichier Help.html est introuvable à côté de l'application.</p>
    </body></html>
    """
}
