<%
' =====================================================================
'  db_connection.asp
'  Include de conexión ADODB a SQL Server (BDD_PoliMusic)
'  ---------------------------------------------------------------------
'  Servidor        : localhost
'  Base de datos   : BDD_PoliMusic
'  Autenticación   : SQL Server  ->  usuario "sa" / contraseña "admin04"
'                    (también existe el login "usr_polimusic" / "Politecnica1")
'  Cifrado         : Opcional (Encrypt=Optional)
'  Certificado     : Servidor de confianza habilitado (TrustServerCertificate=Yes)
'
'  Este archivo se incluye con:  <!--#include file="db_connection.asp"-->
'  Expone la variable global "objConn" (ADODB.Connection ya abierta) y
'  la subrutina "CerrarConexion()" para liberar recursos al final.
' =====================================================================

Dim objConn
Set objConn = Server.CreateObject("ADODB.Connection")

' --- Cadena de conexión ------------------------------------------------
' Probamos varios providers en orden de preferencia para máxima
' compatibilidad. MSOLEDBSQL es el driver moderno de SQL Server 2025 y
' es el único que soporta "Encrypt=Optional" + "TrustServerCertificate".
Dim sProviders, sConn, i, bConnected
sProviders = Array("MSOLEDBSQL", "SQLNCLI11", "SQLOLEDB")

bConnected = False
For i = 0 To UBound(sProviders)
    sConn = "Provider=" & sProviders(i) & ";" & _
            "Server=localhost;" & _
            "Database=BDD_PoliMusic;" & _
            "UID=sa;PWD=admin04;" & _
            "Encrypt=Optional;" & _
            "TrustServerCertificate=Yes;" & _
            "Connection Timeout=30;"

    On Error Resume Next
    objConn.Open sConn
    If Err.Number = 0 Then
        bConnected = True
        Exit For
    End If
    Err.Clear
    On Error GoTo 0
Next

If Not bConnected Then
    On Error Resume Next
    ' Último intento con SQLOLEDB (sin cifrado) por si los drivers
    ' modernos no estén registrados en el servidor.
    sConn = "Provider=SQLOLEDB;Server=localhost;Database=BDD_PoliMusic;UID=sa;PWD=admin04;Connection Timeout=30;"
    objConn.Open sConn
    If Err.Number = 0 Then bConnected = True
    Err.Clear
    On Error GoTo 0
End If

If Not bConnected Then
    Response.Write "<div style='color:#ff6b6b;font-family:Segoe UI,sans-serif;padding:24px'>" & _
                   "<h2>No se pudo conectar a BDD_PoliMusic</h2>" & _
                   "<p>Verifique que SQL Server 2025 esté corriendo en localhost, " & _
                   "que el login <b>sa/admin04</b> exista y que el driver OLE DB esté instalado.</p></div>"
    Response.End
End If

' ---------------------------------------------------------------------
'  CerrarConexion: libera la conexión de forma segura.
' ---------------------------------------------------------------------
Sub CerrarConexion()
    If IsObject(objConn) Then
        If objConn.State = 1 Then objConn.Close
        Set objConn = Nothing
    End If
End Sub

' ---------------------------------------------------------------------
'  Ejecuta un comando parametrizado (evita inyección SQL).
'  Ejemplo:
'    Set cmd = Comando("INSERT INTO TBL_SONG (SONG_NAME) VALUES (?)", Array(200,1,50,nombre))
'  donde cada elemento del array es: adType, adParamInput, tamaño(opcional), valor
' ---------------------------------------------------------------------
Function Comando(sql, params)
    Dim cmd, p, a
    Set cmd = Server.CreateObject("ADODB.Command")
    cmd.ActiveConnection = objConn
    cmd.CommandText = sql
    cmd.CommandType = 1 ' adCmdText
    If IsArray(params) Then
        For Each a In params
            ' a = Array(adType, adParamInput, sizeOrEmpty, value)
            If UBound(a) >= 2 And a(2) <> "" And Not IsEmpty(a(2)) Then
                Set p = cmd.CreateParameter(a(0), a(1), 1, CInt(a(2)), a(3))
            Else
                Set p = cmd.CreateParameter(a(0), a(1), 1, , a(3))
            End If
            cmd.Parameters.Append p
        Next
    End If
    Set Comando = cmd
End Function
%>
