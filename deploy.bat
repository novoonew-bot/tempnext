@echo off
REM Tempnext - script de deploy
REM
REM MODO 1 (Claude preparou o index.html direto em C:\tempnext):
REM   deploy.bat v333u "descricao do commit"
REM
REM MODO 2 (voce baixou tempnext_vXXX.html em Downloads — fluxo antigo):
REM   deploy.bat v333u "descricao" downloads

setlocal

if "%~1"=="" goto :uso
if "%~2"=="" goto :uso

set VERSAO=%~1
set DESCRICAO=%~2
set MODO=%~3

cd /d C:\tempnext || goto :erro

echo.
echo === Tempnext deploy === %VERSAO% ===
echo.

if /I "%MODO%"=="downloads" (
  set ARQUIVO=tempnext_%VERSAO%.html
  set ORIGEM=C:\Users\%USERNAME%\Downloads\%ARQUIVO%
  if not exist "%ORIGEM%" (
    echo [ERRO] Arquivo nao encontrado: %ORIGEM%
    goto :erro
  )
  echo [1/7] Backup do orig em C:\backup_tempnext\
  copy /Y "%ORIGEM%" "C:\backup_tempnext\%ARQUIVO%" || goto :erro
  echo [2/7] Backup do orig em D:\
  copy /Y "%ORIGEM%" "D:\%ARQUIVO%" 2>nul
  echo [3/7] Copiando pra C:\tempnext\index.html
  copy /Y "%ORIGEM%" index.html || goto :erro
) else (
  REM MODO 1: index.html ja esta em C:\tempnext, preparado pelo Claude.
  REM Faz backup do proprio index.html como vXXX antes de compilar.
  echo [1/7] Backup do orig em C:\backup_tempnext\
  if not exist C:\backup_tempnext mkdir C:\backup_tempnext
  copy /Y index.html "C:\backup_tempnext\tempnext_%VERSAO%.html" || goto :erro
  echo [2/7] Backup do orig em D:\
  copy /Y index.html "D:\tempnext_%VERSAO%.html" 2>nul
  echo [3/7] index.html ja esta posicionado (modo Claude)
)

echo [4/7] Compilando...
call node compilar.cjs || goto :erro_compilar

if not exist index_compiled.html (
  echo [ERRO] compilar.cjs rodou mas nao gerou index_compiled.html
  goto :erro
)

echo [5/7] Substituindo original pelo compilado
del index.html || goto :erro
ren index_compiled.html index.html || goto :erro

echo [6/7] Git add + commit
git add -A || goto :erro
git commit -m "%VERSAO% %DESCRICAO%" || goto :erro_commit

echo [7/7] Git push --force
git push --force || goto :erro

echo [8/8] Restaurando fonte babel em C:\tempnext\index.html
copy /Y "C:\backup_tempnext\tempnext_%VERSAO%.html" index.html || goto :erro

echo.
echo === Deploy concluido: %VERSAO% ===
echo Vercel vai detectar o push e atualizar em ~30s.
echo Fonte babel ja restaurado em C:\tempnext\index.html (pronto pra proxima edicao).
echo.
endlocal
exit /b 0

:uso
echo.
echo Uso MODO 1 (Claude preparou index.html): deploy.bat ^<versao^> "^<descricao^>"
echo Uso MODO 2 (arquivo em Downloads):        deploy.bat ^<versao^> "^<descricao^>" downloads
echo.
endlocal
exit /b 1

:erro_compilar
echo.
echo [ERRO] compilar.cjs falhou. Index original ainda esta intacto.
echo Se for "Cannot find module @babel/core", rode primeiro: npm install
endlocal
exit /b 1

:erro_commit
echo.
echo [AVISO] Git commit falhou (nada pra commitar ou conflito). Verifique: git status
endlocal
exit /b 1

:erro
echo.
echo [ERRO] Deploy interrompido. Verifique a mensagem acima.
endlocal
exit /b 1
