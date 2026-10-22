#!/bin/bash
# usage: run.sh "<extra ap args>"   -- launches both instances, waits until both exit or 900s
cd /c/Users/hanwd/OneDrive/Desktop/past-future
taskkill //F //IM Godot_v4.7.2-stable_win64.exe >/dev/null 2>&1
rm -f docs/internal/gameplay_recording/logs/*.log docs/internal/gameplay_recording/logs/*.out docs/internal/gameplay_recording/logs/*.err
powershell -File tools/recording/launch.ps1 -Script playthrough -Extra "$1" >/dev/null 2>&1
echo "both instances exited"
