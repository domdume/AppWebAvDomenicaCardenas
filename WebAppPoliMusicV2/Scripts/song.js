(function () {
    'use strict';
    var audio = document.getElementById('audioPlayer'), title = document.getElementById('nowTitle'), status = document.getElementById('playerStatus');
    var tracks = Array.prototype.slice.call(document.querySelectorAll('.track-play')), current = -1;
    function available() { return tracks.filter(function (t) { return !t.disabled && !t.closest('tr').hidden; }); }
    function mark(playing) { tracks.forEach(function (t, i) { t.classList.toggle('is-playing', playing && i === current); t.setAttribute('aria-pressed', playing && i === current ? 'true' : 'false'); }); }
    function start(track) {
        if (!track || track.disabled) return;
        var index = tracks.indexOf(track);
        if (index === current && !audio.paused) { audio.pause(); return; }
        if (index !== current) { current = index; audio.src = track.dataset.src; title.textContent = track.dataset.title; }
        var attempt = audio.play();
        if (attempt) attempt.catch(function () { status.textContent = 'No se pudo reproducir. Revisa el archivo de audio o pulsa reproducir.'; mark(false); });
    }
    tracks.forEach(function (t) { if (!t.dataset.src) { t.disabled = true; t.title = 'Archivo de audio no disponible en SongFiles'; t.setAttribute('aria-label', t.title); } t.addEventListener('click', function () { start(t); }); });
    var playAll = document.getElementById('playAll');
    playAll.disabled = available().length === 0;
    playAll.addEventListener('click', function () { start(available()[0]); });
    function step(direction) { var list = available(); if (!list.length) return; var i = list.indexOf(tracks[current]); start(list[(i + direction + list.length) % list.length]); }
    document.getElementById('previousTrack').addEventListener('click', function () { step(-1); });
    document.getElementById('nextTrack').addEventListener('click', function () { step(1); });
    audio.addEventListener('play', function () { status.textContent = 'Reproduciendo ahora'; mark(true); });
    audio.addEventListener('pause', function () { status.textContent = 'En pausa'; mark(false); });
    audio.addEventListener('ended', function () { mark(false); var list = available(), i = list.indexOf(tracks[current]); if (i >= 0 && i + 1 < list.length) start(list[i + 1]); else status.textContent = 'Fin de la biblioteca'; });
    audio.addEventListener('error', function () { status.textContent = 'El archivo no está disponible o su formato no es compatible.'; mark(false); });
    document.getElementById('songSearch').addEventListener('input', function () { var query = this.value.toLocaleLowerCase().trim(), count = 0; tracks.forEach(function (t) { var match = t.dataset.title.toLocaleLowerCase().indexOf(query) !== -1; t.closest('tr').hidden = !match; if (match) count++; }); document.getElementById('noResults').hidden = count > 0 || tracks.length === 0; playAll.disabled = available().length === 0; });
}());
