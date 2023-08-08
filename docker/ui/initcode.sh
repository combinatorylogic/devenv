#!/bin/bash


mkdir -p /var/run/dbus
mkdir -p /workdir/vscode
dbus-daemon --config-file=/usr/share/dbus-1/system.conf
nohup code --disable-gpu --in-process-gpu --no-sandbox --user-data-dir /workdir/vscode &> /dev/null &


