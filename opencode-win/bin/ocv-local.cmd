@echo off
powershell -NoProfile -ExecutionPolicy Bypass -File "%USERPROFILE%\.config\opencode\start-lmstudio.ps1"
set "OPENCODE_CONFIG=%USERPROFILE%\.config\opencode\opencode-local-min.json"
opencode %*