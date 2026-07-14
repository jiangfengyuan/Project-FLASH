#!/usr/bin/env bash
# Generate the internal-dev Android release keystore used by build.gradle.
# Run this after installing JDK 17+.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "${SCRIPT_DIR}/../android/app"

STORE_PASS="${FLASH_RELEASE_STORE_PASSWORD:-flashdev}"
KEY_PASS="${FLASH_RELEASE_KEY_PASSWORD:-${STORE_PASS}}"
KEY_ALIAS="${FLASH_RELEASE_KEY_ALIAS:-flash-release}"

keytool -genkey -v \
  -keystore flash-release.keystore \
  -alias "${KEY_ALIAS}" \
  -keyalg RSA \
  -keysize 2048 \
  -validity 10950 \
  -storepass "${STORE_PASS}" \
  -keypass "${KEY_PASS}" \
  -dname "CN=Flash Dev"

echo "Keystore created at android/app/flash-release.keystore"
