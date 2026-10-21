<%
' =====================================================================
'  logout.asp  —  Cierre de sesión de PoliMusic
' ---------------------------------------------------------------------
'  Destruye la sesión activa (Session.Abandon) y redirige al login.
' =====================================================================

' 1) Limpiamos las variables de sesión de forma explícita.
Session("username")   = ""
Session("user_type")  = ""
Session("user_photo") = ""
Session("user_id")    = ""

' 2) Abandonamos la sesión (elimina el objeto Session en el servidor).
Session.Abandon

' 3) Redirigimos siempre a la pantalla de inicio de sesión.
Response.Redirect "login.asp"
%>
