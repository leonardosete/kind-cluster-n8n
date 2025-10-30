#!/bin/sh
# Copyright The Helm Authors.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# The install script is based off of the MIT-licensed script from glide,
# the package manager for Go: https://github.com/Masterminds/glide.sh/blob/master/get

: ${BINARY_NAME:="helm"}
: ${USE_SUDO:="true"}
: ${VERIFY_CHECKSUM:="true"}
: ${HELM_INSTALL_DIR:="/usr/local/bin"}
: ${GPG_PUBRING:="helm-pubring.gpg"}

# helmVersion gets the latest stable version of helm unless a version is specified
helmVersion() {
  if [ -n "$HELM_VERSION" ]; then
    VERSION=$HELM_VERSION
  else
    VERSION=$(curl -s https://api.github.com/repos/helm/helm/releases/latest | grep 'tag_name' | cut -d\" -f4)
  fi
}

# has determines if a command is present on a system
has() {
  command -v "$1" > /dev/null 2>&1
}

# has_sudo returns true if the user has sudo privileges.
has_sudo() {
  if [ "$(id -u)" = 0 ]; then
    return 0
  fi
  if ! has "sudo"; then
    return 1
  fi
  if ! sudo -n true 2> /dev/null; then
    return 1
  fi
  return 0
}

# check_sudo returns true if we have sudo privileges or if we don't need them.
check_sudo() {
  if [ "$(id -u)" = 0 ]; then
    return 0
  fi
  if ! has_sudo; then
    if [ "$USE_SUDO" = "true" ]; then
      return 1
    fi
  fi
  return 0
}

# run_as_sudo returns true if the user has sudo privileges.
run_as_sudo() {
  if has_sudo; then
    sudo "$@"
  else
    "$@"
  fi
}

# download downloads a file from a url using either curl or wget
download() {
  if has "curl"; then
    curl -SsL "$1" > "$2"
  elif has "wget"; then
    wget -qO "$2" "$1"
  else
    error "ERROR: you need curl or wget to download the binary"
  fi
}

# error prints an error message to stderr
error() {
  printf "\e[31m%s\n\e[0m" "$1" >&2
  exit 1
}

# verify_checksum verifies the checksum of a file
verify_checksum() {
  if ! has "sha256sum"; then
    error "ERROR: you need sha256sum to verify the checksum"
  fi
  local url="$1"
  local file="$2"
  local checksum_file="$file.sha256"
  download "$url.sha256" "$checksum_file"
  sha256sum -c "$checksum_file"
}

# verify_signature verifies the signature of a file
verify_signature() {
  if ! has "gpg"; then
    error "ERROR: you need gpg to verify the signature"
  fi
  local url="$1"
  local file="$2"
  local sig_file="$file.asc"
  local pubring_file="$HELM_INSTALL_DIR/$GPG_PUBRING"
  download "$url.asc" "$sig_file"
  if [ ! -f "$pubring_file" ]; then
    echo "Downloading GPG public key"
    download "https://helm.sh/helm-v3-signing-key.asc" "$pubring_file"
  fi
  gpg --no-default-keyring --keyring "$pubring_file" --verify "$sig_file" "$file"
}

# detect_arch detects the architecture of the system
detect_arch() {
  case "$(uname -m)" in
  x86_64)
    ARCH="amd64"
    ;;
  armv*)
    ARCH="arm"
    ;;
  aarch64)
    ARCH="arm64"
    ;;
  *)
    error "ERROR: unsupported architecture: $(uname -m)"
    ;;
  esac
}

# detect_os detects the operating system of the system
detect_os() {
  case "$(uname -s)" in
  Linux)
    OS="linux"
    ;;
  Darwin)
    OS="darwin"
    ;;
  *)
    error "ERROR: unsupported operating system: $(uname -s)"
    ;;
  esac
}

# main is the main function of the script
main() {
  detect_arch
  detect_os
  helmVersion

  if [ -z "$VERSION" ]; then
    error "ERROR: could not determine helm version"
  fi

  local url="https://get.helm.sh/helm-${VERSION}-${OS}-${ARCH}.tar.gz"
  local file="/tmp/helm-${VERSION}-${OS}-${ARCH}.tar.gz"

  echo "Downloading $url"
  download "$url" "$file"

  if [ "$VERIFY_CHECKSUM" = "true" ]; then
    echo "Verifying checksum"
    verify_checksum "$url" "$file"
  fi

  if [ "$VERIFY_SIGNATURE" = "true" ]; then
    echo "Verifying signature"
    verify_signature "$url" "$file"
  fi

  echo "Preparing to install $BINARY_NAME into ${HELM_INSTALL_DIR}"

  if ! check_sudo; then
    error "ERROR: sudo privileges are required to install to ${HELM_INSTALL_DIR}"
  fi

  if ! run_as_sudo "tar -C ${HELM_INSTALL_DIR} -xzf ${file} ${OS}-${ARCH}/${BINARY_NAME}"; then
    error "ERROR: failed to install $BINARY_NAME"
  fi

  if ! run_as_sudo "mv ${HELM_INSTALL_DIR}/${OS}-${ARCH}/${BINARY_NAME} ${HELM_INSTALL_DIR}/${BINARY_NAME}"; then
    error "ERROR: failed to move $BINARY_NAME"
  fi

  if ! run_as_sudo "rm -rf ${HELM_INSTALL_DIR}/${OS}-${ARCH}"; then
    error "ERROR: failed to remove temporary directory"
  fi

  echo "$BINARY_NAME installed into ${HELM_INSTALL_DIR}/${BINARY_NAME}"
}

main