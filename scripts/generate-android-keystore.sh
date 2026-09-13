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
REPOSITORY_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
STORE_FILE="${FLASH_RELEASE_STORE_FILE:-}"
STORE_PASS="${FLASH_RELEASE_STORE_PASSWORD:-}"
KEY_PASS="${FLASH_RELEASE_KEY_PASSWORD:-}"
KEY_ALIAS="${FLASH_RELEASE_KEY_ALIAS:-flash-release}"

if [[ -z "${STORE_FILE}" || -z "${STORE_PASS}" || -z "${KEY_PASS}" ]]; then
  echo "Refusing to create a release key with a default password." >&2
  echo "Set FLASH_RELEASE_STORE_FILE, FLASH_RELEASE_STORE_PASSWORD and FLASH_RELEASE_KEY_PASSWORD first." >&2
  exit 1
fi

if [[ "${STORE_FILE}" != /* ]]; then
  echo "FLASH_RELEASE_STORE_FILE must be an absolute path outside the repository." >&2
  exit 1
fi

case "${STORE_FILE}" in
  "${REPOSITORY_DIR}"/*)
    echo "Refusing to create a signing key inside the repository." >&2
    exit 1
    ;;
esac

if [[ ${#STORE_PASS} -lt 12 || ${#KEY_PASS} -lt 12 ]]; then
  echo "Release-key passwords must each contain at least 12 characters." >&2
  exit 1
fi

if [[ -e "${STORE_FILE}" ]]; then
  echo "Refusing to overwrite ${STORE_FILE}." >&2
  exit 1
fi

umask 077

keytool -genkey -v \
  -keystore "${STORE_FILE}" \
  -alias "${KEY_ALIAS}" \
  -keyalg RSA \
  -keysize 2048 \
  -validity 10950 \
  -storepass "${STORE_PASS}" \
  -keypass "${KEY_PASS}" \
  -dname "CN=Flash Dev"

echo "Keystore created at ${STORE_FILE}"
