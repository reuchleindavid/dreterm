# DRETerm - Konzept

Ein eigenes Mac-Terminal für David: sieht aus und fühlt sich an wie Terminal.app, aber mit einer
Sidebar statt Tab-Leiste, sauber benannten Sitzungen und ein paar Werkzeugen, die im Alltag fehlen.

## Grundidee
- **Links Sidebar** mit allen Sitzungen (statt Tabs oben). Jede Sitzung hat einen eigenen Namen,
  eine Farbe und ein Symbol. Darunter live: aktueller Ordner und laufendes Programm (z. B. `claude`, `npm`).
- **Rechts das Terminal** - echte Shell (zsh als Login-Shell), voll kompatibel mit vim, htop, Claude Code usw.
- **Optik:** dunkles, ruhiges Design, durchscheinende Sidebar (macOS-Vibrancy), versteckte Titelleiste,
  wählbare Farbschemata, Monospace-Schrift frei wählbar.

## Funktionen v1
| Bereich | Funktion |
|---|---|
| Sitzungen | Neu (⌘T, startet im Ordner der aktuellen Sitzung), schließen (⌘W), umbenennen (Doppelklick / ⌘⇧R), Farbe, Symbol, anheften, duplizieren, Drag-and-Drop-Sortierung, ⌘1-9 und ⌘⇧[ / ⌘⇧] zum Wechseln |
| Live-Status | Ordner + laufender Prozess pro Sitzung, Aktivitätspunkt bei Ausgabe im Hintergrund, Haken wenn ein langer Befehl im Hintergrund fertig wurde, Glocke |
| Wiederherstellung | Namen, Farben, Notizen und letzter Ordner bleiben über Neustarts erhalten |
| Befehlspalette | ⌘P: Sitzungen suchen und wechseln, Snippets ausführen, Aktionen (Theme, neue Sitzung …) |
| Snippets | Gespeicherte Befehle (z. B. `claude`, `git status`, Ports anzeigen), per Palette oder Sidebar ausführen |
| Notizen | Inspector rechts (⌘I) mit Notizen pro Sitzung |
| Terminal | Suchen (⌘F), Bildschirm leeren (⌘K), Schriftgröße (⌘+ / ⌘- / ⌘0), Statusleiste mit Prozess, Pfad, Spalten×Zeilen |
| Ordner | Im Finder öffnen, Pfad kopieren |
| Einstellungen | Theme, Schrift, Größe, Deckkraft, Shell, Snippets verwalten |

## Technik
- Swift 5.10 + SwiftUI (macOS 14), Terminal-Engine **SwiftTerm 1.18** (xterm-kompatibel, Metal-fähig).
- Kein Xcode nötig: Swift Package, `build.sh` baut ein `.app`-Bundle inkl. Icon.
- Prozess-Infos ohne Shell-Integration: aktueller Ordner über `proc_pidinfo`, Vordergrund-Prozess über `tcgetpgrp` auf dem PTY.
- Daten: `~/Library/Application Support/DRETerm/state.json`.

## Später (v2-Ideen)
- Gruppen/Ordner in der Sidebar (z. B. pro Kunde), Split-Ansicht (zwei Sitzungen nebeneinander)
- macOS-Mitteilung, wenn ein langer Befehl im Hintergrund fertig ist
- SSH-Profile (Server-Liste mit Ein-Klick-Verbindung), Workspaces (Sitzungs-Sets laden)
- Verlauf durchsuchen über alle Sitzungen, Ausgabe als Datei speichern
