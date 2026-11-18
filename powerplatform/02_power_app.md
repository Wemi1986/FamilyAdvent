# Power App „WebERP Weberei“ – Bildschirme und Formeln

> **Formelschreibweise:** Alle Formeln sind in **deutscher** Schreibweise (`;` trennt Argumente,
> `;;` trennt Befehle, `0,19` ist eine Dezimalzahl). Ist dein Power Apps Studio auf Englisch,
> ersetze `;;` → `;`, dann `;` → `,` und `0,19` → `0.19`.

## 0. App anlegen

1. https://make.powerapps.com → **Erstellen** → **Leere App** → **Leere Canvas-App**, Name `WebERP Weberei`, Format **Tablet**.
2. Links **Daten** → **Daten hinzufügen** → **SharePoint** → deine Website → alle 7 Listen auswählen:
   `Kunden`, `Garne`, `Artikel`, `Maschinen`, `Auftraege`, `Lagerbewegungen`, `Rechnungen`.
3. **Einstellungen** → **Allgemein** → *Datenzeilenlimit* auf **2000** setzen (siehe „Grenzen“ in der README).
4. Bildschirme anlegen und genau so benennen:
   `scrUebersicht`, `scrAuftraege`, `scrAuftragNeu`, `scrProduktion`, `scrLager`, `scrRechnungen`,
   `scrKunden`, `scrGarne`, `scrArtikel`, `scrMaschinen`.
5. Auf jedem Bildschirm außer `scrUebersicht` oben links eine Schaltfläche „← Übersicht“ mit
   `OnSelect: Navigate(scrUebersicht; ScreenTransition.None)`.

**Nummernvergabe:** Die Belegnummern (KD…, AU…, RE… usw.) bildet die App aus der internen SharePoint-ID:
`"AU" & (5000 + ID)`. Deshalb wird jeder Datensatz erst angelegt und dann mit seiner Nummer versehen.

---

## 1. `scrUebersicht` – Dashboard

| Steuerelement | Eigenschaft | Formel |
|---|---|---|
| `lblOffeneAuftraege` (Bezeichnung) | Text | `CountRows(Filter(Auftraege; Status.Value = "Offen")) & " offene Aufträge"` |
| `lblMaschinen` | Text | `CountRows(Filter(Maschinen; Status.Value = "Läuft")) & " / " & CountRows(Maschinen) & " Webmaschinen in Betrieb"` |
| `lblUmsatz` | Text | `"Umsatz netto: " & Text(Sum(Rechnungen; Netto); "[$-de-DE]#.##0,00 €"; "de-DE")` |
| `lblOffenePosten` | Text | `"Offene Posten: " & Text(Sum(Filter(Rechnungen; Bezahlt = false); Brutto); "[$-de-DE]#.##0,00 €"; "de-DE")` |
| `scrUebersicht` | OnVisible | siehe unten |
| `galHinweise` (Katalog, vertikal, eine Bezeichnung) | Items | `colHinweise` |
| Bezeichnung in `galHinweise` | Text | `ThisItem.Text` |

`scrUebersicht.OnVisible` (sammelt die Hinweise bei jedem Öffnen der Übersicht neu):
```
Refresh(Garne);; Refresh(Auftraege);; Refresh(Maschinen);;
ClearCollect(colHinweise;
  ForAll(Filter(Garne; Bestand < Mindestbestand);
    {Text: "⚠ Garn " & Bezeichnung & " unter Mindestbestand (" & Bestand & " / " & Mindestbestand & " kg)"}));;
Collect(colHinweise;
  ForAll(Filter(Auftraege; Liefertermin < Today() && (Status.Value = "Offen" || Status.Value = "In Produktion"));
    {Text: "⏰ Auftrag " & Title & " ist überfällig"}));;
Collect(colHinweise;
  ForAll(Filter(Auftraege; Status.Value = "Fertig"); {Text: "📦 Auftrag " & Title & " ist bereit zur Lieferung"}));;
Collect(colHinweise;
  ForAll(Filter(Auftraege; Status.Value = "Geliefert"); {Text: "🧾 Auftrag " & Title & " ist noch nicht fakturiert"}));;
Collect(colHinweise;
  ForAll(Filter(Maschinen; Status.Value = "Wartung" || Status.Value = "Störung"); {Text: "🔧 " & Bezeichnung & ": " & Status.Value}))
```

Navigationsschaltflächen (je eine Schaltfläche):
`Navigate(scrAuftraege)`, `Navigate(scrProduktion)`, `Navigate(scrLager)`, `Navigate(scrRechnungen)`,
`Navigate(scrKunden)`, `Navigate(scrGarne)`, `Navigate(scrArtikel)`, `Navigate(scrMaschinen)`.

---

## 2. `scrAuftraege` – Kundenaufträge

| Steuerelement | Eigenschaft | Formel |
|---|---|---|
| `btnNeuerAuftrag` | OnSelect | `Navigate(scrAuftragNeu)` |
| `drpStatus` (Dropdown) | Items | `["Alle"; "Offen"; "In Produktion"; "Fertig"; "Geliefert"; "Fakturiert"]` |
| `galAuftraege` (Katalog, vertikal) | Items | `SortByColumns(Filter(Auftraege; drpStatus.Selected.Value = "Alle" \|\| Status.Value = drpStatus.Selected.Value); "Liefertermin"; SortOrder.Ascending)` |

Im Katalog `galAuftraege`:

| Steuerelement | Eigenschaft | Formel |
|---|---|---|
| `lblZeile1` | Text | `ThisItem.Title & " · " & LookUp(Kunden; Title = ThisItem.KundeNr).Name` |
| `lblZeile2` | Text | `LookUp(Artikel; Title = ThisItem.ArtikelNr).Bezeichnung & " · " & ThisItem.Meter & " m · Liefertermin " & Text(ThisItem.Liefertermin; "dd.mm.yyyy")` |
| `lblStatus` | Text | `ThisItem.Status.Value` |
| `lblStatus` | Color | `If(ThisItem.Liefertermin < Today() && ThisItem.Status.Value in ["Offen"; "In Produktion"]; Color.Red; Color.Black)` |
| `btnLiefern` | Visible | `ThisItem.Status.Value = "Fertig"` |
| `btnFakturieren` | Visible | `ThisItem.Status.Value = "Geliefert"` |
| `btnStorno` | Visible | `ThisItem.Status.Value = "Offen"` |
| `btnStorno` | OnSelect | `Remove(Auftraege; ThisItem);; Notify("Auftrag storniert")` |

`btnLiefern.OnSelect`:
```
Refresh(Artikel);;
With({art: LookUp(Artikel; Title = ThisItem.ArtikelNr)};
  If(art.Lager < ThisItem.Meter;
    Notify("Nicht genügend Fertigware am Lager"; NotificationType.Error);

    Patch(Artikel; art; {Lager: art.Lager - ThisItem.Meter});;
    Patch(Lagerbewegungen; Defaults(Lagerbewegungen);
      {Title: "Warenausgang"; Referenz: ThisItem.Title; Material: art.Bezeichnung; Menge: -ThisItem.Meter; Einheit: "m"});;
    Patch(Auftraege; ThisItem; {Status: {Value: "Geliefert"}});;
    Notify("Lieferung für " & ThisItem.Title & " gebucht"; NotificationType.Success)
  )
)
```

`btnFakturieren.OnSelect`:
```
With({art: LookUp(Artikel; Title = ThisItem.ArtikelNr); kd: LookUp(Kunden; Title = ThisItem.KundeNr)};
With({netto: ThisItem.Meter * art.Preis};
With({re: Patch(Rechnungen; Defaults(Rechnungen); {
        AuftragNr: ThisItem.Title; KundeNr: kd.Title; KundeName: kd.Name;
        Positionstext: art.Bezeichnung & " (" & art.Bindung.Value & ", " & art.Breite & " cm)";
        Menge: ThisItem.Meter; Preis: art.Preis;
        Netto: netto; MwSt: Round(netto * 0,19; 2); Brutto: Round(netto * 1,19; 2);
        Rechnungsdatum: Today(); Faellig: DateAdd(Today(); kd.Zahlziel; TimeUnit.Days);
        Bezahlt: false; Versendet: false})};
  Patch(Rechnungen; re; {Title: "RE" & (6000 + re.ID)});;
  Patch(Auftraege; ThisItem; {Status: {Value: "Fakturiert"}; RechnungNr: "RE" & (6000 + re.ID)});;
  Notify("Rechnung RE" & (6000 + re.ID) & " erstellt – der Flow verschickt sie per E-Mail"; NotificationType.Success)
)))
```

---

## 3. `scrAuftragNeu` – Neuer Auftrag

| Steuerelement | Eigenschaft | Formel |
|---|---|---|
| `drpKunde` (Dropdown) | Items / Value | `Kunden` / Value-Spalte `Name` |
| `drpArtikel` (Dropdown) | Items / Value | `Artikel` / Value-Spalte `Bezeichnung` |
| `txtMeter` (Texteingabe) | Format | `TextFormat.Number` |
| `dteTermin` (Datumsauswahl) | DefaultDate | `DateAdd(Today(); 14; TimeUnit.Days)` |
| `lblGarncheck` | Text | siehe unten |
| `btnSpeichern` | OnSelect | siehe unten |

`lblGarncheck.Text` (zeigt, ob das Garn reicht – nur zur Info, der Auftrag wird trotzdem angenommen):
```
With({a: drpArtikel.Selected; m: Value(txtMeter.Text)};
With({gk: LookUp(Garne; Title = a.KettGarnNr); gs: LookUp(Garne; Title = a.SchussGarnNr)};
  "Kette: " & gk.Bezeichnung & " " & Round(a.KettBedarf * m; 1) & " kg (Bestand " & gk.Bestand & ")" & Char(10) &
  "Schuss: " & gs.Bezeichnung & " " & Round(a.SchussBedarf * m; 1) & " kg (Bestand " & gs.Bestand & ")" & Char(10) &
  "Wert: " & Text(m * a.Preis; "[$-de-DE]#.##0,00 €"; "de-DE")
))
```

`btnSpeichern.OnSelect`:
```
If(Value(txtMeter.Text) <= 0 || IsBlank(drpKunde.Selected) || IsBlank(drpArtikel.Selected);
  Notify("Bitte Kunde, Artikel und eine Menge > 0 angeben"; NotificationType.Error);

  With({neu: Patch(Auftraege; Defaults(Auftraege); {
          KundeNr: drpKunde.Selected.Title; ArtikelNr: drpArtikel.Selected.Title;
          Meter: Value(txtMeter.Text); Liefertermin: dteTermin.SelectedDate; Auftragsdatum: Today();
          Status: {Value: "Offen"}; Produziert: 0})};
    Patch(Auftraege; neu; {Title: "AU" & (5000 + neu.ID)});;
    Notify("Auftrag AU" & (5000 + neu.ID) & " angelegt"; NotificationType.Success)
  );;
  Reset(txtMeter);;
  Navigate(scrAuftraege)
)
```

---

## 4. `scrProduktion` – Webereiplanung

### Katalog `galOffen` (offene Aufträge einplanen)

| Steuerelement | Eigenschaft | Formel |
|---|---|---|
| `galOffen` | Items | `SortByColumns(Filter(Auftraege; Status.Value = "Offen"); "Liefertermin"; SortOrder.Ascending)` |
| `lblAuftrag` | Text | `ThisItem.Title & " · " & LookUp(Artikel; Title = ThisItem.ArtikelNr).Bezeichnung & " · " & ThisItem.Meter & " m · bis " & Text(ThisItem.Liefertermin; "dd.mm.yyyy")` |
| `drpMaschine` (Dropdown im Katalog) | Items / Value | `Filter(Maschinen; Status.Value = "Bereit")` / Value-Spalte `Bezeichnung` |
| `lblLaufzeit` | Text | siehe unten |
| `btnStarten` | OnSelect | siehe unten |
| `btnAusLager` | Text / Visible | `"Aus Lager bedienen"` / `LookUp(Artikel; Title = ThisItem.ArtikelNr).Lager >= ThisItem.Meter` |
| `btnAusLager` | OnSelect | `Patch(Auftraege; ThisItem; {Status: {Value: "Fertig"}; Produziert: ThisItem.Meter})` |

`lblLaufzeit.Text` – Leistung = Drehzahl × 60 / (Schussdichte × 100) × Nutzeffekt:
```
With({m: drpMaschine.Selected; art: LookUp(Artikel; Title = ThisItem.ArtikelNr)};
With({mh: m.Drehzahl * 60 / (art.Schussdichte * 100) * m.Nutzeffekt / 100};
  If(IsBlank(m); "Keine Maschine frei";
     Round(mh; 1) & " m/h · ca. " & Round(ThisItem.Meter / mh; 0) & " h")
))
```

`btnStarten.OnSelect` – prüft das Garn, bucht Kett- und Schussgarn ab und belegt die Maschine:
```
Refresh(Garne);; Refresh(Maschinen);;
With({art: LookUp(Artikel; Title = ThisItem.ArtikelNr); m: LookUp(Maschinen; ID = drpMaschine.Selected.ID)};
With({k: art.KettGarnNr; s: art.SchussGarnNr;
      kBed: art.KettBedarf * ThisItem.Meter; sBed: art.SchussBedarf * ThisItem.Meter};
With({gk: LookUp(Garne; Title = k); gs: LookUp(Garne; Title = s)};
  If(
    IsBlank(m) || m.Status.Value <> "Bereit";
      Notify("Bitte eine freie Maschine wählen"; NotificationType.Error);

    If(k = s; gk.Bestand < kBed + sBed; gk.Bestand < kBed || gs.Bestand < sBed);
      Notify("Garnbestand reicht nicht – erst Wareneingang buchen"; NotificationType.Error);

    // Garn abbuchen (gleiches Garn für Kette und Schuss nur einmal buchen)
    Patch(Garne; gk; {Bestand: gk.Bestand - If(k = s; kBed + sBed; kBed)});;
    If(k <> s; Patch(Garne; gs; {Bestand: gs.Bestand - sBed}));;
    Patch(Lagerbewegungen; Defaults(Lagerbewegungen);
      {Title: "Garnverbrauch Kette"; Referenz: ThisItem.Title; Material: gk.Bezeichnung; Menge: -kBed; Einheit: "kg"});;
    Patch(Lagerbewegungen; Defaults(Lagerbewegungen);
      {Title: "Garnverbrauch Schuss"; Referenz: ThisItem.Title; Material: gs.Bezeichnung; Menge: -sBed; Einheit: "kg"});;
    Patch(Maschinen; m; {Status: {Value: "Läuft"}});;
    Patch(Auftraege; ThisItem; {Status: {Value: "In Produktion"}; MaschineNr: m.Title; Produziert: 0});;
    Notify(ThisItem.Title & " läuft auf " & m.Bezeichnung; NotificationType.Success)
  )
)))
```

### Katalog `galLaufend` (laufende Fertigungsaufträge)

| Steuerelement | Eigenschaft | Formel |
|---|---|---|
| `galLaufend` | Items | `Filter(Auftraege; Status.Value = "In Produktion")` |
| `lblLauf` | Text | `ThisItem.Title & " · " & LookUp(Maschinen; Title = ThisItem.MaschineNr).Bezeichnung & " · " & ThisItem.Produziert & " / " & ThisItem.Meter & " m"` |
| `rectFortschritt` (Rechteck) | Width | `300 * Min(1; ThisItem.Produziert / ThisItem.Meter)` |
| `txtMenge` (Texteingabe, Zahl) | HintText | `"gewebte Meter"` |
| `btnRueckmelden` | OnSelect | siehe unten |
| `btnAbschliessen` | OnSelect | siehe unten |

`btnRueckmelden.OnSelect`:
```
If(Value(txtMenge.Text) <= 0;
  Notify("Bitte Meter > 0 eingeben"; NotificationType.Error);

  Patch(Auftraege; ThisItem; {Produziert: ThisItem.Produziert + Value(txtMenge.Text)});;
  Patch(Lagerbewegungen; Defaults(Lagerbewegungen);
    {Title: "Rückmeldung"; Referenz: ThisItem.Title;
     Material: LookUp(Artikel; Title = ThisItem.ArtikelNr).Bezeichnung; Menge: Value(txtMenge.Text); Einheit: "m"});;
  Reset(txtMenge);;
  Notify("Rückmeldung gebucht"; NotificationType.Success)
)
```

`btnAbschliessen.OnSelect` – bucht die Ware ins Fertigwarenlager und gibt die Maschine frei:
```
With({art: LookUp(Artikel; Title = ThisItem.ArtikelNr);
      m: LookUp(Maschinen; Title = ThisItem.MaschineNr);
      menge: Max(ThisItem.Produziert; ThisItem.Meter)};
  Patch(Artikel; art; {Lager: art.Lager + menge});;
  Patch(Lagerbewegungen; Defaults(Lagerbewegungen);
    {Title: "Fertigmeldung"; Referenz: ThisItem.Title; Material: art.Bezeichnung; Menge: menge; Einheit: "m"});;
  Patch(Maschinen; m; {Status: {Value: "Bereit"}});;
  Patch(Auftraege; ThisItem; {Status: {Value: "Fertig"}; Produziert: menge});;
  Notify(ThisItem.Title & " fertig – " & menge & " m ans Lager"; NotificationType.Success)
)
```

---

## 5. `scrLager`

| Steuerelement | Eigenschaft | Formel |
|---|---|---|
| `galGarnlager` | Items | `Garne` |
| Bezeichnung im Katalog | Text | `ThisItem.Bezeichnung & " " & ThisItem.Farbe & ": " & ThisItem.Bestand & " kg (min. " & ThisItem.Mindestbestand & ")"` |
| Bezeichnung im Katalog | Color | `If(ThisItem.Bestand < ThisItem.Mindestbestand; Color.Red; Color.Black)` |
| `galFertigware` | Items | `Artikel` |
| Bezeichnung im Katalog | Text | `ThisItem.Bezeichnung & ": " & ThisItem.Lager & " m"` |
| `lblGarnwert` | Text | `"Garnlager: " & Text(Sum(Garne; Bestand * Preis); "[$-de-DE]#.##0,00 €"; "de-DE")` |
| `drpGarn` (Dropdown) | Items / Value | `Garne` / Value-Spalte `Bezeichnung` |
| `txtKg` (Texteingabe, Zahl) | HintText | `"kg"` |
| `txtLieferschein` | HintText | `"Lieferant / Lieferschein"` |
| `btnWareneingang` | OnSelect | siehe unten |
| `galBewegungen` | Items | `SortByColumns(Lagerbewegungen; "Created"; SortOrder.Descending)` |
| Bezeichnung im Katalog | Text | `Text(ThisItem.Created; "dd.mm.yyyy hh:mm") & " · " & ThisItem.Title & " · " & ThisItem.Referenz & " · " & ThisItem.Material & " · " & ThisItem.Menge & " " & ThisItem.Einheit` |

`btnWareneingang.OnSelect`:
```
Refresh(Garne);;
With({g: LookUp(Garne; ID = drpGarn.Selected.ID); kg: Value(txtKg.Text)};
  If(kg <= 0;
    Notify("Bitte Menge > 0 eingeben"; NotificationType.Error);

    Patch(Garne; g; {Bestand: g.Bestand + kg});;
    Patch(Lagerbewegungen; Defaults(Lagerbewegungen);
      {Title: "Wareneingang"; Referenz: Coalesce(txtLieferschein.Text; "–"); Material: g.Bezeichnung; Menge: kg; Einheit: "kg"});;
    Reset(txtKg);; Reset(txtLieferschein);;
    Notify(kg & " kg " & g.Bezeichnung & " eingebucht"; NotificationType.Success)
  )
)
```

---

## 6. `scrRechnungen`

| Steuerelement | Eigenschaft | Formel |
|---|---|---|
| `galRechnungen` | Items | `SortByColumns(Rechnungen; "Created"; SortOrder.Descending)` |
| `lblRe1` | Text | `ThisItem.Title & " · " & ThisItem.KundeName & " · Auftrag " & ThisItem.AuftragNr` |
| `lblRe2` | Text | `Text(ThisItem.Brutto; "[$-de-DE]#.##0,00 €"; "de-DE") & " brutto · fällig " & Text(ThisItem.Faellig; "dd.mm.yyyy") & " · " & If(ThisItem.Bezahlt; "bezahlt"; ThisItem.Faellig < Today(); "ÜBERFÄLLIG"; "offen") & If(ThisItem.Versendet; " · versendet"; "")` |
| `lblRe2` | Color | `If(!ThisItem.Bezahlt && ThisItem.Faellig < Today(); Color.Red; Color.Black)` |
| `btnBezahlt` | Visible | `!ThisItem.Bezahlt` |
| `btnBezahlt` | OnSelect | `Patch(Rechnungen; ThisItem; {Bezahlt: true});; Notify("Zahlungseingang gebucht"; NotificationType.Success)` |

Das PDF und den E-Mail-Versand erledigt der Flow „Rechnung versenden“ (siehe `03_flows.md`).

---

## 7. Stammdaten: `scrKunden`, `scrGarne`, `scrArtikel`, `scrMaschinen`

Alle vier Bildschirme sind gleich aufgebaut: links ein Katalog, rechts ein Bearbeitungsformular.
Beispiel **Kunden** (bei den anderen Listennamen und Präfix tauschen):

| Steuerelement | Eigenschaft | Formel |
|---|---|---|
| `galKunden` | Items | `Kunden` |
| `frmKunden` (Formular bearbeiten) | DataSource / Item | `Kunden` / `galKunden.Selected` |
| `frmKunden` | Felder | alle Spalten außer `Nr` (die Nummer vergibt die App) |
| `btnNeu` | OnSelect | `NewForm(frmKunden)` |
| `btnSpeichern` | OnSelect | `SubmitForm(frmKunden)` |
| `frmKunden` | OnSuccess | `If(IsBlank(Self.LastSubmit.Title); Patch(Kunden; Self.LastSubmit; {Title: "KD" & (1000 + Self.LastSubmit.ID)}));; Notify("Gespeichert"; NotificationType.Success)` |

| Bildschirm | Liste | Präfix in OnSuccess |
|---|---|---|
| `scrKunden` | `Kunden` | `"KD" & (1000 + …ID)` |
| `scrGarne` | `Garne` | `"GA" & (2000 + …ID)` |
| `scrArtikel` | `Artikel` | `"AR" & (3000 + …ID)` |
| `scrMaschinen` | `Maschinen` | `"WM" & (4000 + …ID)` |

**Tipps:**
- **Artikel:** Für `KettGarnNr` und `SchussGarnNr` die Karte entsperren und das Textfeld durch ein Dropdown ersetzen
  (`Items: Garne`, Value-Spalte `Title`, Karte `Update: dropdown.Selected.Title`), damit niemand Garnnummern abtippen muss.
- **Maschinen:** Im Formular beim Feld `Status` die Eigenschaft `DisplayMode` auf
  `If(ThisItem.Status.Value = "Läuft"; DisplayMode.View; DisplayMode.Edit)` setzen. Eine laufende Maschine
  wird nur über „Abschließen“ wieder frei.
- **Löschen:** Keine Lösch-Schaltfläche in die Stammdaten einbauen. Kunden, Artikel und Garne, die in Aufträgen
  stehen, sollen erhalten bleiben. Löschen nur in SharePoint und nur durch Admins.
