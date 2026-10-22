#!/bin/bash

# Exit on error
set -e

# Verify we are in the correct directory
if [ ! -f "pubspec.yaml" ] || ! grep -q "name: _shelf_compliance" "pubspec.yaml"; then
  echo "Error: This script must be run from the root of pkgs/_shelf_compliance!"
  exit 1
fi

echo "Checking out submodules..."
git -C ../.. submodule update --init --recursive

export PATH="$HOME/.local/share/mise/shims:$HOME/.dotnet:$PATH"

if command -v dotnet >/dev/null 2>&1 && dotnet --list-sdks | grep -q '^10\.'; then
  echo "Found existing .NET 10 SDK:"
  dotnet --version
else
  echo "Installing .NET 10 SDK..."
  # Download install script
  curl -sSL https://dot.net/v1/dotnet-install.sh -O

  # Make it executable
  chmod +x ./dotnet-install.sh

  # Install .NET 10 latest patch
  ./dotnet-install.sh --channel 10.0

  echo "Installed dotnet version:"
  dotnet --version
fi

echo "Running compliance tests..."
dart test test/compliance_test.dart
