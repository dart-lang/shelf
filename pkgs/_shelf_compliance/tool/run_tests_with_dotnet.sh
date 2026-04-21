#!/bin/bash

# Exit on error
set -e

echo "Installing .NET 10 SDK..."
# Download install script
curl -sSL https://dot.net/v1/dotnet-install.sh -O

# Make it executable
chmod +x ./dotnet-install.sh

# Install .NET 10.0.106
./dotnet-install.sh --version 10.0.106

# Add to PATH
export PATH="$PATH:$HOME/.dotnet"

echo "Installed dotnet version:"
dotnet --version

echo "Running compliance tests..."
dart test test/compliance_test.dart
