# Aufgabe 1: R-Shiny Companion-App modernisieren, auditieren und absichern

## Kurzkontext für Codex

Diese Repository enthält eine ältere R-Shiny Companion-App zu einer wissenschaftlichen Publikation über die Test-Retest-Reliabilität von Conjoint-Studien. Die App soll Forschenden ermöglichen, eine Excel- oder CSV-Datei in einem vorgegebenen Format hochzuladen, den im Paper beschriebenen Workflow auszuführen, Ergebnisse einzusehen und Resultate als Excel-Dateien sowie Plots als PNG-Dateien herunterzuladen.

Die wissenschaftliche Funktionalität soll **nicht fachlich neu erfunden** werden. Ziel ist ein gründlicher Modernisierungs-, Qualitäts- und Sicherheitsdurchgang: bessere Codequalität, nachvollziehbare Projektstruktur, moderne Shiny-UI, sauberere Fehlerbehandlung, sichere Upload-/Download-Pfade, Session-bezogene Datenlöschung und bessere Testbarkeit.

---

## Nicht verhandelbare Anforderungen

1. **Statistische Ergebnisse bleiben fachlich identisch.**
   - Keine Änderung an Formeln, Reliabilitätsmaßen, Testlogik, Datenaufbereitung oder Output-Definitionen, außer ein Bug ist durch Tests oder Code eindeutig belegt.
   - Vor jeder Änderung an Analysefunktionen erst Baseline-Ergebnisse erzeugen und nach Änderungen vergleichen.

2. **User-Daten werden nicht dauerhaft gespeichert.**
   - Uploads, temporäre Zwischendateien, generierte Excel-Dateien und PNG-Dateien gehören in einen Session-spezifischen temporären Ordner.
   - Beim Session-Ende und App-Stop sollen diese Ordner explizit gelöscht werden.
   - Keine Analytics, kein Tracking, keine Speicherung von Upload-Inhalten in Logs.

3. **Keine ungeprüften Dateiannahmen.**
   - Browser-MIME-Typen und Dateiendungen sind Hinweise, aber keine alleinige Sicherheitsprüfung.
   - CSV/XLSX-Inhalte müssen serverseitig validiert werden.

4. **UI modernisieren, aber wissenschaftliche Transparenz bewahren.**
   - Die App soll klarer, moderner und freundlicher wirken.
   - Methodische Hinweise, Annahmen, Fehlermeldungen und Download-Optionen müssen sichtbar und verständlich bleiben.

5. **Codex arbeitet in kleinen, prüfbaren Schritten.**
   - Erst Repository scannen.
   - Dann Baseline und Tests schaffen.
   - Danach refactoren.
   - Dann UI modernisieren.
   - Dann Security-/Privacy-Checks abschließen.

---

## Erster Prompt für Codex

Diesen Prompt in VS Code/Codex verwenden:

```text
Lies diese Datei vollständig: 01_SHINY_COMPANION_APP_MODERNIZATION_AUDIT.md.
Scanne danach das gesamte Repository, ohne Code zu verändern.
Erstelle zuerst docs/APP_BASELINE_AUDIT.md mit:
1. Projektstruktur,
2. App-Einstiegspunkten,
3. verwendeten R-Paketen,
4. Upload-/Download-Flow,
5. Analysefunktionen,
6. UI-Struktur,
7. vorhandenen Tests,
8. vorhandenen Beispiel-/Fixture-Dateien,
9. erkennbaren Risiken.

Ändere erst Code, nachdem dieser Audit-Bericht erstellt wurde.
```

---

## Zielbild nach Aufgabe 1

Am Ende soll das Repository folgende Eigenschaften haben:

- Die Shiny-App startet lokal reproduzierbar.
- Dependencies sind dokumentiert und möglichst über `renv` oder eine vergleichbare Struktur fixiert.
- Der fachliche Analyseworkflow ist in testbare R-Funktionen ausgelagert.
- UI und Serverlogik sind besser getrennt.
- Uploads werden geprüft, begrenzt und in Session-spezifischen temporären Ordnern verarbeitet.
- Downloads werden pro Session generiert und nach Session-Ende gelöscht.
- Nutzerfreundliche Fehlermeldungen ersetzen rohe R-Fehler.
- Die Oberfläche nutzt eine moderne Shiny-UI, vorzugsweise `{bslib}` mit Bootstrap 5.
- Es gibt Regressionstests für Beispielinput und erwartete Kernoutputs.
- Es gibt Security-/Privacy-Dokumentation für Serverbetrieb und App-Verhalten.

---

## Phase 0: Repository-Orientierung und Ist-Zustand

Codex soll zuerst nur lesen und dokumentieren.

### Zu prüfen

- Gibt es `app.R`, `ui.R`, `server.R`, `global.R`, `R/`, `modules/`, `www/`, `data/`, `inst/`, `tests/`, `renv.lock`, `DESCRIPTION`, `Dockerfile`, Deployment-Dateien?
- Welche Pakete werden geladen?
- Welche Funktionen berechnen die Test-Retest-Reliabilität?
- Welche Dateien werden hochgeladen?
- Welche Dateiformate werden akzeptiert?
- Welche Excel-/CSV-Struktur wird erwartet?
- Welche Outputs werden erzeugt?
- Wo entstehen temporäre Dateien?
- Wird etwas auf Platte gespeichert?
- Gibt es Beispiel-Daten?
- Gibt es Tests?
- Gibt es externe Netzwerkzugriffe?
- Gibt es Codepfade mit `eval`, `parse`, `system`, `shell`, `file.rename`, `file.copy`, `unlink`, `downloadHandler`, `write.xlsx`, `png`, `ggsave`?

### Ergebnisdatei

Codex erstellt:

```text
docs/APP_BASELINE_AUDIT.md
```

Diese Datei enthält mindestens:

```text
## Repository map
## App entry points
## Package inventory
## Upload pipeline
## Analysis pipeline
## Output/download pipeline
## UI inventory
## Temp file and persistence inventory
## Current test coverage
## Current risks
## Recommended next steps
```

---

## Phase 1: Reproduzierbare lokale Entwicklungsumgebung

### Ziel

Die App soll lokal mit einem klaren Befehl starten und mit einem klaren Befehl geprüft werden können.

### Schritte

1. Prüfen, ob `renv` vorhanden ist.
2. Falls ja: `renv::restore()`-Workflow dokumentieren.
3. Falls nein: Codex darf `renv` vorbereiten, aber keine Paketversionen blind aktualisieren.
4. Einen lokalen Startbefehl erstellen, z. B.:

```text
Rscript scripts/run_app.R
```

5. Einen Checkbefehl erstellen, z. B.:

```text
Rscript scripts/check_app.R
```

6. Falls das Projekt als R-Package strukturiert ist, zusätzlich:

```text
R CMD check .
```

7. Optional, falls sinnvoll:

```text
.vscode/tasks.json
Makefile
```

### Akzeptanzkriterien

- Ein neuer Entwickler kann die App nach README-Anweisung lokal starten.
- Codex dokumentiert alle benötigten Systemvoraussetzungen.
- Die App startet ohne manuelle Änderungen an Pfaden.

---

## Phase 2: Baseline-Regression vor Refactoring

### Ziel

Bevor Code verändert wird, müssen fachliche Referenzergebnisse gesichert werden.

### Schritte

1. Vorhandene Beispiel-Dateien suchen.
2. Falls Beispiel-Dateien vorhanden sind:
   - App-Workflow einmal lokal durchspielen.
   - Wichtige Outputs speichern.
   - Kernwerte, Tabellenformen, Spaltennamen und Plot-Dateinamen dokumentieren.
3. Falls keine Beispiel-Dateien vorhanden sind:
   - Aus Dokumentation/README die minimale gültige Inputstruktur ableiten.
   - Eine kleine synthetische Test-Fixture erstellen.
   - Diese Fixture deutlich als synthetisch markieren.
4. Regressionstest erzeugen:

```text
tests/testthat/test_regression_outputs.R
```

5. Erwartete Ergebnisse nur für stabile, zentrale Outputs testen:
   - Spaltennamen,
   - Anzahl Zeilen/Spalten,
   - zentrale Reliabilitätswerte,
   - fehlertolerante numerische Vergleiche,
   - vorhandene Downloads.

### Akzeptanzkriterien

- Es gibt mindestens einen reproduzierbaren Testlauf mit Beispielinput.
- Nach einem Refactoring können zentrale Outputs mit der Baseline verglichen werden.
- Tests trennen klar zwischen fachlicher Regression und UI-Verhalten.

---

## Phase 3: Codequalität und Architektur verbessern

### Ziel

Die App soll wartbarer werden, ohne die Fachlogik zu verändern.

### Empfohlene Struktur

Falls das Repository noch monolithisch ist, schrittweise in diese Richtung gehen:

```text
app.R
R/
  analysis_parse_input.R
  analysis_validate_input.R
  analysis_reliability.R
  analysis_outputs.R
  ui_theme.R
  ui_upload.R
  ui_results.R
  server_upload.R
  server_results.R
  session_files.R
  errors.R
  utils.R
scripts/
  run_app.R
  check_app.R
tests/
  testthat/
    test_parse_input.R
    test_validate_input.R
    test_reliability_regression.R
    test_session_files.R
www/
  app.css
  app.js
```

### Refactoring-Regeln

- Analysefunktionen als möglichst reine Funktionen schreiben:

```text
input data -> output object
```

- Shiny-reactives sollen diese Funktionen nur aufrufen, nicht die komplette Analyse enthalten.
- UI-Komponenten in eigene Funktionen oder Module auslagern.
- Wiederholte Codeblöcke in Funktionen überführen.
- Fehlerbehandlung zentralisieren.
- Keine großen Refactors ohne Regressionstest.
- Nach jedem Refactoring Tests ausführen.

### Shiny-Module

Wenn UI/Server sehr groß sind, Module verwenden:

```text
upload_module_ui(id)
upload_module_server(id)
results_module_ui(id)
results_module_server(id, analysis_result)
documentation_module_ui(id)
```

Shiny-Module sind besonders sinnvoll für Upload, Validierung, Ergebnisse, Downloads und Dokumentation.

### Linting und Stil

Codex soll prüfen, ob diese Tools sinnvoll integrierbar sind:

```text
lintr
styler
testthat
```

Nicht blind umfangreiche Stiländerungen über die gesamte Codebase machen. Erst priorisierte Dateien bearbeiten.

---

## Phase 4: Upload-, Session- und Privacy-Security

### Ziel

Die App soll Uploads kontrolliert verarbeiten und nach der Session keine User-Dateien behalten.

### Upload-Limits

Codex soll eine explizite Maximalgröße setzen, z. B. in `global.R` oder beim App-Start:

```r
options(shiny.maxRequestSize = 20 * 1024^2)
```

Der konkrete Wert soll dokumentiert und leicht konfigurierbar sein.

### Erlaubte Formate

UI-seitig:

```r
fileInput(
  inputId = "data_file",
  label = "Upload CSV or Excel file",
  accept = c(".csv", ".xlsx", "text/csv", "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet")
)
```

Serverseitig zusätzlich prüfen:

- Dateigröße,
- Extension,
- parsebarer Inhalt,
- erwartete Spalten,
- Datentypen,
- Mindestanzahl Cases/Rows,
- keine unerwarteten zusätzlichen Tabellenblätter, falls die App nur ein Sheet erwartet,
- keine Formeln als Daten, falls Excel-Dateien gelesen werden und Formeln problematisch sind,
- keine Pfadverwendung aus User-Dateinamen.

### Session-spezifischer Arbeitsordner

Alle verarbeiteten Dateien und generierten Outputs in einem pro Session erzeugten Ordner ablegen:

```r
create_session_dir <- function(session) {
  root <- file.path(tempdir(), "conjoint_trt_app")
  dir.create(root, recursive = TRUE, showWarnings = FALSE)
  path <- file.path(root, session$token)
  dir.create(path, recursive = TRUE, showWarnings = FALSE)
  normalizePath(path, mustWork = TRUE)
}
```

Dazu passende Cleanup-Funktion:

```r
cleanup_session_dir <- function(path) {
  if (!is.character(path) || length(path) != 1L || is.na(path)) return(invisible(FALSE))
  if (!dir.exists(path)) return(invisible(TRUE))
  unlink(path, recursive = TRUE, force = TRUE)
  invisible(TRUE)
}
```

Im Server:

```r
server <- function(input, output, session) {
  session_dir <- create_session_dir(session)

  session$onSessionEnded(function() {
    cleanup_session_dir(session_dir)
  })

  # App logic ...
}
```

Optional zusätzlich `onStop()` verwenden, wenn globale App-Ressourcen entstehen.

### Pfadregeln

- Nie direkt mit dem Browser-Dateinamen schreiben.
- Browser-Dateinamen nur als Anzeige-Text verwenden und vorher säubern.
- Output-Dateien intern deterministisch benennen:

```text
results.xlsx
summary.xlsx
plot_reliability.png
plot_distribution.png
```

- Keine relativen Pfade wie `../../` aus Userinput übernehmen.
- Downloads nur aus dem Session-Ordner liefern.

### Logging

Logs dürfen enthalten:

```text
session started
file uploaded: size, extension, validation status
analysis started/completed
cleanup completed/failed
```

Logs dürfen nicht enthalten:

```text
Datensätze
Rohdaten
Teilnehmer-IDs
vollständige Zellinhalte aus Tabellen
absolute private Pfade von Usern
```

### Ressourcenlimits

Prüfen und dokumentieren:

- maximale Uploadgröße,
- maximale Zeilenanzahl,
- maximale Spaltenanzahl,
- erwartete Excel-Sheets,
- Timeouts für schwere Berechnungen, falls nötig,
- verständliche Fehlermeldung bei zu großen Dateien.

### Security-Testfälle

Codex soll Tests für mindestens diese Fälle anlegen:

```text
- falsche Dateiendung
- CSV mit falschen Spalten
- XLSX mit fehlenden Spalten
- leere Datei
- Datei größer als Limit, soweit testbar
- Dateiname mit ../ oder Sonderzeichen
- ungültige numerische Werte
- Download vor erfolgreicher Analyse
```

---

## Phase 5: Moderne UI mit Shiny und bslib

### Ziel

Die Oberfläche soll moderner, klarer und besser geführt wirken. Fokus: gute Forschungs-App, nicht Marketing-Landingpage.

### Präferenz

Codex soll zuerst prüfen, ob `{bslib}` bereits vorhanden ist oder einfach integrierbar ist. Empfohlene Zielrichtung:

```r
library(shiny)
library(bslib)

app_theme <- bs_theme(
  version = 5,
  bootswatch = "flatly"
)

ui <- page_navbar(
  title = "Conjoint Test-Retest Reliability Companion App",
  theme = app_theme,
  nav_panel("Upload", upload_module_ui("upload")),
  nav_panel("Analysis", analysis_module_ui("analysis")),
  nav_panel("Results", results_module_ui("results")),
  nav_panel("Documentation", documentation_module_ui("docs"))
)
```

Alternative Layouts prüfen:

```text
page_sidebar
page_fillable
cards
value boxes
accordion panels
modal help dialogs
progress indicators
```

### UI-Inhalte

Die App sollte idealerweise diese Bereiche haben:

1. **Start / Purpose**
   - Kurz erklären, wofür die App ist.
   - Link/Verweis auf Paper und OSF-Repository, falls im Repo vorhanden.

2. **Upload**
   - Klarer Hinweis auf erlaubtes Dateiformat.
   - Beispielstruktur anzeigen.
   - Optional Beispiel-Template zum Download.

3. **Validation**
   - Nach Upload: Checkliste mit gefundenen Spalten, Anzahl Zeilen, Warnungen.

4. **Analysis Controls**
   - Parameter der bisherigen App erhalten.
   - Bessere Labels und Hilfetexte.

5. **Results**
   - Kennzahlen als Cards/Value Boxes.
   - Tabellen in klaren Panels.
   - Plots mit konsistenter Größe.
   - Download-Buttons gruppieren.

6. **Documentation**
   - Minimaler Methodenüberblick.
   - Erklärungen zu Outputs.
   - Hinweise, wie Ergebnisse zu interpretieren sind.

7. **Privacy / Data handling**
   - Kurztext: Dateien werden nur für die aktuelle Session verarbeitet und anschließend gelöscht.

### UX-Regeln

- Keine rohen R-Fehler im UI.
- Bei Fehlern klare Hinweise: was ist falsch, wie kann man es beheben?
- Upload erst validieren, dann Analyse starten.
- Downloadbuttons erst aktivieren, wenn Ergebnisse vorliegen.
- Lange Berechnungen mit Fortschrittsanzeige.
- Wichtige Methodenhinweise nicht in Tooltips verstecken.
- Tabellen und Plots auch auf mittelgroßen Laptop-Screens lesbar machen.

### CSS

Falls eigenes CSS nötig ist:

```text
www/app.css
```

CSS sparsam verwenden. Bootstrap-/bslib-Komponenten bevorzugen.

---

## Phase 6: Downloads und Ergebnisexporte verbessern

### Ziel

Excel- und PNG-Downloads sollen zuverlässig, session-spezifisch und reproduzierbar erzeugt werden.

### Regeln

- Jede Output-Datei wird im Session-Ordner erzeugt.
- `downloadHandler()` liefert nur Dateien aus diesem Ordner.
- Vor jedem Download prüfen, ob Analyseergebnisse existieren.
- Keine Userdaten in Dateinamen.
- Optional Zeitstempel im Downloadnamen, aber nicht im internen Pfad.
- Plot-Exportgrößen festlegen:

```r
width = 1600
height = 1000
res = 200
```

oder äquivalent mit `ggsave()`.

### Tests

- Ergebnis-Excel existiert nach Analyse.
- Ergebnis-Excel hat erwartete Sheets/Spalten.
- PNG-Dateien existieren und sind größer als 0 Bytes.
- Downloads vor Analyse geben eine freundliche Fehlermeldung.

---

## Phase 7: Tests und automatisierte Checks

### Empfohlene Teststruktur

```text
tests/testthat/
  test_parse_input.R
  test_validate_input.R
  test_reliability_regression.R
  test_session_files.R
  test_download_outputs.R
```

### Optional Browser-/E2E-Tests

Wenn Playwright bereits im Setup vorhanden ist, kann Codex einen schlanken Browser-Test ergänzen:

```text
tests/e2e/
  companion_app.spec.ts
```

Dieser Test soll:

1. App lokal starten.
2. Beispiel-Datei hochladen.
3. Validierungsstatus prüfen.
4. Analyse starten.
5. Ergebnisbereich prüfen.
6. Download eines Excel-Files auslösen.
7. Download eines PNG-Files auslösen.

Falls `{shinytest2}` bereits im R-Setup besser passt, darf Codex stattdessen oder zusätzlich `{shinytest2}` verwenden.

### Check-Skript

Codex soll ein Skript erstellen oder aktualisieren:

```text
scripts/check_app.R
```

Dieses soll nach Möglichkeit ausführen:

```r
lintr::lint_package()
testthat::test_dir("tests/testthat")
```

Falls es kein R-Package ist, entsprechend anpassen.

---

## Phase 8: Dokumentation für Nutzer und Betreiber

### README aktualisieren

README sollte enthalten:

```text
- Zweck der App
- Beziehung zum Paper
- Link zum OSF-Repository, falls vorhanden
- erwartetes Inputformat
- lokale Installation
- lokale Ausführung
- Outputbeschreibung
- Datenschutz-/Session-Hinweis
- bekannte Grenzen
```

### Neue Dokumente

Codex soll diese Dateien erstellen oder aktualisieren:

```text
docs/APP_BASELINE_AUDIT.md
docs/SECURITY_AND_PRIVACY.md
docs/UI_MODERNIZATION_NOTES.md
docs/REGRESSION_TESTING.md
```

### SECURITY_AND_PRIVACY.md

Diese Datei soll knapp, aber konkret erklären:

- Welche Dateitypen akzeptiert werden.
- Welche Limits gelten.
- Wo Dateien temporär liegen.
- Wann Cleanup läuft.
- Was nicht gespeichert wird.
- Welche Annahmen vom Serverbetrieb abhängen, z. B. HTTPS, Reverse Proxy, Container, Systemlogs.

---

## Phase 9: Reihenfolge der konkreten Codex-Arbeit

Codex soll diese Reihenfolge einhalten:

1. Audit schreiben.
2. App lokal startbar machen.
3. Dependencies dokumentieren/fixen.
4. Beispielinput/Baseline sichern.
5. Regressionstests anlegen.
6. Upload-/Validierungslogik isolieren.
7. Session-Dateimanagement und Cleanup einbauen.
8. Analysefunktionen testbarer strukturieren.
9. Downloadlogik absichern.
10. UI mit bslib modernisieren.
11. Fehlermeldungen und Nutzerführung verbessern.
12. Browser-/E2E-Test ergänzen, falls praktikabel.
13. README und Security-Dokumentation schreiben.
14. Abschlussbericht mit offenen Punkten erstellen.

---

## Abschlussbericht von Codex

Am Ende soll Codex eine Datei erstellen:

```text
docs/MODERNIZATION_COMPLETION_REPORT.md
```

Inhalt:

```text
## Was wurde geändert?
## Welche fachlichen Funktionen blieben unverändert?
## Welche Tests wurden ergänzt?
## Welche Security-/Privacy-Maßnahmen wurden ergänzt?
## Welche UI-Komponenten wurden modernisiert?
## Wie startet man die App lokal?
## Wie führt man Tests aus?
## Welche Punkte bleiben offen?
```

---

## Akzeptanzkriterien für Aufgabe 1

Die Aufgabe gilt als erfolgreich abgeschlossen, wenn:

- Die App startet lokal mit dokumentiertem Befehl.
- Mindestens ein Beispielinput läuft durch.
- Kernoutputs bleiben gegenüber der Baseline gleich oder Abweichungen sind begründet dokumentiert.
- Upload-Validierung ist serverseitig vorhanden.
- Temporäre Session-Dateien werden pro Session erstellt und beim Session-Ende gelöscht.
- Downloads kommen nur aus dem Session-Ordner.
- UI ist auf Bootstrap 5 / bslib oder eine ähnlich moderne Shiny-Struktur gebracht.
- README, Security-/Privacy-Dokumentation und Testdokumentation sind vorhanden.
- Tests laufen mit einem dokumentierten Befehl.

---

## Wichtige Quellen für Codex

- Shiny `fileInput`: Uploads liegen in zufälligen Unterordnern des R-Prozess-Temp-Verzeichnisses; Shiny verfolgt diese Uploads pro Session und löscht sie beim Session-Ende. Zusätzlich soll diese App eigene generierte Dateien explizit bereinigen.  
  https://shiny.posit.co/r/reference/shiny/latest/fileinput.html

- Shiny Upload-Artikel: Standardlimit für Uploads ist 5 MB; `options(shiny.maxRequestSize = ...)` kann das Limit anpassen.  
  https://shiny.posit.co/r/articles/build/upload/

- Shiny `onStop`: Callback nach App-Ende oder Session-Ende, je nach Scope.  
  https://shiny.posit.co/r/reference/shiny/1.7.2/onstop.html

- Shiny Themes / bslib: Shiny integriert seit Version 1.6 `{bslib}` mit Zugriff auf moderne Bootstrap-Versionen, Bootswatch und Custom Themes.  
  https://shiny.posit.co/r/articles/build/themes/

- bslib Dashboards: Posit beschreibt `{bslib}` als moderne Richtung für Shiny-Dashboards mit Cards, Layouts und weiteren Dashboard-Komponenten.  
  https://shiny.posit.co/blog/posts/bslib-dashboards/

- Shiny Modules: offizielle Posit-Dokumentation zur Modularisierung größerer Shiny-Apps.  
  https://shiny.posit.co/r/articles/improve/modules/
