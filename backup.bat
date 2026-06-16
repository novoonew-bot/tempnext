@echo off
REM ============================================================
REM  Tempnext - Backup de seguranca (C: e D:)
REM  Roda: copia index.html, manifest, service-worker e icones
REM  para uma pasta datada em C:\tempnext_backups e D:\tempnext_backups
REM  Uso:  cd C:\tempnext  &&  backup.bat
REM ============================================================

setlocal

REM --- carimbo de data/hora AAAAMMDD_HHMMSS (independe de locale) ---
for /f %%i in ('powershell -NoProfile -Command "Get-Date -Format yyyyMMdd_HHmmss"') do set STAMP=%%i

set SRC=C:\tempnext
set DESTC=C:\tempnext_backups\%STAMP%_v424
set DESTD=D:\tempnext_backups\%STAMP%_v424

echo.
echo === Tempnext backup %STAMP% (v424 / SW v421) ===
echo.

REM --- destino C: ---
mkdir "%DESTC%" 2>nul
copy /Y "%SRC%\index.html" "%DESTC%\" >nul
copy /Y "%SRC%\manifest.json" "%DESTC%\" >nul
copy /Y "%SRC%\service-worker.js" "%DESTC%\" >nul
copy /Y "%SRC%\tempnext_icon_192.png" "%DESTC%\" >nul
copy /Y "%SRC%\tempnext_icon_512.png" "%DESTC%\" >nul
copy /Y "%SRC%\tempnext_icon_maskable_512.png" "%DESTC%\" >nul
copy /Y "%SRC%\tempnext_apple_touch_icon.png" "%DESTC%\" >nul
copy /Y "%SRC%\tempnext_favicon.png" "%DESTC%\" >nul
echo [OK] Backup em: %DESTC%

REM --- destino D: (so se o disco D existir) ---
if exist D:\ (
  mkdir "%DESTD%" 2>nul
  copy /Y "%SRC%\index.html" "%DESTD%\" >nul
  copy /Y "%SRC%\manifest.json" "%DESTD%\" >nul
  copy /Y "%SRC%\service-worker.js" "%DESTD%\" >nul
  copy /Y "%SRC%\tempnext_icon_192.png" "%DESTD%\" >nul
  copy /Y "%SRC%\tempnext_icon_512.png" "%DESTD%\" >nul
  copy /Y "%SRC%\tempnext_icon_maskable_512.png" "%DESTD%\" >nul
  copy /Y "%SRC%\tempnext_apple_touch_icon.png" "%DESTD%\" >nul
  copy /Y "%SRC%\tempnext_favicon.png" "%DESTD%\" >nul
  echo [OK] Backup em: %DESTD%
) else (
  echo [AVISO] Disco D: nao encontrado - backup D pulado.
)

echo.
echo === Concluido ===
endlocal
pause
