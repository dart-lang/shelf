#!/bin/bash

set -euo pipefail

# Verify we are in the correct directory
if [ ! -f "pubspec.yaml" ] || ! grep -q "name: _shelf_compliance" "pubspec.yaml"; then
  echo "Error: This script must be run from the root of pkgs/_shelf_compliance!"
  exit 1
fi

echo "Checking out submodules..."
git -C ../.. submodule update --init --recursive

export PATH="$PATH:$HOME/.dotnet"

if command -v dotnet >/dev/null 2>&1 && dotnet --list-sdks | grep -q '^10\.'; then
  echo "Found existing .NET 10 SDK:"
  dotnet --version
else
  echo "Installing .NET 10 SDK..."
  curl -sSL https://dot.net/v1/dotnet-install.sh -O
  chmod +x ./dotnet-install.sh
  ./dotnet-install.sh --channel 10.0

  echo "Installed dotnet version:"
  dotnet --version
fi

echo "Running compliance tests..."
dart test
