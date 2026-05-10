@echo off
REM Tempnext - script de deploy
REM Uso: deploy.bat v333r "descricao do commit"

setlocal

if "%~1"=="" goto :uso
if "%~2"=="" goto :uso

set VERSAO=%~1
set DESCRICAO=%~2
set ARQUIVO=tempnext_%VERSAO%.html
set ORIGEM=C:\Users\%USERNAME%\Downloads\%ARQUIVO%

echo.
echo === Tempnext deploy === %VERSAO% ===
echo.

if not exist "%ORIGEM%" (
  echo [ERRO] Arquivo nao encontrado: %ORIGEM%
  echo Coloque o %ARQUIVO% em Downloads e tente de novo.
  goto :erro
)

echo [1/7] Backup em C:\backup_tempnext\
copy /Y "%ORIGEM%" "C:\backup_tempnext\%ARQUIVO%" || goto :erro

echo [2/7] Backup em D:\
copy /Y "%ORIGEM%" "D:\%ARQUIVO%" || goto :erro

echo [3/7] Copiando pra C:\tempnext\index.html
cd /d C:\tempnext || goto :erro
copy /Y "%ORIGEM%" index.html || goto :erro

echo [4/7] Compilando...
call node compilar.js || goto :erro_compilar

if not exist index_compiled.html (
  echo [ERRO] compilar.js rodou mas nao gerou index_compiled.html
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

echo.
echo === Deploy concluido: %VERSAO% ===
echo Vercel vai detectar o push e atualizar em ~30s.
echo.
endlocal
exit /b 0

:uso
echo.
echo Uso: deploy.bat ^<versao^> "^<descricao^>"
echo Exemplo: deploy.bat v333s "pin gota azul"
echo.
echo O arquivo tempnext_^<versao^>.html precisa estar em Downloads.
endlocal
exit /b 1

:erro_compilar
echo.
echo [ERRO] compilar.js falhou. Index original ainda esta intacto.
echo Conserte o erro de compilacao e rode de novo.
endlocal
exit /b 1

:erro_commit
echo.
echo [AVISO] Git commit falhou. Possiveis causas:
echo   - Nada pra commitar (arquivo identico ao anterior)
echo   - Conflito de merge
echo Verifique com: git status
endlocal
exit /b 1

:erro
echo.
echo [ERRO] Deploy interrompido. Verifique a mensagem acima.
endlocal
exit /b 1