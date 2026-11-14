@echo off
REM Windows wrapper: runs the toolkit inside WSL so ssh/sshpass/tar/gzip are available.
setlocal
set "HERE=%~dp0"
wsl bash -lc "'%HERE:\=/%bin/keenetic-dev' %*"
