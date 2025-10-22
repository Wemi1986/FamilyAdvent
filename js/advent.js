// Globale Variable zur Speicherung der geladenen YouTube-Player-Instanzen
const youtubePlayers = {};
let youtubeLinks = {}; // Speichert die Video-IDs aus der JSON-Datei

// Hauptlogik des Adventskalenders
// Promise returned from initializeCalendar is ignored Warnung: 'async' entfernt, da nur
// ein einfacher 'fetch' ohne weitere asynchrone Logik folgt.
function initializeCalendar() {
  // 1. YouTube Links aus JSON laden
  fetch('./Data/youtube_links.json')
      .then(response => {
        if (!response.ok) {
          // throw of exception caught locally Warnung: Fehlerbehandlung verbessert.
          throw new Error(`HTTP error! status: ${response.status}`);
        }
        return response.json();
      })
      .then(data => {
        youtubeLinks = data;

        // 2. Initialisierungsvariablen
        const today = new Date();
        const currentDay = today.getDate();
        // const currentDay = 24; // DEBUG: Zum Testen aller Türchen

        const doors = document.querySelectorAll('.door');

        doors.forEach(door => {
          const day = parseInt(door.getAttribute('data-day'), 10);
          const playerId = `player${day}`; // Die ID des Containers (z.B. 'player1')
          const localStorageKey = 'doorOpened' + day; // Schlüssel für localStorage

          // --- A. Persistenz (Zustand aus localStorage wiederherstellen) ---
          if (localStorage.getItem(localStorageKey) === 'true') {
            door.classList.add('flipped');
          }

          // --- B. Datumsprüfung und Aktivierung/Deaktivierung ---
          if (currentDay < day) {
            // Türchen liegt in der Zukunft
            door.classList.add('disabled');
          } else {
            // Türchen ist heute oder in der Vergangenheit
            door.classList.add('available');
          }

          // --- C. Klick-Ereignis-Handler ---
          door.addEventListener('click', function() {
            // 1. Prüfen auf Deaktivierung
            if (this.classList.contains('disabled')) {
              alert(`Das Türchen ${day} öffnet erst am ${day}. Dezember!`);
              return;
            }

            // 2. Türchen öffnen oder Status umschalten
            if (!this.classList.contains('flipped')) {
              // Türchen öffnen
              this.classList.add('flipped');
              localStorage.setItem(localStorageKey, 'true'); // Zustand speichern

              // YouTube Video laden und starten
              loadAndPlayVideo(day, playerId, true); // true = Autoplay
            } else {
              // Türchen ist bereits geöffnet, steuere das Video (Pausieren/Starten)
              const player = youtubePlayers[day];
              if (player && typeof player.getPlayerState === 'function') {
                const playerState = player.getPlayerState();
                // Prüft, ob das Video gerade spielt (1) oder buffert (3)
                if (playerState === 1 || playerState === 3) {
                  player.pauseVideo();
                } else {
                  player.playVideo();
                }
              } else {
                // Video wurde noch nicht geladen (z.B. nach Neuladen der Seite)
                loadAndPlayVideo(day, playerId, false); // Kein Autoplay, nur laden
              }
            }
          });
        });
      })
      .catch(error => {
        console.error("Fehler bei Initialisierung des Kalenders:", error);
        alert("Konnte Videodaten nicht laden oder es gab ein Netzwerkproblem.");
      });
}


/**
 * Lädt den YouTube Player in das Türchen und startet das Video.
 * @param {number} day - Die Nummer des Tags.
 * @param {string} playerId - Die ID des DIV-Containers.
 * @param {boolean} autoplay - Ob das Video sofort starten soll.
 */
function loadAndPlayVideo(day, playerId, autoplay) {
  const videoId = youtubeLinks[day.toString()];
  if (!videoId) {
    console.warn(`Keine Video-ID für Tag ${day} gefunden.`);
    return;
  }

  // Wenn der Player bereits initialisiert ist, spiele/pausiere ihn nur.
  if (youtubePlayers[day]) {
    if (autoplay) {
      youtubePlayers[day].playVideo();
    } else {
      youtubePlayers[day].pauseVideo();
    }
    return;
  }

  // Player erstellen
  // Unresolved variable or type YT/Player Warnung: Wird zur Laufzeit von der API gelöst.
  const player = new YT.Player(playerId, {
    videoId: videoId,
    width: '100%',
    height: '100%',
    playerVars: {
      'autoplay': autoplay ? 1 : 0,
      'controls': 1,
      'rel': 0,
      'showinfo': 0, // Tippfehler 'showinfo' korrigiert
      'modestbranding': 1 // Tippfehler 'modestbranding' korrigiert
    },
    events: {
      'onReady': (event) => {
        // Stellt sicher, dass der Player wirklich im DOM ist und bereit ist, zu starten.
        if (autoplay) {
          event.target.playVideo();
        }
      }
    }
  });

  // Speichere die Player-Instanz global
  // Local variable player is redundant Warnung: Kann ignoriert werden.
  youtubePlayers[day] = player;
}

// ----------------------------------------------------
// UNTERSTÜTZENDE FUNKTIONEN (z.B. für Login)
// ----------------------------------------------------

/**
 * Funktion zur Passwortprüfung (unabhängig vom Kalender).
 */
function checkPassword() {
  // 'var' is used instead of 'let' or 'const' korrigiert
  const passwordInput = document.getElementById('password').value;
  const correctPassword = 'Grosi'; // Tippfehler 'Grosi' (wenn es im Code 'Grosi' war)

  if (passwordInput === correctPassword) {
    window.location.href = 'adventskalender.html';
    return false;
  } else {
    alert('Falsches Passwort!');
    return false;
  }
}

// --- DOMContentLoaded Wrapper ---
document.addEventListener('DOMContentLoaded', () => {
  // Falls die YouTube API bereits geladen ist (sehr unwahrscheinlich), initialisiere direkt.
  // Ansonsten wartet die Initialisierung auf onYouTubeIframeAPIReady().
  if (typeof YT !== 'undefined' && YT.Player) {
    initializeCalendar();
  }
});