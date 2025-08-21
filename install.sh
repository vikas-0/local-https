#!/usr/bin/env bash
set -euo pipefail

OS=$(uname -s || echo unknown)

ensure_mkcert() {
  if command -v mkcert >/dev/null 2>&1; then
    return 0
  fi

  echo "mkcert not found. Attempting to install..."

  if command -v brew >/dev/null 2>&1; then
    # Works on macOS and Linux (Homebrew/Linuxbrew)
    brew install mkcert || true
  elif [[ "$OS" == "Linux" ]]; then
    if command -v apt-get >/dev/null 2>&1; then
      sudo apt-get update -y && sudo apt-get install -y mkcert || true
    elif command -v dnf >/dev/null 2>&1; then
      sudo dnf install -y mkcert || true
    elif command -v yum >/dev/null 2>&1; then
      sudo yum install -y mkcert || true
    elif command -v pacman >/dev/null 2>&1; then
      sudo pacman -Sy --noconfirm mkcert || true
    elif command -v zypper >/dev/null 2>&1; then
      sudo zypper install -y mkcert || true
    fi
  fi

  if ! command -v mkcert >/dev/null 2>&1; then
    echo "Could not install mkcert automatically. Please install it manually: https://github.com/FiloSottile/mkcert"
    exit 1
  fi
}

ensure_certutil() {
  if command -v certutil >/dev/null 2>&1; then
    return 0
  fi

  echo "certutil (for Firefox trust store) not found. Attempting to install..."

  if command -v brew >/dev/null 2>&1; then
    brew install nss || true
  elif [[ "$OS" == "Linux" ]]; then
    if command -v apt-get >/dev/null 2>&1; then
      sudo apt-get update -y && sudo apt-get install -y libnss3-tools || true
    elif command -v dnf >/dev/null 2>&1; then
      sudo dnf install -y nss-tools || true
    elif command -v yum >/dev/null 2>&1; then
      sudo yum install -y nss-tools || true
    elif command -v pacman >/dev/null 2>&1; then
      sudo pacman -Sy --noconfirm nss || true
    elif command -v zypper >/dev/null 2>&1; then
      sudo zypper install -y mozilla-nss-tools || true
    fi
  fi

  if ! command -v certutil >/dev/null 2>&1; then
    echo "Warning: certutil is not available, so the CA can't be automatically installed in Firefox."
    echo "Install certutil (package: nss-tools/libnss3-tools) and re-run 'mkcert -install' if you want Firefox trust."
  fi
}

ensure_mkcert
ensure_certutil

# Install the local CA (may prompt for password)
mkcert -install

echo "Building and installing the local-https gem..."

gem build local-https.gemspec
sudo gem install ./local-https-*.gem

echo "Installed. Try: local-https add myapp.test 3000 && sudo local-https start"
