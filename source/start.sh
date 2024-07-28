#!/bin/bash

SCRIPT=$(realpath "$0")
SCRIPT_DIR=$(realpath $(dirname "$0"))

cd "$SCRIPT_DIR"

echo "[Desktop Entry]
Exec=$SCRIPT %u
Name=Lineworks
Icon=$SCRIPT_DIR/launcher/icon.png
MimeType=application/x-lineworks;x-scheme-handler/lineworks;
Type=Application
StartupNotify=false
Terminal=false" > Lineworks-handler.desktop
xdg-desktop-menu install Lineworks-handler.desktop
xdg-mime default Lineworks-handler.desktop x-scheme-handler/lineworks
rm Lineworks-handler.desktop
chmod +x $SCRIPT

cd ..

if [ ! -d "./python" ] 
then
    flags=$(grep flags /proc/cpuinfo)
    arch="x86_64"
    if [[ $flags == *"sse4"* ]]; then
        arch="x86_64_v2"
    fi
    if [[ $flags == *"avx2"* ]]; then
        arch="x86_64_v3"
    fi
    if [[ $flags == *"avx512"* ]]; then
        arch="x86_64_v4"
    fi
    echo "DOWNLOADING PYTHON ($arch)..."
    curl -L --progress-bar "https://github.com/indygreg/python-build-standalone/releases/download/20230726/cpython-3.10.12+20230726-$arch-unknown-linux-gnu-install_only.tar.gz" -o "python.tar.gz"
    
    echo "EXTRACTING PYTHON..."
    tar -xf "python.tar.gz"
    rm "python.tar.gz"
fi
./python/bin/python3 source/launch.py "$@"