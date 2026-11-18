# Power Automate – Flows für WebERP Weberei

Alle drei Flows nutzen nur **Standard-Connectoren** (SharePoint, Office 365 Outlook, OneDrive for Business).
Anlegen unter https://make.powerautomate.com → **Erstellen**.

> Die Ausdrücke (`formatNumber(...)` usw.) sind in Power Automate immer in englischer Schreibweise,
> unabhängig von der Sprache. Sie werden im Feld **Ausdruck** (fx) eingefügt.

| Flow | Auslöser | Was er tut |
|---|---|---|
| 1. Rechnung versenden | Rechnung in SharePoint angelegt | Rechnung als PDF erzeugen und dem Kunden mailen |
| 2. Garn-Mindestbestand | täglich 07:00 | Mail an den Einkauf mit allen Garnen unter Mindestbestand |
| 3. Offene Posten | werktags 08:00 | Mail an die Buchhaltung mit allen überfälligen Rechnungen |

---

## Flow 1: „WebERP – Rechnung versenden“

**Typ:** Automatisierter Cloud-Flow

### 1. Auslöser: SharePoint – *Wenn ein Element erstellt oder geändert wird*
- Websiteadresse: deine Weberei-Website, Listenname: `Rechnungen`
- **Einstellungen** des Auslösers → **Auslösebedingungen** → hinzufügen:
  ```
  @and(not(empty(triggerBody()?['Title'])), equals(triggerBody()?['Versendet'], false))
  ```
  Damit startet der Flow erst, wenn die App die Rechnungsnummer gesetzt hat, und nur einmal pro Rechnung.

### 2. SharePoint – *Elemente abrufen* (umbenennen in `Kunde_abrufen`)
- Liste: `Kunden`
- Filterabfrage: `Title eq '@{triggerBody()?['KundeNr']}'`
- Obere Anzahl: `1`

### 3. *Verfassen* (umbenennen in `Rechnung_HTML`) – Eingaben:
```html
<html><body style="font-family:Arial;font-size:11pt">
<p><b>Weberei Musterstadt GmbH</b><br>Webereistraße 1 · 12345 Musterstadt</p>
<p style="margin-top:30px">@{triggerBody()?['KundeName']}</p>
<h2>Rechnung @{triggerBody()?['Title']}</h2>
<p>Datum: @{formatDateTime(triggerBody()?['Rechnungsdatum'],'dd.MM.yyyy')}<br>
Auftrag: @{triggerBody()?['AuftragNr']}<br>Kunden-Nr.: @{triggerBody()?['KundeNr']}</p>
<table border="1" cellpadding="6" style="border-collapse:collapse;width:100%">
<tr><th>Bezeichnung</th><th>Menge</th><th>Preis/m</th><th>Betrag</th></tr>
<tr><td>@{triggerBody()?['Positionstext']}</td>
<td align="right">@{formatNumber(triggerBody()?['Menge'],'N0','de-DE')} m</td>
<td align="right">@{formatNumber(triggerBody()?['Preis'],'N2','de-DE')} €</td>
<td align="right">@{formatNumber(triggerBody()?['Netto'],'N2','de-DE')} €</td></tr>
<tr><td colspan="3" align="right">MwSt. 19 %</td><td align="right">@{formatNumber(triggerBody()?['MwSt'],'N2','de-DE')} €</td></tr>
<tr><td colspan="3" align="right"><b>Gesamtbetrag</b></td><td align="right"><b>@{formatNumber(triggerBody()?['Brutto'],'N2','de-DE')} €</b></td></tr>
</table>
<p>Zahlbar bis @{formatDateTime(triggerBody()?['Faellig'],'dd.MM.yyyy')} ohne Abzug.</p>
</body></html>
```
(Firmenname und Adresse durch deine echten Daten ersetzen; Bankverbindung, Steuernummer usw. ergänzen.)

### 4. OneDrive for Business – *Datei erstellen*
- Ordnerpfad: `/WebERP/Rechnungen`
- Dateiname: `@{triggerBody()?['Title']}.html`
- Dateiinhalt: Ausgaben von `Rechnung_HTML`

### 5. OneDrive for Business – *Datei konvertieren*
- Datei: **ID** aus „Datei erstellen“
- Zieltyp: `PDF`

### 6. Office 365 Outlook – *E-Mail senden (V2)*
- An: `@{first(outputs('Kunde_abrufen')?['body/value'])?['EMail']}`
  **→ In der Testphase hier deine eigene Adresse eintragen**, damit keine Testrechnung an echte Kunden geht.
- Betreff: `Rechnung @{triggerBody()?['Title']} – Weberei Musterstadt`
- Text: kurzer Anschreibentext
- Anlagen: Name `@{triggerBody()?['Title']}.pdf`, Inhalt **Dateiinhalt** aus „Datei konvertieren“

### 7. SharePoint – *Element aktualisieren*
- Liste: `Rechnungen`, ID: **ID** aus dem Auslöser
- `Versendet`: `Ja`

Die Rechnung ist danach in der App als „versendet“ markiert; die Auslösebedingung verhindert einen zweiten Versand.

---

## Flow 2: „WebERP – Garn-Mindestbestand“

**Typ:** Geplanter Cloud-Flow, täglich 07:00

1. **SharePoint – Elemente abrufen:** Liste `Garne`
2. **Datenvorgang – Array filtern**
   - Von: `value` aus „Elemente abrufen“
   - Bedingung (im erweiterten Modus):
     ```
     @less(item()?['Bestand'], item()?['Mindestbestand'])
     ```
   (Spalte gegen Spalte kann SharePoint nicht selbst filtern, deshalb hier im Flow.)
3. **Bedingung:** `@{length(body('Array_filtern'))}` *ist größer als* `0`
4. **Bei Ja:**
   - **Datenvorgang – Auswählen** (Von: `body('Array_filtern')`), Zuordnung:

     | Schlüssel | Wert |
     |---|---|
     | Garn | `item()?['Title']` |
     | Bezeichnung | `concat(item()?['Bezeichnung'], ' ', item()?['Farbe'])` |
     | Bestand kg | `item()?['Bestand']` |
     | Mindestbestand kg | `item()?['Mindestbestand']` |
     | Fehlmenge kg | `sub(item()?['Mindestbestand'], item()?['Bestand'])` |

   - **HTML-Tabelle erstellen** aus der Ausgabe von „Auswählen“
   - **E-Mail senden (V2)** an den Einkauf, Betreff `Garn nachbestellen`, Text = HTML-Tabelle

---

## Flow 3: „WebERP – Offene Posten“

**Typ:** Geplanter Cloud-Flow, Mo–Fr 08:00

1. **SharePoint – Elemente abrufen:** Liste `Rechnungen`, Filterabfrage:
   ```
   Bezahlt eq 0 and Faellig lt '@{formatDateTime(utcNow(),'yyyy-MM-dd')}'
   ```
2. **Bedingung:** `@{length(outputs('Elemente_abrufen')?['body/value'])}` *ist größer als* `0`
3. **Bei Ja:** **Auswählen** (Rechnung = `Title`, Kunde = `KundeName`, Betrag = `formatNumber(item()?['Brutto'],'N2','de-DE')`,
   Fällig seit = `formatDateTime(item()?['Faellig'],'dd.MM.yyyy')`) → **HTML-Tabelle erstellen** →
   **E-Mail senden (V2)** an die Buchhaltung.

Mahnungen an Kunden gehen bewusst **nicht** automatisch raus. Die Buchhaltung entscheidet selbst, wer gemahnt wird.

---

## Tipps

- **Flows in eine Lösung packen:** Lege App und Flows unter **Lösungen** → **Neue Lösung** an. Dann lassen sie
  sich gemeinsam exportieren, sichern und in eine zweite Umgebung (Test → Produktion) übertragen.
- **Verbindungen:** Flows laufen mit den Rechten des Erstellers. Am besten einen Funktions-Account
  (z.B. `weberp@firma.de`) als Besitzer verwenden, damit nichts stoppt, wenn ein Mitarbeiter geht.
- **Fehler mitbekommen:** Unter *Meine Flows* → Flow → *Ausführungsverlauf* siehst du jeden Lauf.
  Zusätzlich kannst du dich unter *Einstellungen* über Fehler per Mail benachrichtigen lassen.
