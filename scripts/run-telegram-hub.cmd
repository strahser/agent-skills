@echo off
REM ============================================================
REM  Always-on opencode hub for Telegram remote.
REM  Plugin runs in-process, so any opencode process works.
REM  Manual: run this file. Auto at logon: shortcut
REM  %APPDATA%\Microsoft\Windows\Start Menu\Programs\Startup\OpenCodeTelegramHub.lnk
REM  (schtasks /sc onlogon is blocked by policy on this PC)
REM ============================================================
cd /d "%~dp0.."
opencode serve --port 4096 --print-logs >> "%~dp0..\.opencode\hub-out.log" 2>&1
