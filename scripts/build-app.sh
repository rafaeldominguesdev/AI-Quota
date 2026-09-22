#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

APP_NAME="AI Quota"
BUNDLE_ID="dev.rafaeldomingues.aiquota"
EXECUTABLE_NAME="AIQuota"
VERSION="0.1.0"
MIN_MACOS="14.0"

echo "==> Compilando em modo release..."
swift build -c release

BINARY_PATH=".build/release/${EXECUTABLE_NAME}"
if [ ! -f "$BINARY_PATH" ]; then
    echo "erro: binário não encontrado em ${BINARY_PATH}" >&2
    exit 1
fi

APP_BUNDLE="dist/${APP_NAME}.app"
CONTENTS_DIR="${APP_BUNDLE}/Contents"
MACOS_DIR="${CONTENTS_DIR}/MacOS"
RESOURCES_DIR="${CONTENTS_DIR}/Resources"

echo "==> Recriando o bundle em \"${APP_BUNDLE}\"..."
rm -rf "$APP_BUNDLE"
mkdir -p "$MACOS_DIR" "$RESOURCES_DIR"

cp "$BINARY_PATH" "${MACOS_DIR}/${EXECUTABLE_NAME}"
chmod +x "${MACOS_DIR}/${EXECUTABLE_NAME}"

# Os recursos declarados no Package.swift (as logos das IAs) NÃO ficam dentro do binário: o
# SwiftPM os empacota em bundles separados ao lado dele. Sem copiá-los para Contents/Resources,
# o app funciona por `swift run` (que acha o bundle em .build) e chega ao usuário sem as logos.
echo "==> Copiando bundles de recursos..."
found_bundle=0
for bundle in .build/release/*.bundle; do
    [ -e "$bundle" ] || continue
    cp -R "$bundle" "${RESOURCES_DIR}/"
    echo "    $(basename "$bundle")"
    found_bundle=1
done
if [ "$found_bundle" -eq 0 ]; then
    echo "erro: nenhum .bundle encontrado em .build/release — o app ficaria sem as logos" >&2
    exit 1
fi

echo "==> Copiando ícone do app..."
cp "AppIcon/AppIcon.icns" "${RESOURCES_DIR}/AppIcon.icns"

echo "==> Escrevendo Info.plist..."
cat > "${CONTENTS_DIR}/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key>
    <string>${APP_NAME}</string>
    <key>CFBundleDisplayName</key>
    <string>${APP_NAME}</string>
    <key>CFBundleIdentifier</key>
    <string>${BUNDLE_ID}</string>
    <key>CFBundleExecutable</key>
    <string>${EXECUTABLE_NAME}</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>${VERSION}</string>
    <key>CFBundleVersion</key>
    <string>${VERSION}</string>
    <key>LSMinimumSystemVersion</key>
    <string>${MIN_MACOS}</string>
    <key>LSApplicationCategoryType</key>
    <string>public.app-category.developer-tools</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSHighResolutionCapable</key>
    <true/>
</dict>
</plist>
PLIST

echo "==> Assinando ad-hoc..."
codesign --force --deep --sign - "$APP_BUNDLE"

echo ""
echo "Pronto: ${APP_BUNDLE}"
echo "Para abrir:  open \"${APP_BUNDLE}\""
echo "Para instalar: arraste \"${APP_BUNDLE}\" para /Applications"
