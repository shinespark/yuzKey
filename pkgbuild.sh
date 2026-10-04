set -ex

PROJECT_NAME="azooKeyMac"
SCHEME="azooKeyMac"
APP_NAME="yuzKey"
CONFIGURATION="Release"
ARCHIVE_PATH="./build/archive.xcarchive"
EXPORT_PATH="./build/export"
EXPORT_OPTIONS_PLIST="./exportOptions.plist"
PKG_SCRIPTS_SOURCE_PATH="./pkg-scripts"
PKG_SCRIPTS_PATH="./build/pkg-scripts"

# 1. Clean Build
rm -rf ./build
mkdir -p ./build
rm -rf ./Core/.build
rm -f ./Core/Package.resolved

# 2. Archive
# Note: use `"$(mktemp -d)` to avoid conflicts with previous builds
xcodebuild \
  -project "${PROJECT_NAME}.xcodeproj" \
  -scheme "${SCHEME}" \
  clean archive \
  -configuration "${CONFIGURATION}" \
  -archivePath "${ARCHIVE_PATH}" \
  -derivedDataPath "$(mktemp -d)" \
  -clonedSourcePackagesDirPath $(mktemp -d) \
  -allowProvisioningUpdates \
  -destination "generic/platform=macOS"

# 3. Export
xcodebuild -exportArchive \
  -archivePath "${ARCHIVE_PATH}" \
  -exportPath "${EXPORT_PATH}" \
  -exportOptionsPlist "${EXPORT_OPTIONS_PLIST}" \
  -allowProvisioningUpdates

# 4. Notarize .app
APP_PATH="${EXPORT_PATH}/${APP_NAME}.app"
APP_ZIP="${APP_NAME}.zip"

# Zip the .app for notarization
ditto -c -k --sequesterRsrc --keepParent "${APP_PATH}" "${APP_ZIP}"

# Submit the .app (zip) for notarization
xcrun notarytool submit "${APP_ZIP}" --keychain-profile "Notarytool" --wait

# Staple the notarization ticket to the .app
xcrun stapler staple "${APP_PATH}"

# Remove the temporary zip
rm "${APP_ZIP}"
rm ${EXPORT_PATH}/Packaging.log
rm ${EXPORT_PATH}/DistributionSummary.plist
rm ${EXPORT_PATH}/ExportOptions.plist

mkdir -p "${PKG_SCRIPTS_PATH}"
cp "${PKG_SCRIPTS_SOURCE_PATH}/postinstall" "${PKG_SCRIPTS_PATH}/postinstall"
cp "./Tools/write_converter_server_launch_agent.sh" "${PKG_SCRIPTS_PATH}/write_converter_server_launch_agent.sh"
chmod +x "${PKG_SCRIPTS_PATH}/postinstall" "${PKG_SCRIPTS_PATH}/write_converter_server_launch_agent.sh"

# Suppose we have build/yuzKey.app
# Use this script to create a plist package for distribution
# pkgbuild --analyze --root ./build/ pkg.plist

# Create a temporary package
pkgbuild --root ${EXPORT_PATH} \
         --scripts ${PKG_SCRIPTS_PATH} \
         --component-plist pkg.plist --identifier io.github.shinespark.inputmethod.yuzKey \
         --version 0 \
         --install-location /Library/Input\ Methods \
         yuzKey-tmp.pkg

# Create a distribution file
# productbuild --synthesize --package yuzKey-tmp.pkg distribution.xml

# Build the final package
productbuild --distribution distribution.xml --package-path . yuzKey-release.pkg

# Clean up
rm yuzKey-tmp.pkg

# Sign Pkg
productsign --sign "Developer ID Installer" ./yuzKey-release.pkg ./yuzKey-release-signed.pkg
rm yuzKey-release.pkg

# Submit for Notarization
# For fork developers: You would need to update `--keychain--profile "Notarytool"` part, because this is environment-depenedent command.
xcrun notarytool submit yuzKey-release-signed.pkg --keychain-profile "Notarytool" --wait

# Staple
xcrun stapler staple yuzKey-release-signed.pkg
