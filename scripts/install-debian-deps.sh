#!/bin/bash
set -e

export DEBIAN_FRONTEND=noninteractive

echo "Installing Telldus Core headless build dependencies on Debian/Raspberry Pi OS..."

# Update package index quietly
apt-get update -qq

# Install required build and runtime dependencies
apt-get install -y -q \
	cmake \
	build-essential \
	pkg-config \
	libftdi1-dev \
	libconfuse-dev \
	libusb-1.0-0-dev \
	libcppunit-dev \
|| {
	echo "Warning: Some packages may have failed to install. Please review the output above."
	exit 1
}

echo "All dependencies installed successfully."
