#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT_DIR"

echo "Compilando HP12C em modo release..."
swift build -c release

APP_DIR="$ROOT_DIR/build/HP12C.app"
rm -rf "$APP_DIR"
mkdir -p "$APP_DIR/Contents/MacOS" "$APP_DIR/Contents/Resources"

cp "$ROOT_DIR/.build/release/HP12C" "$APP_DIR/Contents/MacOS/HP12C"
chmod +x "$APP_DIR/Contents/MacOS/HP12C"

cat > "$APP_DIR/Contents/Info.plist" <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>pt_BR</string>
    <key>CFBundleExecutable</key>
    <string>HP12C</string>
    <key>CFBundleIdentifier</key>
    <string>com.luirdi.hp12c</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>HP 12C</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>NSHighResolutionCapable</key>
    <true/>
</dict>
</plist>
EOF

codesign --force -s - "$APP_DIR"
echo "App gerado com sucesso em: $APP_DIR"

ROOT_APP_DIR="$ROOT_DIR/HP12C.app"
rm -rf "$ROOT_APP_DIR"
cp -R "$APP_DIR" "$ROOT_APP_DIR"
codesign --force -s - "$ROOT_APP_DIR"
echo "Cópia criada na raiz do projeto: $ROOT_APP_DIR"
