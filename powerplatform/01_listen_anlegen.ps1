<#
  WebERP Weberei – SharePoint-Listen anlegen (inkl. Demodaten)

  Voraussetzungen:
    1. PowerShell 7:            https://aka.ms/powershell
    2. PnP.PowerShell:          Install-Module PnP.PowerShell -Scope CurrentUser
    3. Eine eigene App-Registrierung für PnP (seit 09/2024 Pflicht), einmalig:
         Register-PnPEntraIDAppForInteractiveLogin -ApplicationName "PnP WebERP" -Tenant <firma>.onmicrosoft.com -Interactive
       Die ausgegebene Client-ID unten bei -ClientId eintragen.
    4. Eine SharePoint-Teamwebsite, z.B. https://<firma>.sharepoint.com/sites/Weberei

  Aufruf:
    ./01_listen_anlegen.ps1 -SiteUrl https://<firma>.sharepoint.com/sites/Weberei -ClientId <client-id>
    ./01_listen_anlegen.ps1 ... -OhneDemodaten

  Das Skript ist wiederholbar: vorhandene Listen und Spalten werden übersprungen.
#>
param(
  [Parameter(Mandatory)] [string] $SiteUrl,
  [Parameter(Mandatory)] [string] $ClientId,
  [switch] $OhneDemodaten
)
$ErrorActionPreference = 'Stop'
Connect-PnPOnline -Url $SiteUrl -ClientId $ClientId -Interactive

# ---------------------------------------------------------------------------
# Spalten-Helfer (Feld-XML, damit Datums- und Dezimalformate exakt stimmen)
# ---------------------------------------------------------------------------
function Txt($n)          { "<Field Type='Text' Name='$n' StaticName='$n' DisplayName='$n' />" }
function Num($n, $dec=2)  { "<Field Type='Number' Name='$n' StaticName='$n' DisplayName='$n' Decimals='$dec' />" }
function Dat($n)          { "<Field Type='DateTime' Format='DateOnly' Name='$n' StaticName='$n' DisplayName='$n' />" }
function Bool($n)         { "<Field Type='Boolean' Name='$n' StaticName='$n' DisplayName='$n'><Default>0</Default></Field>" }
function Choice($n, [string[]]$werte) {
  $c = ($werte | ForEach-Object { "<CHOICE>$_</CHOICE>" }) -join ''
  "<Field Type='Choice' Name='$n' StaticName='$n' DisplayName='$n' Format='Dropdown'><CHOICES>$c</CHOICES><Default>$($werte[0])</Default></Field>"
}

function Liste([string]$name, [string]$titelAnzeige, [string[]]$felder) {
  if (-not (Get-PnPList -Identity $name -ErrorAction SilentlyContinue)) {
    New-PnPList -Title $name -Template GenericList -OnQuickLaunch | Out-Null
    Write-Host "Liste $name angelegt" -ForegroundColor Green
  } else { Write-Host "Liste $name existiert bereits" -ForegroundColor Yellow }

  # Titel-Spalte = Belegnummer; nicht Pflicht, weil die App sie nach dem Anlegen setzt
  Set-PnPField -List $name -Identity Title -Values @{ Title = $titelAnzeige; Required = $false } | Out-Null

  $view = Get-PnPView -List $name | Where-Object DefaultView
  $viewFelder = @('LinkTitle')
  foreach ($xml in $felder) {
    $intern = ([xml]$xml).Field.Name
    if (-not (Get-PnPField -List $name -Identity $intern -ErrorAction SilentlyContinue)) {
      Add-PnPFieldFromXml -List $name -FieldXml $xml | Out-Null
    }
    $viewFelder += $intern
  }
  Set-PnPView -List $name -Identity $view.Id -Fields $viewFelder | Out-Null
}

# ---------------------------------------------------------------------------
# Listen
# ---------------------------------------------------------------------------
Liste 'Kunden' 'Nr' @(
  (Txt 'Name'), (Txt 'Ort'), (Txt 'EMail'), (Num 'Zahlziel' 0)
)
Liste 'Garne' 'Nr' @(
  (Txt 'Bezeichnung'), (Txt 'Material'), (Num 'Nm' 0), (Txt 'Farbe'),
  (Num 'Bestand' 1), (Num 'Mindestbestand' 0), (Num 'Preis' 2)
)
Liste 'Artikel' 'Nr' @(
  (Txt 'Bezeichnung'),
  (Choice 'Bindung' @('Leinwand','Köper 2/1','Köper 2/2','Köper 3/1','Atlas 5-bindig','Atlas 8-bindig','Jacquard')),
  (Num 'Breite' 0), (Num 'Schussdichte' 0),
  (Txt 'KettGarnNr'), (Num 'KettBedarf' 3), (Txt 'SchussGarnNr'), (Num 'SchussBedarf' 3),
  (Num 'Preis' 2), (Num 'Lager' 0)
)
Liste 'Maschinen' 'Nr' @(
  (Txt 'Bezeichnung'), (Choice 'Typ' @('Greifer','Luftdüse','Wasserdüse','Projektil','Schützen')),
  (Num 'Drehzahl' 0), (Num 'Nutzeffekt' 0), (Choice 'Status' @('Bereit','Läuft','Wartung','Störung'))
)
Liste 'Auftraege' 'Nr' @(
  (Txt 'KundeNr'), (Txt 'ArtikelNr'), (Num 'Meter' 0), (Dat 'Liefertermin'), (Dat 'Auftragsdatum'),
  (Choice 'Status' @('Offen','In Produktion','Fertig','Geliefert','Fakturiert')),
  (Txt 'MaschineNr'), (Num 'Produziert' 0), (Txt 'RechnungNr')
)
Liste 'Lagerbewegungen' 'Vorgang' @(
  (Txt 'Referenz'), (Txt 'Material'), (Num 'Menge' 1), (Txt 'Einheit')
)
Liste 'Rechnungen' 'Nr' @(
  (Txt 'AuftragNr'), (Txt 'KundeNr'), (Txt 'KundeName'), (Txt 'Positionstext'),
  (Num 'Menge' 0), (Num 'Preis' 2), (Num 'Netto' 2), (Num 'MwSt' 2), (Num 'Brutto' 2),
  (Dat 'Rechnungsdatum'), (Dat 'Faellig'), (Bool 'Bezahlt'), (Bool 'Versendet')
)

if ($OhneDemodaten) { Write-Host 'Fertig (ohne Demodaten).'; return }

# ---------------------------------------------------------------------------
# Demodaten (nur wenn die jeweilige Liste leer ist)
# ---------------------------------------------------------------------------
function Daten([string]$liste, [hashtable[]]$zeilen) {
  if ((Get-PnPListItem -List $liste -PageSize 1 | Measure-Object).Count -gt 0) {
    Write-Host "$liste enthält schon Daten – Demodaten übersprungen" -ForegroundColor Yellow; return
  }
  foreach ($z in $zeilen) { Add-PnPListItem -List $liste -Values $z | Out-Null }
  Write-Host "${liste}: $($zeilen.Count) Demodatensätze" -ForegroundColor Green
}
$heute = Get-Date

Daten 'Kunden' @(
  @{ Title='KD1001'; Name='Modehaus Berger GmbH'; Ort='München';   EMail='einkauf@example.com';   Zahlziel=30 },
  @{ Title='KD1002'; Name='Heimtex Schulz KG';    Ort='Bielefeld'; EMail='info@example.com';      Zahlziel=14 },
  @{ Title='KD1003'; Name='Polster & Co.';        Ort='Coburg';    EMail='bestellung@example.com'; Zahlziel=30 }
)
Daten 'Garne' @(
  @{ Title='GA2001'; Bezeichnung='Baumwolle gekämmt';  Material='CO 100%'; Nm=50; Farbe='Rohweiß';   Bestand=820; Mindestbestand=200; Preis=6.40 },
  @{ Title='GA2002'; Bezeichnung='Baumwolle gefärbt';  Material='CO 100%'; Nm=50; Farbe='Marine';    Bestand=310; Mindestbestand=150; Preis=8.10 },
  @{ Title='GA2003'; Bezeichnung='Leinen';             Material='LI 100%'; Nm=26; Farbe='Natur';     Bestand=140; Mindestbestand=120; Preis=14.50 },
  @{ Title='GA2004'; Bezeichnung='Polyester Filament'; Material='PES';     Nm=60; Farbe='Schwarz';   Bestand=450; Mindestbestand=100; Preis=4.20 },
  @{ Title='GA2005'; Bezeichnung='Schurwolle';         Material='WO 100%'; Nm=32; Farbe='Anthrazit'; Bestand=90;  Mindestbestand=100; Preis=18.90 }
)
Daten 'Artikel' @(
  @{ Title='AR3001'; Bezeichnung='Hemdenpopeline';         Bindung='Leinwand';       Breite=150; Schussdichte=36; KettGarnNr='GA2001'; KettBedarf=0.062; SchussGarnNr='GA2001'; SchussBedarf=0.055; Preis=7.80;  Lager=120 },
  @{ Title='AR3002'; Bezeichnung='Denim Marine';           Bindung='Köper 3/1';      Breite=160; Schussdichte=24; KettGarnNr='GA2002'; KettBedarf=0.21;  SchussGarnNr='GA2001'; SchussBedarf=0.17;  Preis=11.50; Lager=0 },
  @{ Title='AR3003'; Bezeichnung='Halbleinen Tischwäsche'; Bindung='Leinwand';       Breite=180; Schussdichte=18; KettGarnNr='GA2001'; KettBedarf=0.09;  SchussGarnNr='GA2003'; SchussBedarf=0.12;  Preis=13.90; Lager=45 },
  @{ Title='AR3004'; Bezeichnung='Bezugsstoff Wollmix';    Bindung='Atlas 5-bindig'; Breite=140; Schussdichte=22; KettGarnNr='GA2004'; KettBedarf=0.11;  SchussGarnNr='GA2005'; SchussBedarf=0.19;  Preis=24.00; Lager=0 }
)
Daten 'Maschinen' @(
  @{ Title='WM4001'; Bezeichnung='Dornier P1';       Typ='Greifer';   Drehzahl=550; Nutzeffekt=85; Status='Bereit' },
  @{ Title='WM4002'; Bezeichnung='Dornier P2';       Typ='Greifer';   Drehzahl=550; Nutzeffekt=85; Status='Bereit' },
  @{ Title='WM4003'; Bezeichnung='Picanol Omni';     Typ='Luftdüse';  Drehzahl=900; Nutzeffekt=88; Status='Bereit' },
  @{ Title='WM4004'; Bezeichnung='Sulzer Projektil'; Typ='Projektil'; Drehzahl=380; Nutzeffekt=80; Status='Wartung' },
  @{ Title='WM4005'; Bezeichnung='Jacquard J1';      Typ='Greifer';   Drehzahl=450; Nutzeffekt=78; Status='Bereit' }
)
Daten 'Auftraege' @(
  @{ Title='AU5001'; KundeNr='KD1001'; ArtikelNr='AR3001'; Meter=600; Liefertermin=$heute.AddDays(10); Auftragsdatum=$heute; Status='Offen'; Produziert=0 },
  @{ Title='AU5002'; KundeNr='KD1002'; ArtikelNr='AR3003'; Meter=400; Liefertermin=$heute.AddDays(18); Auftragsdatum=$heute; Status='Offen'; Produziert=0 },
  @{ Title='AU5003'; KundeNr='KD1003'; ArtikelNr='AR3004'; Meter=250; Liefertermin=$heute.AddDays(25); Auftragsdatum=$heute; Status='Offen'; Produziert=0 }
)
Write-Host 'Fertig.' -ForegroundColor Green
