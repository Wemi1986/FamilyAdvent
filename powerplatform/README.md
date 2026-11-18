# WebERP Weberei – Power Platform

Die Weberei-App als **Power App** mit **Power-Automate-Flows**. Die Daten liegen in **SharePoint-Listen**.
Dafür reicht ein normaler Microsoft-365-Business-Plan, eine Premium-Lizenz ist nicht nötig.

```
 Power App (Tablet/Browser)          SharePoint-Website „Weberei“          Power Automate
 ─────────────────────────          ────────────────────────────          ─────────────────────
 Übersicht · Aufträge         ⇄     Kunden · Garne · Artikel        →     Rechnung als PDF mailen
 Produktion · Lager                 Maschinen · Auftraege                 Garn-Mindestbestand (täglich)
 Rechnungen · Stammdaten            Lagerbewegungen · Rechnungen          Offene Posten (werktags)
```

## Dateien

| Datei | Inhalt |
|---|---|
| `01_listen_anlegen.ps1` | Legt die 7 SharePoint-Listen mit allen Spalten an, optional mit Demodaten |
| `02_power_app.md` | Alle Bildschirme der App mit Steuerelementen und Formeln zum Einfügen |
| `03_flows.md` | Die drei Flows Schritt für Schritt |

## Einrichtung (ca. 2–3 Stunden)

1. **SharePoint-Website anlegen:** SharePoint → *Website erstellen* → *Teamwebsite*, z.B. `Weberei`.
2. **Listen anlegen:** `01_listen_anlegen.ps1` ausführen (Voraussetzungen stehen oben im Skript).
   Ohne PowerShell: Listen in SharePoint von Hand anlegen. Die Spaltennamen und -typen stehen im Skript im Abschnitt „Listen“.
   **Die Spaltennamen müssen exakt stimmen**, sonst passen die Formeln nicht.
3. **App bauen:** nach `02_power_app.md`.
4. **Flows bauen:** nach `03_flows.md`. Beim Rechnungs-Flow zuerst die **eigene** E-Mail-Adresse als Empfänger nehmen.
5. **Testen:** einmal den ganzen Ablauf durchspielen: Auftrag anlegen → Produktion starten → Meter zurückmelden →
   Abschließen → Liefern → Fakturieren → PDF-Mail prüfen → Zahlung buchen.
6. **Freigeben:** App mit den Mitarbeitern teilen (*Teilen* in Power Apps) und ihnen Zugriff auf die SharePoint-Website geben.

## Ablauf eines Auftrags

```
Offen ──Starten──▶ In Produktion ──Abschließen──▶ Fertig ──Liefern──▶ Geliefert ──Fakturieren──▶ Fakturiert
  │  (Garn wird abgebucht,          (Meter ins                (Ware aus dem               (Rechnung wird angelegt,
  │   Maschine belegt)               Fertigwarenlager)         Lager gebucht)              Flow mailt das PDF)
  └──Aus Lager bedienen──▶ Fertig   (wenn genug Fertigware da ist)
```

Jede Mengenänderung wird zusätzlich in der Liste `Lagerbewegungen` protokolliert. So lässt sich jeder Bestand nachvollziehen.

## Rechte und Sicherheit

- **Berechtigungen der SharePoint-Website** steuern, wer die Daten sieht. Mitarbeitende brauchen *Bearbeiten*-Rechte auf der Website,
  sonst kann die App nicht speichern. Löschen sollten nur Besitzer dürfen.
  Empfehlung: eine eigene Berechtigungsstufe „Bearbeiten ohne Löschen“ anlegen und den Mitarbeitern geben.
- **Versionsverlauf** ist bei SharePoint-Listen standardmäßig an: Jede Änderung an einem Datensatz ist nachvollziehbar
  und lässt sich wiederherstellen. Gelöschte Einträge liegen 93 Tage im Papierkorb.
- **Testumgebung:** Für größere Änderungen eine zweite Website `Weberei-Test` mit demselben Skript anlegen
  und die App dort zuerst ausprobieren. Eine Kopie der App zeigt dann auf die Test-Listen.

## Grenzen dieser Lösung (ehrlich gesagt)

- **Keine echten Transaktionen:** SharePoint kann mehrere Änderungen nicht als „alles oder nichts“ speichern.
  Bricht z.B. beim Start eines Auftrags die Verbindung ab, kann das Garn schon abgebucht sein, die Maschine aber noch frei.
  Dann steht es in `Lagerbewegungen`, und man korrigiert von Hand. Die App lädt vor jeder Buchung die Bestände neu
  (`Refresh`), damit zwei Personen nicht mit veralteten Zahlen buchen. Ganz ausschließen lässt sich das gleichzeitige Buchen
  zweier Personen aber nicht.
- **Delegierung:** Einige Formeln (z.B. „Bestand < Mindestbestand“, Summen) kann SharePoint nicht selbst auswerten.
  Power Apps rechnet dann nur mit den ersten 2000 Einträgen einer Liste. Bei Stammdaten und offenen Aufträgen ist das
  für eine kleine Weberei kein Problem. Die Liste `Lagerbewegungen` wird aber mit der Zeit groß; deshalb zeigt die App
  sie nur sortiert an und rechnet nicht mit ihr.
- **Wenn es wächst:** Mit einer Power-Apps-Premium-Lizenz kann man die Listen nach **Dataverse** umziehen.
  Dann gibt es echte Beziehungen, Rechte pro Tabelle und Zeile und serverseitige Geschäftslogik. Die Bildschirme bleiben weitgehend gleich.
