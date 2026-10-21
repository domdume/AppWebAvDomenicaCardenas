<%@ Language="VBScript" %>
<% Option Explicit %>
<!--#include file="db_connection.asp" -->
<%
' =====================================================================
'  songs.asp  —  Pantalla principal de canciones de PoliMusic
' ---------------------------------------------------------------------
'  • Valida sesión (redirige a login.asp si no hay usuario).
'  • Muestra mensaje de bienvenida con nombre y foto del usuario.
'  • CONTROL DE ROLES (RBAC):
'        USER_TYPE = 0 (Normal) -> solo lectura + reproducir.
'        USER_TYPE = 1 (Admin)  -> además ve y ejecuta el CRUD completo.
'  • Lista las canciones enriquecidas con álbum y artista (LEFT JOIN).
'  • Reproductor de audio HTML5 controlado por JavaScript.
'  • El CRUD se procesa en el MISMO archivo (POST) y SIEMPRE valida
'    en el servidor que Session("user_type") = 1.
' =====================================================================

' ---------------------------------------------------------------------
'  1) VALIDACIÓN DE SESIÓN
' ---------------------------------------------------------------------
If Session("username") = "" Then
    Response.Redirect "login.asp"
    Response.End
End If

' ---------------------------------------------------------------------
'  2) DATOS DEL USUARIO LOGUEADO (re-consulta para foto y rol reales)
' ---------------------------------------------------------------------
Dim uRs, uSql, uCmd
Dim sUsername, sUserPhoto, iUserType, iUserId
sUsername  = Session("username")
sUserPhoto = ""
iUserType  = 0
iUserId    = 0

uSql = "SELECT ID_USER, USER_PHOTO, USER_TYPE FROM TBL_USER WHERE USERNAME = ?"
Set uCmd = Comando(uSql, Array(Array("u", 200, 50, sUsername)))
Set uRs  = uCmd.Execute
If Not uRs.EOF Then
    iUserId    = uRs("ID_USER")
    sUserPhoto = uRs("USER_PHOTO") & ""
    iUserType  = CInt(uRs("USER_TYPE"))
End If
uRs.Close : Set uRs = Nothing : Set uCmd = Nothing

' Forzamos coherencia de la sesión con lo que hay en BD.
Session("user_type")  = iUserType
Session("user_photo") = sUserPhoto

Dim bIsAdmin
bIsAdmin = (iUserType = 1)

' ---------------------------------------------------------------------
'  3) API AJAX: incrementar reproducciones (accion=play&id=NN)
'     Disponible para CUALQUIER usuario logueado (ambos roles reproducen).
' ---------------------------------------------------------------------
If LCase(Request.QueryString("accion")) = "play" Then
    Dim pid, pSql, pCmd, pRs, pNew
    pid = Request.QueryString("id")
    If IsNumeric(pid) Then
        ' Leemos el valor actual y lo incrementamos (operación atómica en SQL).
        pSql = "UPDATE TBL_SONG SET PLAYS = PLAYS + 1 OUTPUT INSERTED.PLAYS WHERE ID_SONG = ?"
        Set pCmd = Comando(pSql, Array(Array("id", 3, "", CLng(pid))))
        Set pRs  = pCmd.Execute
        If Not pRs.EOF Then pNew = pRs(0) Else pNew = 0
        If IsObject(pRs) Then pRs.Close
        Set pRs = Nothing : Set pCmd = Nothing
        CerrarConexion
        Response.ContentType = "text/plain"
        Response.Write pNew
        Response.End
    End If
    CerrarConexion
    Response.Write "0"
    Response.End
End If

' ---------------------------------------------------------------------
'  4) PROCESAMIENTO DEL CRUD (POST) — SOLO ADMIN
'     Validación en servidor: si no es admin, se rechaza siempre.
' ---------------------------------------------------------------------
Dim crudMsg, crudType
crudMsg = ""
crudType = ""

If Request.Form("crud_action") <> "" Then
    If Not bIsAdmin Then
        ' >>> Seguridad: nadie salvo el admin puede mutar TBL_SONG <<<
        crudMsg  = "Acceso denegado: se requiere rol de Administrador."
        crudType = "error"
    Else
        Dim ca, cName, cPath, cId
        ca    = Request.Form("crud_action")
        cName = Trim(Request.Form("song_name"))
        cPath = Trim(Request.Form("song_path"))
        cId   = Request.Form("id_song")

        If ca = "create" Then
            If cName = "" Or cPath = "" Then
                crudMsg  = "Nombre y ruta de la canción son obligatorios."
                crudType = "error"
            Else
                Dim cCmd
                Set cCmd = Comando( _
                    "INSERT INTO TBL_SONG (SONG_NAME, SONG_PATH, PLAYS) VALUES (?, ?, 0)", _
                    Array(Array("n", 200, 50, cName), Array("p", 200, 255, cPath)) _
                )
                cCmd.Execute
                Set cCmd = Nothing
                crudMsg  = "Canción creada correctamente."
                crudType = "success"
            End If

        ElseIf ca = "edit" Then
            If Not IsNumeric(cId) Or cName = "" Or cPath = "" Then
                crudMsg  = "Datos inválidos para la edición."
                crudType = "error"
            Else
                Dim eCmd
                Set eCmd = Comando( _
                    "UPDATE TBL_SONG SET SONG_NAME = ?, SONG_PATH = ? WHERE ID_SONG = ?", _
                    Array(Array("n", 200, 50, cName), Array("p", 200, 255, cPath), Array("i", 3, "", CLng(cId))) _
                )
                eCmd.Execute
                Set eCmd = Nothing
                crudMsg  = "Canción actualizada correctamente."
                crudType = "success"
            End If

        ElseIf ca = "delete" Then
            If Not IsNumeric(cId) Then
                crudMsg  = "ID de canción inválido."
                crudType = "error"
            Else
                ' Borramos primero las filas hijas para no violar las FKs.
                Dim dCmd1, dCmd2, dCmd3
                Set dCmd1 = Comando("DELETE FROM TBL_PLAYER WHERE ID_SONG = ?", Array(Array("i", 3, "", CLng(cId))))
                dCmd1.Execute : Set dCmd1 = Nothing
                Set dCmd2 = Comando("DELETE FROM TBL_TRACKLIST WHERE ID_SONG = ?", Array(Array("i", 3, "", CLng(cId))))
                dCmd2.Execute : Set dCmd2 = Nothing
                Set dCmd3 = Comando("DELETE FROM TBL_SONG WHERE ID_SONG = ?", Array(Array("i", 3, "", CLng(cId))))
                dCmd3.Execute : Set dCmd3 = Nothing
                crudMsg  = "Canción eliminada correctamente."
                crudType = "success"
            End If
        End If
    End If
End If

' ---------------------------------------------------------------------
'  5) LISTADO DE CANCIONES (una fila por canción, con álbum y artista)
' ---------------------------------------------------------------------
Dim listSql, listRs
listSql = _
    "SELECT s.ID_SONG, s.SONG_NAME, s.SONG_PATH, s.PLAYS, " & _
    "  (SELECT TOP 1 a.TITLE_ALBUM FROM TBL_TRACKLIST t JOIN TBL_ALBUM a ON a.ID_ALBUM = t.ID_ALBUM WHERE t.ID_SONG = s.ID_SONG) AS TITLE_ALBUM, " & _
    "  (SELECT TOP 1 a.ALBUM_IMAGE_PATH FROM TBL_TRACKLIST t JOIN TBL_ALBUM a ON a.ID_ALBUM = t.ID_ALBUM WHERE t.ID_SONG = s.ID_SONG) AS ALBUM_IMAGE_PATH, " & _
    "  (SELECT TOP 1 ar.ARTIST_NAME + ' ' + ISNULL(ar.ARTIST_LASTNAME,'') FROM TBL_PLAYER p JOIN TBL_ARTIST ar ON ar.ID_ARTIST = p.ID_ARTIST WHERE p.ID_SONG = s.ID_SONG) AS ARTIST_NAME, " & _
    "  (SELECT TOP 1 ar.ARTIST_IMAGE FROM TBL_PLAYER p JOIN TBL_ARTIST ar ON ar.ID_ARTIST = p.ID_ARTIST WHERE p.ID_SONG = s.ID_SONG) AS ARTIST_IMAGE " & _
    "FROM TBL_SONG s ORDER BY s.ID_SONG"

Set listRs = Server.CreateObject("ADODB.Recordset")
listRs.Open listSql, objConn, 3, 1   ' adOpenStatic, adLockReadOnly (permite RecordCount)

' Álbumes para la barra lateral (estilo Spotify)
Dim albRs
Set albRs = objConn.Execute("SELECT TITLE_ALBUM FROM TBL_ALBUM ORDER BY ID_ALBUM")

' ---------------------------------------------------------------------
'  HELPER: convierte la ruta "~/" de la BD en la ruta web real.
'  El prefijo "~/" apunta a la carpeta "SongFilesAndImages_resources".
' ---------------------------------------------------------------------
Function ResolvePath(dbPath)
    If IsNull(dbPath) Or dbPath = "" Then
        ResolvePath = ""
    Else
        ResolvePath = "SongFilesAndImages_resources/" & Replace(CStr(dbPath), "~/", "")
    End If
End Function

' Ruta de la foto de perfil del usuario (con fallback).
Dim sProfileImg
If sUserPhoto <> "" Then
    sProfileImg = ResolvePath(sUserPhoto)
Else
    sProfileImg = "SongFilesAndImages_resources/UserImages/default.jpg"
End If
%>
<!DOCTYPE html>
<html lang="es">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>PoliMusic · Tus canciones</title>
    <link rel="stylesheet" href="styles.css?v=20261021">
    <script>
    /* Fallback temprano de imágenes: se define ANTES de que el navegador
       cargue las <img>, así evitamos la carrera con app.js y nunca queda
       el icono de "imagen rota". */
    window.imgError = function (el, type) {
        if (!el || el.dataset.fallback) return;
        el.dataset.fallback = "1";
        var c = (type === "artist") ? "#2a2230" : "#241b1b";
        var svg = '<svg xmlns="http://www.w3.org/2000/svg" width="64" height="64" viewBox="0 0 64 64">' +
                  '<rect width="64" height="64" rx="12" fill="' + c + '"/>' +
                  '<path d="M24 16l22 16-22 16z" fill="#ff7e6b" opacity="0.8"/></svg>';
        el.src = "data:image/svg+xml;utf8," + encodeURIComponent(svg);
    };
    </script>
</head>
<body class="app-body">

    <!-- ===================== BARRA LATERAL (estilo Spotify) ===================== -->
    <aside class="sidebar">
        <a class="brand" href="songs.asp">
            <span class="brand-dot"></span>
            <span class="brand-name">Poli<span>Music</span></span>
        </a>

        <nav class="side-nav">
            <a class="side-item active" href="songs.asp"><span class="side-ic">⌂</span> Inicio</a>
            <a class="side-item" href="#"><span class="side-ic">⌕</span> Buscar</a>
            <a class="side-item" href="#"><span class="side-ic">▤</span> Tu biblioteca</a>
        </nav>

        <div class="side-sep"></div>

        <div class="side-label">Playlists</div>
        <a class="side-item" href="#"><span class="side-plus">+</span> Crear playlist</a>
        <a class="side-item" href="#"><span class="side-heart">♥</span> Canciones que te gustan</a>

        <div class="side-sep"></div>

        <div class="side-label">Álbumes</div>
        <% If Not albRs.EOF Then
             Do While Not albRs.EOF %>
            <span class="side-item side-album"><%= Server.HTMLEncode(albRs("TITLE_ALBUM") & "") %></span>
        <%
                 albRs.MoveNext
             Loop
           End If %>
    </aside>

    <!-- ===================== COLUMNA PRINCIPAL ===================== -->
    <div class="main-col">

        <header class="topbar">
            <div class="topbar-left">
                <div class="nav-arrows">
                    <button class="nav-btn" type="button" aria-label="Atrás">‹</button>
                    <button class="nav-btn" type="button" aria-label="Adelante">›</button>
                </div>
                <nav class="tabs">
                    <a class="tab active" href="#">Canciones</a>
                    <a class="tab" href="#">Artistas</a>
                    <a class="tab" href="#">Álbumes</a>
                </nav>
            </div>

            <div class="user-area">
                <div class="welcome">
                    <img class="avatar" src="<%= sProfileImg %>" alt="Foto de perfil"
                         onerror="this.src='SongFilesAndImages_resources/UserImages/default.jpg'">
                    <div class="welcome-text">
                        <strong><%= Server.HTMLEncode(sUsername) %></strong>
                        <% If bIsAdmin Then %><span class="role-badge">ADMIN</span><% End If %>
                    </div>
                </div>
                <a class="btn-logout" href="logout.asp" title="Cerrar sesión">Salir</a>
            </div>
        </header>

        <main class="content">
            <div class="page-head">
                <div>
                    <h1 class="page-title">Tus canciones</h1>
                    <p class="page-sub"><%= listRs.RecordCount %> canciones en tu catálogo</p>
                </div>
                <div class="page-actions">
                    <% If bIsAdmin Then %>
                        <button class="btn-salmon" id="btnAddSong" data-action="create">+ Nueva canción</button>
                    <% End If %>
                </div>
            </div>

            <% If crudMsg <> "" Then %>
                <div class="alert alert-<%= crudType %>"><%= Server.HTMLEncode(crudMsg) %></div>
            <% End If %>

            <section class="song-grid">
            <% If listRs.EOF Then %>
                <div class="empty">No hay canciones registradas.</div>
            <% Else
               Do While Not listRs.EOF
                   Dim sId, sName, sPath, sPlays, sAlbum, sAlbumImg, sArtist, sArtistImg
                   sId        = listRs("ID_SONG")
                   sName      = listRs("SONG_NAME") & ""
                   sPath      = ResolvePath(listRs("SONG_PATH"))
                   sPlays     = listRs("PLAYS") & ""
                   sAlbum     = listRs("TITLE_ALBUM") & ""
                   sAlbumImg  = ResolvePath(listRs("ALBUM_IMAGE_PATH"))
                   sArtist    = listRs("ARTIST_NAME") & ""
                   sArtistImg = ResolvePath(listRs("ARTIST_IMAGE"))
                   If sArtist = "" Then sArtist = "Artista desconocido"
                   If sAlbum  = "" Then sAlbum  = "Álbum desconocido"
            %>
                <article class="song-card"
                         data-id="<%= sId %>"
                         data-src="<%= sPath %>"
                         data-title="<%= Server.HTMLEncode(sName) %>"
                         data-artist="<%= Server.HTMLEncode(sArtist) %>"
                         data-album="<%= Server.HTMLEncode(sAlbum) %>"
                         data-cover="<%= sAlbumImg %>">

                    <div class="card-art">
                        <img class="card-cover" src="<%= sAlbumImg %>"
                             alt="<%= Server.HTMLEncode(sAlbum) %>"
                             onerror="window.imgError(this)">

                        <button class="card-play" data-play="<%= sId %>"
                                title="Reproducir" aria-label="Reproducir">▶</button>

                        <% If bIsAdmin Then %>
                        <div class="card-tools">
                            <button class="tool-btn" title="Editar"
                                    data-edit="<%= sId %>"
                                    data-name="<%= Server.HTMLEncode(sName) %>"
                                    data-path="<%= Server.HTMLEncode(listRs("SONG_PATH") & "") %>">✎</button>
                            <button class="tool-btn tool-danger" title="Eliminar"
                                    data-del="<%= sId %>"
                                    data-name="<%= Server.HTMLEncode(sName) %>">🗑</button>
                        </div>
                        <% End If %>

                        <div class="eq" aria-hidden="true"><span></span><span></span><span></span><span></span></div>
                    </div>

                    <h3 class="card-title"><%= Server.HTMLEncode(sName) %></h3>
                    <p class="card-sub"><%= Server.HTMLEncode(sArtist) %></p>
                    <div class="card-plays"><span class="plays"><%= sPlays %></span> reproducciones</div>
                </article>
            <%
                       listRs.MoveNext
                   Loop
                   End If
            %>
            </section>
        </main>
    </div>

    <!-- ===================== REPRODUCTOR (barra inferior) ===================== -->
    <footer class="player-bar" id="playerBar">
        <div class="player-left">
            <img class="np-cover" id="npCover" src="" alt=""
                 onerror="this.style.visibility='hidden'">
            <div class="np-meta">
                <span class="np-title" id="npTitle">Selecciona una canción</span>
                <span class="np-artist" id="npArtist"></span>
            </div>
        </div>

        <div class="player-center">
            <button class="pc-btn" id="btnPlayPause" title="Reproducir / Pausar">▶</button>
            <div class="pc-seek">
                <span class="pc-time" id="pcCurrent">0:00</span>
                <input type="range" id="seekBar" class="seek" min="0" max="100" value="0" step="0.1">
                <span class="pc-time" id="pcDuration">0:00</span>
            </div>
        </div>

        <div class="player-right">
            <input type="range" id="volBar" class="vol" min="0" max="1" value="0.8" step="0.05" title="Volumen">
        </div>

        <!-- Audio real (oculto) -->
        <audio id="audioEl" preload="none"></audio>
    </footer>

    <!-- ===================== MODAL CRUD ===================== -->
    <% If bIsAdmin Then %>
    <div class="modal-overlay" id="modalOverlay" hidden>
        <div class="modal">
            <div class="modal-head">
                <h2 id="modalTitle">Nueva canción</h2>
                <button class="modal-close" id="modalClose" title="Cerrar">×</button>
            </div>
            <form method="post" action="songs.asp" class="crud-form" id="crudForm" novalidate>
                <input type="hidden" name="crud_action" id="crudAction" value="create">
                <input type="hidden" name="id_song" id="crudId" value="">

                <label>
                    <span>Nombre de la canción *</span>
                    <input type="text" name="song_name" id="crudName" maxlength="50" required
                           placeholder="Ej. Adventure">
                </label>

                <label>
                    <span>Ruta del archivo (mp3) *</span>
                    <input type="text" name="song_path" id="crudPath" maxlength="255" required
                           placeholder="~/songFiles/bensound-xxx.mp3">
                    <small>Debe comenzar con <code>~/</code> y apuntar a la carpeta de recursos.</small>
                </label>

                <div class="modal-actions">
                    <button type="button" class="btn-ghost" id="btnCancel">Cancelar</button>
                    <button type="submit" class="btn-salmon" id="btnSave">Guardar</button>
                </div>
            </form>
        </div>
    </div>

    <!-- Modal de confirmación de eliminación -->
    <div class="modal-overlay" id="delOverlay" hidden>
        <div class="modal modal-sm">
            <div class="modal-head">
                <h2>Confirmar eliminación</h2>
                <button class="modal-close" id="delClose" title="Cerrar">×</button>
            </div>
            <p class="del-text">¿Está seguro de eliminar la canción <strong id="delName"></strong>? Esta acción no se puede deshacer.</p>
            <form method="post" action="songs.asp" id="delForm">
                <input type="hidden" name="crud_action" value="delete">
                <input type="hidden" name="id_song" id="delId" value="">
                <div class="modal-actions">
                    <button type="button" class="btn-ghost" id="delCancel">Cancelar</button>
                    <button type="submit" class="btn-danger">Eliminar</button>
                </div>
            </form>
        </div>
    </div>
    <% End If %>

    <script src="app.js"></script>
</body>
</html>
<%
' ---------------------------------------------------------------------
'  Cierre de recursos
' ---------------------------------------------------------------------
If IsObject(listRs) Then
    If listRs.State = 1 Then listRs.Close
    Set listRs = Nothing
End If
If IsObject(albRs) Then
    If albRs.State = 1 Then albRs.Close
    Set albRs = Nothing
End If
CerrarConexion
%>
