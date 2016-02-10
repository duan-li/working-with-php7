@ECHO OFF
taskkill /f /im php-cgi.exe
taskkill /f /im nginx.exe
ECHO Starting PHP FastCGI...
set PATH=.\PHP;%PATH%
.\RunHiddenConsole.exe .\PHP\php-cgi.exe -b 127.0.0.1:9123
cd nginx
ECHO Starting Nginx Server...
nginx.exe
pause