# DodoTidy - macOS Systembereiniger

Eine native macOS-Anwendung für Systemüberwachung, Festplattenanalyse und Bereinigung. Entwickelt mit SwiftUI für macOS 14+.

## Funktionen

- **Dashboard**: Echtzeit-Systemmetriken (CPU, Arbeitsspeicher, Festplatte, Akku, Bluetooth-Geräte)
- **Bereiniger**: Caches, Protokolle und temporäre Dateien scannen und entfernen
- **Analysator**: Visuelle Speicherplatzanalyse mit interaktiver Navigation
- **Optimierer**: Systemoptimierungsaufgaben (DNS-Cache leeren, Spotlight zurücksetzen, Schriftarten-Cache neu erstellen usw.)
- **Apps**: Installierte Anwendungen anzeigen und mit zugehöriger Dateibereinigung deinstallieren
- **Verlauf**: Alle Bereinigungsvorgänge verfolgen
- **Geplante Aufgaben**: Bereinigungsroutinen automatisieren

## Sicherheitsvorkehrungen

DodoTidy wurde mit mehreren Sicherheitsmechanismen zum Schutz Ihrer Daten entwickelt:

### 1. Papierkorb-basierte Löschung (Wiederherstellbar)

Alle Dateilöschungen verwenden die macOS-API `trashItem()`, die Dateien in den Papierkorb verschiebt, anstatt sie dauerhaft zu löschen. Versehentlich gelöschte Dateien können jederzeit aus dem Papierkorb wiederhergestellt werden.

### 2. Geschützte Pfade

Die folgenden Pfade sind standardmäßig geschützt und werden niemals bereinigt:

- `~/Documents` - Ihre Dokumente
- `~/Desktop` - Desktop-Dateien
- `~/Pictures`, `~/Movies`, `~/Music` - Medienbibliotheken
- `~/.ssh`, `~/.gnupg` - Sicherheitsschlüssel
- `~/.aws`, `~/.kube` - Cloud-Anmeldedaten
- `~/Library/Keychains` - System-Schlüsselbunde
- `~/Library/Application Support/MobileSync` - iOS-Gerätesicherungen

Geschützte Pfade können in den Einstellungen angepasst werden.

### 3. Sichere vs. nur manuelle Kategorien

**Sichere automatische Bereinigungspfade** (von geplanten Aufgaben verwendet):
- Browser-Caches (Safari, Chrome, Firefox)
- Anwendungs-Caches (Spotify, Slack, Discord, VS Code, Zoom, Teams)
- Xcode DerivedData

**Nur manuelle Pfade** (erfordern explizite Benutzeraktion, werden nie automatisch bereinigt):
- **Downloads** - Kann wichtige unverarbeitete Dateien enthalten
- **Papierkorb** - Leeren ist UNWIDERRUFLICH
- **Systemprotokolle** - Können für Fehlerbehebung benötigt werden
- **Entwickler-Caches** (npm, Yarn, Homebrew, pip, CocoaPods, Gradle, Maven) - Können lange Neudownloads erfordern

### 4. Probelauf-Modus

Aktivieren Sie den "Probelauf-Modus" in den Einstellungen, um genau zu sehen, welche Dateien gelöscht würden, ohne tatsächlich etwas zu löschen. Dies zeigt:
- Dateipfade
- Dateigrößen
- Änderungsdaten
- Gesamtanzahl und -größe

### 5. Dateialter-Filter

Legen Sie ein Mindestalter für Dateien (in Tagen) fest, um nur Dateien zu bereinigen, die älter als ein bestimmter Schwellenwert sind. Dies verhindert das versehentliche Löschen kürzlich erstellter oder geänderter Dateien.

Beispiel: Auf 7 Tage einstellen, um nur Dateien zu bereinigen, die in der letzten Woche nicht geändert wurden.

### 6. Bestätigung geplanter Aufgaben

Wenn "Geplante Aufgaben bestätigen" aktiviert ist (Standard), werden geplante Bereinigungsaufgaben:
- Eine Benachrichtigung senden, wenn sie ausführungsbereit sind
- Vor der Ausführung auf Benutzerbestätigung warten
- Nie ohne Benutzerüberprüfung automatisch bereinigen

### 7. Nur Benutzerbereich-Operationen

DodoTidy arbeitet vollständig im Benutzerbereich:
- Keine sudo- oder Root-Berechtigungen erforderlich
- Kann Systemdateien nicht ändern
- Kann Daten anderer Benutzer nicht beeinflussen
- Alle Operationen auf `~/`-Pfade beschränkt

### 8. Sichere Optimierer-Befehle

Der Optimierer führt nur bekannte, sichere Systembefehle aus:
- `dscacheutil -flushcache` - DNS-Cache leeren
- `qlmanage -r cache` - Quick Look-Miniaturansichten zurücksetzen
- `lsregister` - Launch Services-Datenbank neu erstellen

Keine destruktiven oder riskanten Systembefehle sind enthalten.

## Anforderungen

- macOS 14.0 oder höher
- Xcode 15.0 oder höher (zum Kompilieren)

## Kompilierung

### Mit XcodeGen (Empfohlen)

```bash
# Abhängigkeiten installieren
make install-dependencies

# Xcode-Projekt generieren
make generate-project

# App kompilieren
make build

# App ausführen
make run
```

### Direkt mit Xcode

1. Führen Sie `make generate-project` aus, um das Xcode-Projekt zu erstellen
2. Öffnen Sie `DodoTidy.xcodeproj` in Xcode
3. Kompilieren und ausführen (Cmd+R)

## Projektstruktur

```
DodoTidy/
├── App/
│   ├── DodoTidyApp.swift          # Haupt-App-Einstiegspunkt
│   ├── AppDelegate.swift          # Menüleistenverwaltung
│   └── StatusItemManager.swift    # Statusleistensymbol
├── Views/
│   ├── MainWindow/                # Hauptfensteransichten
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
│       └── MenuBarView.swift      # Menüleisten-Popover
├── Services/
│   └── DodoTidyService.swift      # Kern-Dienstanbieter
├── Models/
│   ├── SystemMetrics.swift        # Systemmetrik-Modelle
│   └── ScanResult.swift           # Scanergebnis-Modelle
├── Utilities/
│   ├── ProcessRunner.swift        # Prozessausführungshelfer
│   ├── DesignSystem.swift         # Farben, Schriften, Stile
│   └── Extensions.swift           # Formatierungshelfer
└── Resources/
    └── Assets.xcassets            # App-Symbole
```

## Architektur

Die App verwendet eine anbieterbasierte Architektur:

- **DodoTidyService**: Hauptkoordinator, der alle Anbieter verwaltet
- **StatusProvider**: Sammlung von Systemmetriken mit nativen macOS-APIs
- **AnalyzerProvider**: Speicherplatzanalyse mit FileManager
- **CleanerProvider**: Cache- und temporäre Dateibereinigung mit Sicherheitsvorkehrungen
- **OptimizerProvider**: Systemoptimierungsaufgaben
- **UninstallProvider**: App-Deinstallation mit Erkennung zugehöriger Dateien

Alle Anbieter verwenden Swifts `@Observable`-Makro für reaktives Zustandsmanagement.

## Einstellungen

Greifen Sie über das App-Menü oder die Seitenleiste auf die Einstellungen zu:

- **Allgemein**: Bei Anmeldung starten, Menüleistensymbol, Aktualisierungsintervall
- **Bereinigung**: Vor Bereinigung bestätigen, Probelauf-Modus, Dateialter-Filter
- **Geschützte Pfade**: Pfade, die nie bereinigt werden sollen
- **Benachrichtigungen**: Warnungen bei wenig Speicherplatz, Benachrichtigungen für geplante Aufgaben

## Designsystem

- **Primärfarbe**: #13715B (Grün)
- **Hintergrund**: #0F1419 (Dunkel)
- **Primärtext**: #F9FAFB
- **Eckenradius**: 4px
- **Schaltflächenhöhe**: 34px

## Lizenz

MIT-Lizenz
