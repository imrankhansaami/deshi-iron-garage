@echo off
rem ---------------------------------------------------------------------------
rem  DESHI IRON GARAGE - launch the game (title screen, then START)
rem
rem  Double-click this file. If Godot is somewhere other than the path below,
rem  edit the GODOT line to point at your Godot 4.7 executable.
rem ---------------------------------------------------------------------------
set "GODOT=C:\Users\imran\Downloads\godat\Godot_v4.7.2-stable_win64.exe"
if not exist "%GODOT%" (
  echo Could not find Godot at:
  echo   %GODOT%
  echo Edit this file and point the GODOT line at your Godot 4.7 executable.
  pause
  exit /b 1
)
start "" "%GODOT%" --path "%~dp0."
