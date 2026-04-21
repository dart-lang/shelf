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

echo "Installing .NET 10 SDK..."
# Download install script
curl -sSL https://dot.net/v1/dotnet-install.sh -O

# Make it executable
chmod +x ./dotnet-install.sh

# Install .NET 10 latest patch
./dotnet-install.sh --channel 10.0

# Add to PATH
export PATH="$PATH:$HOME/.dotnet"

echo "Installed dotnet version:"
dotnet --version

echo "Running compliance tests..."
dart test test/compliance_test.dart
