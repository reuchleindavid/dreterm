![DRETerm](docs/banner.png)

# DRETerm - das Mac-Terminal mit Sidebar statt Tabs

[![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)
![macOS 14+](https://img.shields.io/badge/macOS-14%2B-8B5CF6)
![Swift](https://img.shields.io/badge/Swift-5.10-C084FC)
![Engine](https://img.shields.io/badge/Engine-SwiftTerm-6D3FD4)

Ein natives Mac-Terminal, das sich anfühlt wie Terminal.app, aber links eine Sidebar hat: jede Sitzung mit eigenem Namen, Farbe und Symbol, darunter live der Ordner und das Programm, das gerade läuft.

Entstanden, weil ich parallel in zehn Terminal-Tabs an Kundenshops, Servern und Claude-Code-Sitzungen arbeite und bei „zsh“, „zsh“, „zsh“ nie wusste, welcher Tab welcher ist.

![DRETerm](docs/screenshot.png)

## Was es kann

| Bereich | Funktion |
|---|---|
| **Sitzungen** | Benennen per Doppelklick, Farbe, Symbol, anheften, per Drag & Drop sortieren, duplizieren |
| **Live-Status** | Aktueller Ordner und laufender Prozess (`claude`, `npm`, `ssh` …) direkt in der Sidebar |
| **Hintergrund** | Punkt bei neuer Ausgabe, grüner Haken, wenn ein längerer Befehl fertig ist, Glocke |
| **Wiederherstellung** | Sitzungen bleiben über Neustarts erhalten: Name, Farbe, Notizen und letzter Ordner |
| **Befehlspalette** | ⌘P: Sitzungen, Snippets, Themes und Aktionen durchsuchen |
| **Snippets** | Gespeicherte Befehle mit einem Klick ausführen oder nur einfügen |
| **Notizen** | Inspector (⌘I) mit Notizen und Details pro Sitzung |
| **Optik** | 6 Themes, echte Fenster-Transparenz mit optionalem Weichzeichnen, frei wählbare Monospace-Schrift |

## Prinzipien

- **Ein echtes Terminal.** Login-Shell, xterm-256color, Truecolor. vim, htop, ssh und Claude Code laufen wie gewohnt.
- **Keine Shell-Integration nötig.** Ordner und Prozess kommen direkt aus dem Kernel (`proc_pidinfo`, `tcgetpgrp`), an der `.zshrc` ändert sich nichts.
- **Deutsche Tastatur zuerst.** ⌥ bleibt ⌥, damit `@`, `[`, `]`, `|` und `{}` funktionieren.
- **Ruhig statt bunt.** Dunkles Violett als Standard-Theme, keine Effekte, die nur Deko sind.

## Installation

Voraussetzung: macOS 14 und die Command Line Tools (`xcode-select --install`). Xcode ist nicht nötig.

```bash
git clone https://github.com/reuchleindavid/dreterm.git
cd dreterm
./build.sh             # baut dist/DRETerm.app
./build.sh --install   # optional: nach /Applications kopieren
```


## Tastenkürzel

| Kürzel | Aktion |
|---|---|
| ⌘T | Neue Sitzung im Ordner der aktuellen |
| ⌘N | Neue Sitzung im Home-Ordner |
| ⌘W | Sitzung schließen |
| ⌘⇧R / Doppelklick | Umbenennen |
| ⌘1 … ⌘9 | Zu Sitzung springen |
| ⌘⌥↑ / ⌘⌥↓ | Vorherige / nächste Sitzung |
| ⌘P | Befehlspalette |
| ⌘I | Notizen & Details |
| ⌘F | Suchen |
| ⌘K | Bildschirm leeren |
| ⌘+ / ⌘- / ⌘0 | Schriftgröße |
| ⌘⌥+ / ⌘⌥- | Deckender / transparenter |
| ⌘⇧O | Ordner im Finder zeigen |
| ⌘⇧C | Pfad kopieren |

## Gut zu wissen

- **Daten:** Sitzungen, Snippets und Einstellungen liegen in `~/Library/Application Support/DRETerm/state.json`.
- **Laufende Programme** überleben einen Neustart der App nicht. Wiederhergestellt wird die Sitzung mit frischer Shell im letzten Ordner.
- **SwiftTerm ist auf 1.18.0 fixiert.** Neuere Versionen brauchen Swift 6 und damit eine neuere Toolchain.
- **Theme „DRE Violett“** ist aus den Farben von [david-reuchlein.de](https://www.david-reuchlein.de/) abgeleitet.

## Aufbau

```
Sources/DRETerm/
  DRETermApp.swift      App, Menüs, Tastenkürzel
  Store.swift           Zustand, Persistenz, Terminal-Views pro Sitzung, Prozess-Poll
  ProcInfo.swift        Ordner und Vordergrund-Prozess aus dem Kernel
  Theme.swift           Farbschemata
  ContentView.swift     Fenster, Terminal-Bereich, Statusleiste
  SidebarView.swift     Sitzungsliste, Kontextmenü, Snippets
  PaletteView.swift     Befehlspalette
  InspectorView.swift   Notizen & Details
  SettingsView.swift    Einstellungen
Scripts/make_icon.swift App-Icon aus dem Logo
build.sh                Bündelt die .app ohne Xcode
```

## Geplant

- Gruppen in der Sidebar (z. B. pro Kunde)
- Split-Ansicht für zwei Sitzungen nebeneinander
- macOS-Mitteilung, wenn ein langer Befehl fertig ist
- SSH-Profile mit Ein-Klick-Verbindung

## Lizenz

MIT - siehe [LICENSE](LICENSE). Terminal-Engine: [SwiftTerm](https://github.com/migueldeicaza/SwiftTerm) von Miguel de Icaza (MIT).
