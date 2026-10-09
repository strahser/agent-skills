@echo off
REM ============================================================
REM  Telegram remote for opencode (timjonez plugin)
REM  Run once on each PC. Secrets NEVER leave this machine:
REM  token/chat id are typed here and stored via setx only.
REM ============================================================
setlocal
set /p TG_TOKEN="Bot token from @BotFather: "
set /p TG_CHAT="Numeric chat id from @userinfobot: "
if "%TG_TOKEN%"=="" echo Empty token, abort. & exit /b 1
if "%TG_CHAT%"=="" echo Empty chat id, abort. & exit /b 1
setx TELEGRAM_BOT_TOKEN "%TG_TOKEN%" >nul
setx TELEGRAM_CHAT_ID "%TG_CHAT%" >nul
echo [1/2] Env vars saved (take effect in NEW terminals).
call "C:\Program Files\nodejs\npm.cmd" --prefix "%~dp0..\.opencode" install --no-audit --no-fund node-telegram-bot-api@^0.66.0
echo [2/2] Plugin dependency installed.
echo.
echo Next: open a NEW terminal, cd to project root, run:  opencode
echo The bot will message you "OpenCode Remote connected!".
echo For 24/7 hub without open TUI use scripts\run-telegram-hub.cmd
endlocal
