# DodoTidy - Nettoyeur Système macOS

<p align="center">
  <img src="dodotidy.png" alt="DodoTidy Logo" width="150">
</p>

Une application macOS native pour la surveillance système, l'analyse de disque et le nettoyage. Développée avec SwiftUI pour macOS 14+.

## Fonctionnalités

- **Tableau de bord** : Métriques système en temps réel (CPU, mémoire, disque, batterie, appareils Bluetooth)
- **Nettoyeur** : Analyser et supprimer les caches, journaux et fichiers temporaires
- **Analyseur** : Analyse visuelle de l'espace disque avec navigation interactive
- **Optimiseur** : Tâches d'optimisation système (vider le cache DNS, réinitialiser Spotlight, reconstruire le cache des polices, etc.)
- **Applications** : Afficher les applications installées et désinstaller avec nettoyage des fichiers associés
- **Historique** : Suivre toutes les opérations de nettoyage
- **Tâches planifiées** : Automatiser les routines de nettoyage

## Comparaison avec les alternatives payantes

DodoTidy est une alternative gratuite et open source aux nettoyeurs système macOS payants comme CleanMyMac X, MacKeeper et DaisyDisk. Il offre des fonctionnalités comparables sans frais d'abonnement ni coûts d'achat uniques.

| Fonctionnalité | **DodoTidy** | **CleanMyMac X** | **MacKeeper** | **DaisyDisk** |
|----------------|-------------|------------------|---------------|---------------|
| **Prix** | Gratuit (Open Source) | $39.95/an ou $89.95 unique | $71.40/an ($5.95/mois) | $9.99 unique |
| **Surveillance système** | ✅ CPU, RAM, Disque, Batterie, Bluetooth | ✅ CPU, RAM, Disque | ✅ Surveillance mémoire | ❌ |
| **Nettoyage cache/fichiers** | ✅ | ✅ | ✅ | ❌ |
| **Analyseur d'espace disque** | ✅ Graphique sunburst visuel | ✅ Space Lens | ❌ | ✅ Anneaux visuels |
| **Désinstallateur d'apps** | ✅ Avec fichiers associés | ✅ Avec fichiers associés | ✅ Smart Uninstaller | ❌ |
| **Optimisation système** | ✅ DNS, Spotlight, polices, Dock | ✅ Scripts maintenance | ✅ Démarrage, RAM | ❌ |
| **Nettoyage planifié** | ✅ | ✅ | ❌ | ❌ |
| **Suppression vers corbeille** | ✅ Toujours récupérable | ✅ | ✅ | ✅ |
| **Mode simulation** | ✅ | ❌ | ❌ | ❌ |
| **Chemins protégés** | ✅ Personnalisable | ✅ | ✅ | N/A |
| **Version macOS** | 14.0+ (Sonoma) | 10.13+ | 10.13+ | 10.13+ |
| **Open Source** | ✅ Licence MIT | ❌ | ❌ | ❌ |

## Mesures de Sécurité

DodoTidy est conçu avec plusieurs mécanismes de sécurité pour protéger vos données :

### 1. Suppression vers la corbeille (Récupérable)

Toutes les suppressions de fichiers utilisent l'API `trashItem()` de macOS, qui déplace les fichiers vers la Corbeille au lieu de les supprimer définitivement. Vous pouvez toujours récupérer les fichiers supprimés accidentellement depuis la Corbeille.

### 2. Chemins protégés

Les chemins suivants sont protégés par défaut et ne seront jamais nettoyés :

- `~/Documents` - Vos documents
- `~/Desktop` - Fichiers du bureau
- `~/Pictures`, `~/Movies`, `~/Music` - Bibliothèques multimédia
- `~/.ssh`, `~/.gnupg` - Clés de sécurité
- `~/.aws`, `~/.kube` - Identifiants cloud
- `~/Library/Keychains` - Trousseaux système
- `~/Library/Application Support/MobileSync` - Sauvegardes d'appareils iOS

Vous pouvez personnaliser les chemins protégés dans les Réglages.

### 3. Catégories sûres vs manuelles uniquement

**Chemins de nettoyage automatique sûrs** (utilisés par les tâches planifiées) :
- Caches de navigateur (Safari, Chrome, Firefox)
- Caches d'applications (Spotify, Slack, Discord, VS Code, Zoom, Teams)
- Xcode DerivedData

**Chemins manuels uniquement** (nécessitent une action explicite de l'utilisateur, jamais nettoyés automatiquement) :
- **Téléchargements** - Peut contenir des fichiers importants non traités
- **Corbeille** - Le vidage est IRRÉVERSIBLE
- **Journaux système** - Peuvent être nécessaires pour le dépannage
- **Caches développeur** (npm, Yarn, Homebrew, pip, CocoaPods, Gradle, Maven) - Peuvent nécessiter de longs re-téléchargements

### 4. Mode simulation

Activez le "Mode simulation" dans les Réglages pour prévisualiser exactement quels fichiers seraient supprimés sans rien supprimer réellement. Cela affiche :
- Chemins des fichiers
- Tailles des fichiers
- Dates de modification
- Nombre et taille totaux

### 5. Filtre d'âge des fichiers

Définissez un âge minimum des fichiers (en jours) pour ne nettoyer que les fichiers plus anciens qu'un seuil spécifié. Cela empêche la suppression accidentelle de fichiers récemment créés ou modifiés.

Exemple : Réglez sur 7 jours pour ne nettoyer que les fichiers qui n'ont pas été modifiés la semaine dernière.

### 6. Confirmation des tâches planifiées

Lorsque "Confirmer les tâches planifiées" est activé (par défaut), les tâches de nettoyage planifiées :
- Envoient une notification quand elles sont prêtes à s'exécuter
- Attendent la confirmation de l'utilisateur avant l'exécution
- Ne nettoient jamais automatiquement sans vérification de l'utilisateur

### 7. Opérations en espace utilisateur uniquement

DodoTidy fonctionne entièrement dans l'espace utilisateur :
- Aucun privilège sudo ou root requis
- Ne peut pas modifier les fichiers système
- Ne peut pas affecter les données d'autres utilisateurs
- Toutes les opérations limitées aux chemins `~/`

### 8. Commandes d'optimisation sûres

L'optimiseur n'exécute que des commandes système connues et sûres :
- `dscacheutil -flushcache` - Vider le cache DNS
- `qlmanage -r cache` - Réinitialiser les miniatures Quick Look
- `lsregister` - Reconstruire la base de données Launch Services

Aucune commande système destructive ou risquée n'est incluse.

## Installation

### Homebrew (Recommandé)

```bash
brew tap dodoapps/tap
brew install --cask dodotidy
xattr -cr /Applications/DodoTidy.app
```

### Installation manuelle

1. Téléchargez le dernier DMG depuis [Releases](https://github.com/dodoapps/dodotidy/releases)
2. Ouvrez le DMG et faites glisser DodoTidy vers Applications
3. Faites un clic droit et sélectionnez "Ouvrir" lors du premier lancement (requis pour les applications non signées)

Ou exécutez : `xattr -cr /Applications/DodoTidy.app`

## Configuration requise

- macOS 14.0 ou ultérieur
- Xcode 15.0 ou ultérieur (pour la compilation à partir du code source)

## Compilation à partir du code source

### Avec XcodeGen (Recommandé)

```bash
# Installer les dépendances
make install-dependencies

# Générer le projet Xcode
make generate-project

# Compiler l'application
make build

# Exécuter l'application
make run
```

### Directement avec Xcode

1. Exécutez `make generate-project` pour créer le projet Xcode
2. Ouvrez `DodoTidy.xcodeproj` dans Xcode
3. Compilez et exécutez (Cmd+R)

## Structure du projet

```
DodoTidy/
├── App/
│   ├── DodoTidyApp.swift          # Point d'entrée principal
│   ├── AppDelegate.swift          # Gestion de la barre de menus
│   └── StatusItemManager.swift    # Icône de la barre d'état
├── Views/
│   ├── MainWindow/                # Vues de la fenêtre principale
│   │   ├── MainWindowView.swift
│   │   ├── SidebarView.swift
│   │   ├── DashboardView.swift
│   │   ├── CleanerView.swift
│   │   ├── AnalyzerView.swift
│   │   ├── OptimizerView.swift
│   │   ├── AppsView.swift
│   │   ├── HistoryView.swift
│   │   └── ScheduledTasksView.swift
│   └── MenuBar/
│       └── MenuBarView.swift      # Popover de la barre de menus
├── Services/
│   └── DodoTidyService.swift      # Fournisseurs de services principaux
├── Models/
│   ├── SystemMetrics.swift        # Modèles de métriques système
│   └── ScanResult.swift           # Modèles de résultats d'analyse
├── Utilities/
│   ├── ProcessRunner.swift        # Assistant d'exécution de processus
│   ├── DesignSystem.swift         # Couleurs, polices, styles
│   └── Extensions.swift           # Assistants de formatage
└── Resources/
    └── Assets.xcassets            # Icônes de l'application
```

## Architecture

L'application utilise une architecture basée sur des fournisseurs :

- **DodoTidyService** : Coordinateur principal gérant tous les fournisseurs
- **StatusProvider** : Collecte des métriques système via les API natives macOS
- **AnalyzerProvider** : Analyse de l'espace disque avec FileManager
- **CleanerProvider** : Nettoyage des caches et fichiers temporaires avec mesures de sécurité
- **OptimizerProvider** : Tâches d'optimisation système
- **UninstallProvider** : Désinstallation d'applications avec détection des fichiers associés

Tous les fournisseurs utilisent la macro `@Observable` de Swift pour la gestion d'état réactive.

## Réglages

Accédez aux Réglages depuis le menu de l'application ou la barre latérale pour configurer :

- **Général** : Lancer à la connexion, icône de barre de menus, intervalle de rafraîchissement
- **Nettoyage** : Confirmer avant le nettoyage, mode simulation, filtre d'âge des fichiers
- **Chemins protégés** : Chemins qui ne doivent jamais être nettoyés
- **Notifications** : Alertes d'espace disque faible, notifications de tâches planifiées

## Système de design

- **Couleur primaire** : #13715B (Vert)
- **Arrière-plan** : #0F1419 (Sombre)
- **Texte principal** : #F9FAFB
- **Rayon de bordure** : 4px
- **Hauteur des boutons** : 34px

## Licence

Licence MIT

---

Fait partie de la famille d'applications Dodo ([DodoPulse](https://github.com/dodoapps/dodopulse), [DodoTidy](https://github.com/dodoapps/dodotidy), [DodoClip](https://github.com/dodoapps/dodoclip), [DodoNest](https://github.com/dodoapps/dodonest))
