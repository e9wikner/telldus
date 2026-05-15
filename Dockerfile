# syntax=docker/dockerfile:1
FROM debian:bookworm-slim AS build
ENV DEBIAN_FRONTEND=noninteractive

# Install build dependencies
RUN apt-get update -qq && apt-get install -y -q \
	cmake \
	build-essential \
	pkg-config \
	libftdi1-dev \
	libconfuse-dev \
	libusb-1.0-0-dev \
	libcppunit-dev \
	&& rm -rf /var/lib/apt/lists/*

WORKDIR /build

# Copy source and configure
COPY . .
RUN cmake --preset headless

# Build and test (single-threaded for QEMU stability)
RUN cmake --build build/headless --parallel 1
RUN ctest --test-dir build/headless -R cppunit --output-on-failure

# --- Final stage ---
FROM debian:bookworm-slim
ENV DEBIAN_FRONTEND=noninteractive

# Install runtime libraries only
RUN apt-get update -qq && apt-get install -y -q --no-install-recommends \
	libftdi1-2 \
	libconfuse2 \
	libusb-1.0-0 \
	tini \
	usbutils \
	&& rm -rf /var/lib/apt/lists/*

# Copy artifacts from build stage
COPY --from=build /build/build/headless/service/telldusd /usr/local/sbin/
COPY --from=build /build/build/headless/client/libtelldus-core.so* /usr/local/lib/
COPY --from=build /build/build/headless/tdtool/tdtool /usr/local/bin/
COPY --from=build /build/build/headless/tdadmin/tdadmin /usr/local/bin/

# Copy sample config as fallback
COPY telldus-core/service/tellstick.conf /etc/tellstick.conf

# Copy and install entrypoint script
COPY scripts/docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh
RUN chmod +x /usr/local/bin/docker-entrypoint.sh

# Update library cache
RUN ldconfig

# tini as PID 1 for signal forwarding and zombie reaping,
# then delegate to smart dispatch entrypoint
ENTRYPOINT ["/usr/bin/tini", "--", "/usr/local/bin/docker-entrypoint.sh"]
CMD ["telldusd", "--nodaemon"]
