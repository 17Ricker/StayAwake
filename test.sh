#!/bin/bash
# Compila ed esegue i test di StayAwake (senza root, senza toccare pmset). Uso: ./test.sh
set -euo pipefail
# Le macro di SwiftUI richiedono Xcode completo, non solo i Command Line Tools.
if [ -z "${DEVELOPER_DIR:-}" ] && [ -d /Applications/Xcode.app ]; then
  export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
fi
cd "$(dirname "$0")"

mkdir -p build
swiftc -D PREVIEW -swift-version 5 Sources/*.swift Tests/*.swift -o build/tests
./build/tests
