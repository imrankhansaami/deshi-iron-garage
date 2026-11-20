@echo off
rem ---------------------------------------------------------------------------
rem  DESHI IRON GARAGE - launch straight into the garage, skipping the menu
rem
rem  Same as run_game.bat, but starts the garage scene directly. Handy for a
rem  demonstration: press F9 once inside to show the finished state.
rem ---------------------------------------------------------------------------
set "GODOT=C:\Users\imran\Downloads\godat\Godot_v4.7.2-stable_win64.exe"
if not exist "%GODOT%" (
  echo Could not find Godot at:
  echo   %GODOT%
  echo Edit this file and point the GODOT line at your Godot 4.7 executable.
  pause
  exit /b 1
)
start "" "%GODOT%" --path "%~dp0." res://scenes/main/garage_world.tscn
