#!/usr/bin/env bash
# Generate the internal-dev Android release keystore used by build.gradle.
# Run this after installing JDK 17+.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "${SCRIPT_DIR}/../android/app"

keytool -genkey -v \
  -keystore flash-release.keystore \
  -alias flash-release \
  -keyalg RSA \
  -keysize 2048 \
  -validity 10950 \
  -storepass flashdev \
  -keypass flashdev \
  -dname "CN=Flash Dev"

echo "Keystore created at android/app/flash-release.keystore"
