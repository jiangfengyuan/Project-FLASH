#!/usr/bin/env bash
# Copyright (c) 2026 Fengyuan Jiang
#
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.

# Generate the internal-dev Android release keystore used by build.gradle.
# Run this after installing JDK 17+.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "${SCRIPT_DIR}/../android/app"

STORE_PASS="${FLASH_RELEASE_STORE_PASSWORD:-}"
KEY_PASS="${FLASH_RELEASE_KEY_PASSWORD:-}"
KEY_ALIAS="${FLASH_RELEASE_KEY_ALIAS:-flash-release}"

if [[ -z "${STORE_PASS}" || -z "${KEY_PASS}" ]]; then
  echo "Refusing to create a release key with a default password." >&2
  echo "Set FLASH_RELEASE_STORE_PASSWORD and FLASH_RELEASE_KEY_PASSWORD first." >&2
  exit 1
fi

if [[ ${#STORE_PASS} -lt 12 || ${#KEY_PASS} -lt 12 ]]; then
  echo "Release-key passwords must each contain at least 12 characters." >&2
  exit 1
fi

if [[ -e flash-release.keystore ]]; then
  echo "Refusing to overwrite android/app/flash-release.keystore." >&2
  exit 1
fi

umask 077

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
