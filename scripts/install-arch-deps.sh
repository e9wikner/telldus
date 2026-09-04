#!/bin/bash
set -e

echo "Installing Telldus Core headless build dependencies on Arch Linux..."

# Install required build and runtime dependencies from official repos
sudo pacman -S --needed --noconfirm \
	cmake \
	gcc \
	make \
	libftdi \
	confuse \
	libusb-compat \
	pkg-config \
	cppunit \
	mosquitto \
|| {
	echo "Warning: Some packages may have failed to install. Please review the output above."
	exit 1
}

echo "All dependencies installed successfully."
