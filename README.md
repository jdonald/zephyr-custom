# Zephyr Custom ARMv7 Board - Hello World

An experimental Zephyr RTOS project demonstrating a "hello world" application built for a **custom out-of-tree board definition** targeting an ARMv7-based chip.

## Overview

This project showcases:

- **Out-of-tree board definition** - Custom ARMv7 board (STM32F407-based) without using Zephyr's built-in boards
- **Kconfig configuration** - Multiple custom Kconfig options demonstrating the configuration system
- **CMake + Ninja build** - Modern build system with optional ccache and reclient support
- **Distributed builds** - Integration with Google's reclient for remote execution

## Project Structure

```
zephyr-custom/
├── boards/
│   └── arm/
│       └── custom_armv7_board/     # Out-of-tree board definition
│           ├── Kconfig.board        # Board selection Kconfig
│           ├── Kconfig.defconfig    # Default configs when board selected
│           ├── custom_armv7_board_defconfig
│           ├── custom_armv7_board.dts    # Device tree
│           ├── custom_armv7_board.yaml   # Board metadata
│           └── board.cmake          # CMake/runner config
├── cmake/
│   └── compiler_cache.cmake    # ccache/reclient CMake module
├── scripts/
│   ├── build.sh               # Build helper script
│   └── setup_reclient.sh      # reclient/RE server setup
├── src/
│   └── main.c                 # Hello world application
├── CMakeLists.txt             # Main CMake configuration
├── Kconfig                    # Application Kconfig
├── prj.conf                   # Project configuration
└── west.yml                   # West workspace manifest
```

## Prerequisites

### Zephyr SDK Installation

1. Follow the [Zephyr Getting Started Guide](https://docs.zephyrproject.org/latest/develop/getting_started/index.html)

2. Install the Zephyr SDK:
   ```bash
   # Download and install Zephyr SDK (example for v0.16.4)
   cd ~
   wget https://github.com/zephyrproject-rtos/sdk-ng/releases/download/v0.16.4/zephyr-sdk-0.16.4_linux-x86_64.tar.xz
   tar xvf zephyr-sdk-0.16.4_linux-x86_64.tar.xz
   cd zephyr-sdk-0.16.4
   ./setup.sh
   ```

3. Install west (Zephyr's meta-tool):
   ```bash
   pip install west
   ```

### Optional: ccache

For faster incremental builds:

```bash
# Ubuntu/Debian
sudo apt install ccache

# macOS
brew install ccache

# Verify installation
ccache --version
```

### Optional: reclient

For distributed/remote builds. See [Reclient Setup](#reclient-distributed-builds) section below.

## Building the Firmware

### Method 1: Using West (Recommended)

```bash
# Initialize workspace (first time only)
west init -l .
west update

# Build with the custom board
west build -b custom_armv7_board --board-root .

# Build with ccache
west build -b custom_armv7_board --board-root . -- -DUSE_CCACHE=ON
```

### Method 2: Using CMake + Ninja Directly

```bash
# Source Zephyr environment
source ~/zephyrproject/zephyr/zephyr-env.sh

# Create build directory
mkdir build && cd build

# Configure with CMake (using Ninja generator)
cmake -GNinja \
    -DBOARD=custom_armv7_board \
    -DBOARD_ROOT=/path/to/zephyr-custom \
    ..

# Build
ninja

# Or build with verbose output
ninja -v
```

### Method 3: Using the Build Script

```bash
# Basic build
./scripts/build.sh

# Build with ccache
./scripts/build.sh --ccache

# Build with reclient
./scripts/build.sh --reclient --reclient-cfg /path/to/reclient.cfg

# Clean build
./scripts/build.sh --pristine

# Verbose build
./scripts/build.sh --verbose
```

### Build Options

| Option | CMake Flag | Description |
|--------|------------|-------------|
| ccache | `-DUSE_CCACHE=ON` | Enable local compilation caching |
| reclient | `-DUSE_RECLIENT=ON` | Enable remote execution |
| reclient config | `-DRECLIENT_CFG=/path/to/cfg` | Path to reclient config file |

## Kconfig Configuration

This project demonstrates the Zephyr Kconfig system with several custom options:

### Application Options (in `prj.conf`)

```kconfig
# Application version string
CONFIG_HELLO_APP_VERSION="1.0.0-custom"

# LED blink interval (100-10000 ms)
CONFIG_HELLO_BLINK_INTERVAL_MS=500

# Enable debug logging
CONFIG_HELLO_ENABLE_DEBUG_LOG=y

# Custom board features
CONFIG_CUSTOM_BOARD_LED_COUNT=3
CONFIG_CUSTOM_BOARD_BUTTON_COUNT=1
```

### Interactive Configuration

Use `menuconfig` to interactively configure options:

```bash
# Using west
west build -t menuconfig

# Using ninja directly (from build directory)
ninja menuconfig
```

Navigate to "Hello World Application Settings" to see custom options.

## ccache Local Caching

ccache provides local compilation caching for faster incremental rebuilds.

### Setup

```bash
# Install ccache
sudo apt install ccache  # Ubuntu/Debian
brew install ccache       # macOS

# Configure ccache (optional - defaults work well)
ccache --max-size=5G
ccache --set-config=compression=true
```

### Usage

```bash
# Build with ccache enabled
cmake -GNinja -DBOARD=custom_armv7_board -DBOARD_ROOT=. -DUSE_CCACHE=ON ..
ninja

# Check ccache statistics
ccache -s
```

### Performance Tips

- First build populates the cache
- Subsequent builds see 10-100x speedup for unchanged files
- Cache survives across `ninja clean`
- Use `ccache -C` to clear cache if needed

## Reclient Distributed Builds

[reclient](https://github.com/bazelbuild/reclient) is Google's remote execution client that enables distributed compilation using the [Remote Execution API](https://github.com/nicoleah/nicoleah.github.io/remote-apis).

### Components

- **rewrapper** - Wraps compiler invocations for remote execution
- **reproxy** - Local proxy that handles remote execution requests
- **bootstrap** - Manages credentials and reproxy lifecycle

### Installing reclient

```bash
# Clone and build from source
git clone https://github.com/nicoleah/nicoleah.github.io.git
cd nicoleah
bazel build //cmd/...

# Copy binaries to a location in PATH
sudo cp bazel-bin/cmd/rewrapper/rewrapper /usr/local/bin/
sudo cp bazel-bin/cmd/reproxy/reproxy /usr/local/bin/
sudo cp bazel-bin/cmd/bootstrap/bootstrap /usr/local/bin/
```

Or use the setup script:

```bash
./scripts/setup_reclient.sh install
```

### Configuring reclient

Create a configuration file `reclient.cfg`:

```cfg
# reclient.cfg - Configuration for remote execution

# Server connection
service=localhost:8980
instance=default_instance

# Execution strategy
# Options: local, remote, remote_local_fallback, racing
exec_strategy=remote_local_fallback

# Logging
log_dir=/tmp/reclient_logs
log_level=warning

# Cache settings
cache_dir=/tmp/reclient_cache
enable_deps_cache=true

# Timeouts
dial_timeout=30s
exec_timeout=10m

# Compression
compression=zstd
```

### Building with reclient

```bash
# Start reproxy (in a separate terminal or as a service)
reproxy --cfg=reclient.cfg &

# Build with reclient
cmake -GNinja \
    -DBOARD=custom_armv7_board \
    -DBOARD_ROOT=. \
    -DUSE_RECLIENT=ON \
    -DRECLIENT_CFG=/path/to/reclient.cfg \
    ..

ninja

# Shutdown reproxy when done
bootstrap --cfg=reclient.cfg --shutdown
```

## Setting Up a Local RE Server

For testing reclient locally, you can run a Remote Execution server. We recommend [BuildBarn](https://github.com/buildbarn/bb-deployments).

### Quick Start with Docker

```bash
# Use the setup script
./scripts/setup_reclient.sh start-server

# Or manually with Docker Compose
cd .re-server
docker-compose up -d
```

### Manual BuildBarn Setup

1. **Clone bb-deployments:**
   ```bash
   git clone https://github.com/buildbarn/bb-deployments.git
   cd bb-deployments
   ```

2. **Start with Docker Compose:**
   ```bash
   cd docker-compose
   docker-compose up -d
   ```

3. **Verify services:**
   ```bash
   # Check running containers
   docker-compose ps

   # Test gRPC endpoint
   grpcurl -plaintext localhost:8980 list
   ```

### RE Server Architecture

```
┌─────────────────────────────────────────────────────────┐
│                    Client Machine                        │
│  ┌─────────┐    ┌─────────┐    ┌──────────────────┐    │
│  │ CMake/  │───▶│rewrapper│───▶│     reproxy      │    │
│  │ Ninja   │    │         │    │ (local proxy)    │    │
│  └─────────┘    └─────────┘    └────────┬─────────┘    │
└─────────────────────────────────────────┼───────────────┘
                                          │ gRPC
                                          ▼
┌─────────────────────────────────────────────────────────┐
│                    RE Server (BuildBarn)                 │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐     │
│  │  Frontend   │  │  Scheduler  │  │   Storage   │     │
│  │ :8980 gRPC  │  │   :8982     │  │ (CAS + AC)  │     │
│  └──────┬──────┘  └──────┬──────┘  └──────┬──────┘     │
│         │                │                │             │
│         └────────────────┼────────────────┘             │
│                          ▼                              │
│                   ┌─────────────┐                       │
│                   │   Workers   │                       │
│                   │ (execution) │                       │
│                   └─────────────┘                       │
└─────────────────────────────────────────────────────────┘
```

### Alternative: Buildfarm

[Buildfarm](https://github.com/bazelbuild/bazel-buildfarm) is another RE-compatible server:

```bash
# Clone Buildfarm
git clone https://github.com/bazelbuild/bazel-buildfarm.git
cd bazel-buildfarm

# Build and run server
bazel run //src/main/java/build/buildfarm:buildfarm-server -- \
    $(pwd)/examples/config.minimal.yml

# Run worker
bazel run //src/main/java/build/buildfarm:buildfarm-operationqueue-worker -- \
    $(pwd)/examples/config.minimal.yml
```

### Cloud RE Services

For production use, consider cloud-hosted RE services:

- **Google Cloud Remote Build Execution** (deprecated, migrating to other solutions)
- **BuildBuddy** - [buildbuddy.io](https://www.buildbuddy.io/)
- **EngFlow** - [engflow.com](https://www.engflow.com/)

Example configuration for BuildBuddy:

```cfg
# reclient.cfg for BuildBuddy
service=remote.buildbuddy.io:443
instance=your-org/default
use_tls=true
tls_client_auth_cert=/path/to/client.crt
tls_client_auth_key=/path/to/client.key
```

## Custom Board Details

The `custom_armv7_board` is an out-of-tree board definition based on the STM32F407VG MCU:

| Feature | Specification |
|---------|--------------|
| CPU | ARM Cortex-M4 @ 168 MHz |
| Architecture | ARMv7-M with FPU |
| Flash | 1 MB |
| SRAM | 192 KB |
| CCM | 64 KB |
| LEDs | 3 (PD12, PD13, PD14) |
| Buttons | 1 (PA0) |
| Console | USART2 @ 115200 baud |

### Device Tree Customization

The board's device tree (`custom_armv7_board.dts`) defines:
- GPIO pins for LEDs and buttons
- USART2 for console output
- Clock configuration (168 MHz from 8 MHz HSE)
- Flash partitions for bootloader, app, and storage

### Porting to Other MCUs

To create a board for a different ARMv7 MCU:

1. Copy the `boards/arm/custom_armv7_board/` directory
2. Rename files to match your board name
3. Update `Kconfig.board` with correct SoC dependencies
4. Modify the device tree for your pinout
5. Adjust clock and peripheral configuration

## Flashing the Firmware

After building, flash the firmware using your preferred method:

```bash
# Using west + OpenOCD
west flash

# Using west + J-Link
west flash --runner jlink

# Using west + STM32CubeProgrammer
west flash --runner stm32cubeprogrammer

# Direct OpenOCD command
openocd -f interface/stlink.cfg -f target/stm32f4x.cfg \
    -c "program build/zephyr/zephyr.elf verify reset exit"
```

## Debugging

```bash
# Start debug session with west
west debug

# Or use GDB directly
arm-none-eabi-gdb build/zephyr/zephyr.elf \
    -ex "target remote localhost:3333"
```

## Troubleshooting

### Build Errors

**"ZEPHYR_BASE not set"**
```bash
source ~/zephyrproject/zephyr/zephyr-env.sh
```

**"Board not found"**
```bash
# Ensure BOARD_ROOT points to project directory
cmake -DBOARD_ROOT=/full/path/to/zephyr-custom ...
```

### reclient Issues

**"Connection refused"**
- Ensure reproxy is running: `pgrep reproxy`
- Check server is accessible: `grpcurl -plaintext localhost:8980 list`

**"Authentication failed"**
- For local server: Use `authenticationPolicy: { allow: {} }`
- For cloud services: Check credentials with `bootstrap --cfg=reclient.cfg`

### ccache Issues

**"Cache miss rate high"**
```bash
# Check ccache config
ccache -p

# Ensure consistent compiler paths
export CC=/usr/bin/gcc
export CXX=/usr/bin/g++
```

## License

SPDX-License-Identifier: Apache-2.0

See [LICENSE](LICENSE) for details.
