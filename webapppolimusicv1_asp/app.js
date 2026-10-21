/* =====================================================================
   app.js  —  PoliMusic (JavaScript Vanilla)
   ---------------------------------------------------------------------
   Diseño de cuadrícula de tarjetas (.song-card).
   Responsabilidades:
     1) Reproductor de audio (play/pausa, seek, volumen, "now playing").
     2) Incremento de reproducciones vía AJAX (songs.asp?accion=play).
     3) Clase .playing + ecualizador animado en la tarjeta activa.
     4) Modales del CRUD (crear / editar / eliminar) y validación.
     5) Placeholder SVG si una imagen no existe (por si acaso).
   ===================================================================== */

(function () {
    "use strict";

    /* ---------- Placeholder SVG para imágenes faltantes ---------- */
    // (También se define inline en el <head> para evitar carreras; aquí se
    //  mantiene como respaldo si app.js se usa de forma independiente.)
    function placeholderSVG(type) {
        var bg = type === "artist" ? "#2a2230" : "#241b1b";
        var svg = '<svg xmlns="http://www.w3.org/2000/svg" width="64" height="64" viewBox="0 0 64 64">' +
                  '<rect width="64" height="64" rx="12" fill="' + bg + '"/>' +
                  '<path d="M24 16l22 16-22 16z" fill="#ff7e6b" opacity="0.8"/></svg>';
        return "data:image/svg+xml;utf8," + encodeURIComponent(svg);
    }
    window.imgError = window.imgError || function (el, type) {
        if (!el || el.dataset.fallback) return;
        el.dataset.fallback = "1";
        el.src = placeholderSVG(type || "album");
    };

    /* ===================== REPRODUCTOR ===================== */
    var audio    = document.getElementById("audioEl");
    var btnPP    = document.getElementById("btnPlayPause");
    var seek     = document.getElementById("seekBar");
    var vol      = document.getElementById("volBar");
    var curEl    = document.getElementById("pcCurrent");
    var durEl    = document.getElementById("pcDuration");
    var npTitle  = document.getElementById("npTitle");
    var npArtist = document.getElementById("npArtist");
    var npCover  = document.getElementById("npCover");

    var currentId = null;
    var currentCard = null;

    function fmt(t) {
        if (!isFinite(t) || t < 0) t = 0;
        var m = Math.floor(t / 60);
        var s = Math.floor(t % 60);
        return m + ":" + (s < 10 ? "0" + s : s);
    }

    function setPlaying(card) {
        document.querySelectorAll(".song-card.playing").forEach(function (c) {
            if (c !== card) c.classList.remove("playing");
        });
        if (card) card.classList.add("playing");
        currentCard = card;
    }

    // Reproduce la canción asociada a una tarjeta.
    function playSong(card) {
        if (!card) return;
        var src = card.getAttribute("data-src");
        var id  = card.getAttribute("data-id");

        // Misma canción -> alternar play/pausa.
        if (currentId === id && audio.src && !audio.paused) {
            audio.pause();
            return;
        }

        audio.src = src;
        audio.load();
        var p = audio.play();
        if (p && typeof p.catch === "function") {
            p.catch(function () {
                npTitle.textContent = "No se pudo reproducir el archivo";
            });
        }

        currentId = id;
        npTitle.textContent  = card.getAttribute("data-title") || "Sin título";
        npArtist.textContent = card.getAttribute("data-artist") || "";
        npCover.src          = card.getAttribute("data-cover") || "";
        npCover.style.visibility = "visible";

        setPlaying(card);
        incrementPlays(id, card);
    }

    function incrementPlays(id, card) {
        var xhr = new XMLHttpRequest();
        xhr.open("GET", "songs.asp?accion=play&id=" + encodeURIComponent(id), true);
        xhr.onreadystatechange = function () {
            if (xhr.readyState === 4 && xhr.status === 200) {
                var n = parseInt(xhr.responseText, 10);
                if (!isNaN(n) && card) {
                    var span = card.querySelector(".plays");
                    if (span) span.textContent = n;
                }
            }
        };
        xhr.send();
    }

    if (btnPP) {
        btnPP.addEventListener("click", function () {
            if (!audio.src) {
                var first = document.querySelector(".song-card");
                if (first) playSong(first);
                return;
            }
            if (audio.paused) audio.play(); else audio.pause();
        });
    }

    if (audio) {
        audio.addEventListener("play",  function () { if (btnPP) btnPP.textContent = "❚❚"; });
        audio.addEventListener("pause", function () { if (btnPP) btnPP.textContent = "▶"; });
        audio.addEventListener("loadedmetadata", function () {
            durEl.textContent = fmt(audio.duration);
        });
        audio.addEventListener("timeupdate", function () {
            curEl.textContent = fmt(audio.currentTime);
            if (audio.duration) {
                seek.value = (audio.currentTime / audio.duration) * 100;
            }
        });
        audio.addEventListener("ended", function () {
            if (btnPP) btnPP.textContent = "▶";
            if (currentCard) currentCard.classList.remove("playing");
            // Auto-siguiente tarjeta.
            var cards = Array.prototype.slice.call(document.querySelectorAll(".song-card"));
            var idx = cards.indexOf(currentCard);
            if (idx > -1 && cards[idx + 1]) {
                playSong(cards[idx + 1]);
            }
        });
    }

    if (seek) {
        seek.addEventListener("input", function () {
            if (audio.duration) audio.currentTime = (seek.value / 100) * audio.duration;
        });
    }
    if (vol) {
        vol.addEventListener("input", function () { audio.volume = parseFloat(vol.value); });
        audio.volume = parseFloat(vol.value || "0.8");
    }

    /* ---- Interacción con las tarjetas ---- */
    document.querySelectorAll(".song-card").forEach(function (card) {
        card.addEventListener("click", function (e) {
            // No reproducir si se pulsó una herramienta de admin o el play.
            if (e.target.closest(".card-tools") || e.target.closest(".card-play")) return;
            playSong(card);
        });
    });

    document.querySelectorAll("[data-play]").forEach(function (btn) {
        btn.addEventListener("click", function (e) {
            e.stopPropagation();
            playSong(btn.closest(".song-card"));
        });
    });

    /* ===================== MODALES CRUD (solo Admin) ===================== */
    var overlay   = document.getElementById("modalOverlay");
    var delOverlay= document.getElementById("delOverlay");
    var crudForm  = document.getElementById("crudForm");
    var crudTitle = document.getElementById("modalTitle");
    var crudAction= document.getElementById("crudAction");
    var crudId    = document.getElementById("crudId");
    var crudName  = document.getElementById("crudName");
    var crudPath  = document.getElementById("crudPath");

    function openCreate() {
        if (!overlay) return;
        crudTitle.textContent = "Nueva canción";
        crudAction.value = "create";
        crudId.value = "";
        crudName.value = "";
        crudPath.value = "";
        overlay.hidden = false;
        crudName.focus();
    }
    function openEdit(btn) {
        if (!overlay) return;
        crudTitle.textContent = "Editar canción";
        crudAction.value = "edit";
        crudId.value = btn.getAttribute("data-edit");
        crudName.value = btn.getAttribute("data-name") || "";
        crudPath.value = btn.getAttribute("data-path") || "";
        overlay.hidden = false;
        crudName.focus();
    }
    function closeModal() { if (overlay) overlay.hidden = true; }

    var btnAdd = document.getElementById("btnAddSong");
    if (btnAdd) btnAdd.addEventListener("click", openCreate);

    document.querySelectorAll("[data-edit]").forEach(function (btn) {
        btn.addEventListener("click", function (e) { e.stopPropagation(); openEdit(btn); });
    });

    var mClose = document.getElementById("modalClose");
    var mCancel= document.getElementById("btnCancel");
    if (mClose)  mClose.addEventListener("click", closeModal);
    if (mCancel) mCancel.addEventListener("click", closeModal);
    if (overlay) overlay.addEventListener("click", function (e) {
        if (e.target === overlay) closeModal();
    });

    /* ---- Modal de eliminación ---- */
    function openDelete(btn) {
        if (!delOverlay) return;
        document.getElementById("delId").value = btn.getAttribute("data-del");
        document.getElementById("delName").textContent = btn.getAttribute("data-name") || "";
        delOverlay.hidden = false;
    }
    function closeDelete() { if (delOverlay) delOverlay.hidden = true; }

    document.querySelectorAll("[data-del]").forEach(function (btn) {
        btn.addEventListener("click", function (e) { e.stopPropagation(); openDelete(btn); });
    });
    var dClose = document.getElementById("delClose");
    var dCancel= document.getElementById("delCancel");
    if (dClose)  dClose.addEventListener("click", closeDelete);
    if (dCancel) dCancel.addEventListener("click", closeDelete);
    if (delOverlay) delOverlay.addEventListener("click", function (e) {
        if (e.target === delOverlay) closeDelete();
    });

    document.addEventListener("keydown", function (e) {
        if (e.key === "Escape") { closeModal(); closeDelete(); }
    });

    /* ---- Validación de formularios (cliente) ---- */
    if (crudForm) {
        crudForm.addEventListener("submit", function (e) {
            var ok = true;
            var name = crudName.value.trim();
            var path = crudPath.value.trim();
            if (name === "") { crudName.style.borderColor = "#ff6b6b"; ok = false; }
            else { crudName.style.borderColor = ""; }
            if (path === "" || path.indexOf("~/") !== 0 || path.toLowerCase().indexOf(".mp3") === -1) {
                crudPath.style.borderColor = "#ff6b6b"; ok = false;
            } else { crudPath.style.borderColor = ""; }
            if (!ok) {
                e.preventDefault();
                alert("Verifique los campos:\n• El nombre es obligatorio.\n• La ruta debe comenzar con '~/' y apuntar a un archivo .mp3");
            }
        });
    }

})();
