@echo off
REM =====================================================================
REM  deploy.bat  -  Despliegue de PoliMusic en IIS
REM  IMPORTANTE: Ejecutar como ADMINISTRADOR (clic derecho -> "Ejecutar
REM  como administrador").  Esto:
REM    1) Habilita ASP Clasico (feature IIS-ASP) si no esta activo.
REM    2) Copia los archivos a C:\inetpub\wwwroot
REM    3) Da permisos de LECTURA a IIS_IUSRS e IUSR (para .asp, .mp3, img).
REM  Requisitos previos: SQL Server con BDD_PoliMusic ya creada
REM  (login sa / admin04) y el driver MSOLEDBSQL instalado.
REM =====================================================================

set "SRC=%~dp0"
set "DST=C:\inetpub\wwwroot"

echo ===================================================
echo  [1/4] Habilitando ASP Clasico (IIS-ASP)...
echo ===================================================
dism /online /enable-feature /featurename:IIS-ASP /all /norestart >nul 2>&1
if "%errorlevel%"=="0" (echo   ASP Clasico habilitado OK.) else (echo   (ya estaba o requiere reinicio de Windows).)

echo ===================================================
echo  [2/4] Copiando archivos a %DST%
echo ===================================================
if not exist "%DST%" mkdir "%DST%"
copy /Y "%SRC%db_connection.asp" "%DST%"
copy /Y "%SRC%login.asp"        "%DST%"
copy /Y "%SRC%logout.asp"       "%DST%"
copy /Y "%SRC%songs.asp"        "%DST%"
copy /Y "%SRC%styles.css"       "%DST%"
copy /Y "%SRC%app.js"           "%DST%"
xcopy /E /I /Y "%SRC%SongFilesAndImages_resources" "%DST%\SongFilesAndImages_resources"

echo ===================================================
echo  [3/4] Permisos de lectura para IIS (IIS_IUSRS / IUSR)...
echo ===================================================
icacls "%DST%" /grant "IIS_IUSRS:(OI)(CI)(RX)" /T >nul 2>&1
icacls "%DST%" /grant "IUSR:(OI)(CI)(RX)" /T >nul 2>&1
echo   Permisos aplicados.

echo ===================================================
echo  [4/4] DESPLIEGUE COMPLETO
echo ===================================================
echo  Abre el navegador en:
echo      http://localhost/login.asp
echo  Cuentas de prueba:
echo      Normal : userNormal  / 12345678
echo      Admin  : userAdmin   / 12345678
echo.
echo  Si ves codigo ASP en texto plano -> ASP clasico no esta habilitado.
echo  Si ves error de conexion BD -> revisa SQL Server / login sa/admin04.
echo.
pause
