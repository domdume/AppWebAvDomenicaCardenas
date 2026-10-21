<%@ Language="VBScript" %>
<% Option Explicit %>
<!--#include file="db_connection.asp" -->
<%
' =====================================================================
'  login.asp  —  Autenticación de PoliMusic
' ---------------------------------------------------------------------
'  Valida usuario/contraseña contra TBL_USER y, en caso de éxito,
'  guarda en Session: username, user_type, user_photo, user_id.
'  Luego redirige a songs.asp (la pantalla principal).
' =====================================================================

Dim action, username, password, msg, rs, sql, cmd

action   = Trim(Request.Form("action"))
username = Trim(Request.Form("username"))
password = Request.Form("password")
msg      = ""

If action = "login" Then
    If username = "" Or password = "" Then
        msg = "Por favor, ingrese usuario y contraseña."
    Else
        ' Consulta parametrizada (sin concatenación -> sin inyección SQL).
        sql = "SELECT ID_USER, USERNAME, USER_PHOTO, USER_TYPE " & _
              "FROM TBL_USER WHERE USERNAME = ? AND PASSWORD = ?"
        Set cmd = Comando(sql, Array( _
            Array("u", 200, 50, username), _
            Array("p", 200, 50, password) _
        ))
        Set rs = cmd.Execute

        If Not rs.EOF Then
            ' --- Creamos la sesión ---
            Session("user_id")    = rs("ID_USER")
            Session("username")   = rs("USERNAME")
            Session("user_photo") = rs("USER_PHOTO") & ""
            Session("user_type")  = rs("USER_TYPE")
            rs.Close
            Set rs = Nothing
            Set cmd = Nothing
            CerrarConexion
            Response.Redirect "songs.asp"
            Response.End
        Else
            rs.Close
            Set rs = Nothing
            msg = "Credenciales incorrectas. Inténtelo de nuevo."
        End If
        Set cmd = Nothing
    End If
End If

' Datos de demostración (no se muestran en producción).
Dim demoNormal, demoAdmin
demoNormal = "userNormal / 12345678  (rol Normal)"
demoAdmin  = "userAdmin  / 12345678  (rol Administrador)"
%>
<!DOCTYPE html>
<html lang="es">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>PoliMusic · Iniciar sesión</title>
    <link rel="stylesheet" href="styles.css?v=20261021">
</head>
<body class="auth-body">
    <main class="auth-card">
        <div class="brand">
            <span class="brand-dot"></span>
            <h1>Poli<span>Music</span></h1>
        </div>
        <p class="auth-sub">Tu streaming musical de la Escuela Politécnica Nacional</p>

        <% If msg <> "" Then %>
            <div class="auth-error"><%= Server.HTMLEncode(msg) %></div>
        <% End If %>

        <form method="post" action="login.asp" class="auth-form" novalidate>
            <input type="hidden" name="action" value="login">
            <label>
                <span>Usuario</span>
                <input type="text" name="username" autocomplete="username" placeholder="Su nombre de usuario" required>
            </label>
            <label>
                <span>Contraseña</span>
                <input type="password" name="password" autocomplete="current-password" placeholder="••••••••" required>
            </label>
            <button type="submit" class="btn-salmon btn-block">Entrar</button>
        </form>

        <div class="auth-hint">
            <p><strong>Cuentas de prueba:</strong></p>
            <ul>
                <li><%= Server.HTMLEncode(demoNormal) %></li>
                <li><%= Server.HTMLEncode(demoAdmin) %></li>
            </ul>
        </div>
    </main>
</body>
</html>
<%
CerrarConexion
%>
