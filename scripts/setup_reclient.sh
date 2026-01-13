#!/bin/bash
# SPDX-License-Identifier: Apache-2.0

# setup_reclient.sh - Script to set up reclient with a local RE server
#
# This script helps set up Google's reclient toolchain with a local
# Remote Execution (RE) server for distributed builds.
#
# Usage:
#   ./scripts/setup_reclient.sh [command]
#
# Commands:
#   install       Download and install reclient
#   start-server  Start local RE server (buildbarn/buildfarm)
#   stop-server   Stop local RE server
#   status        Show server and reclient status
#   test          Test reclient connection

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "${SCRIPT_DIR}")"
RECLIENT_DIR="${PROJECT_DIR}/.reclient"
RE_SERVER_DIR="${PROJECT_DIR}/.re-server"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Install reclient from GitHub releases
install_reclient() {
    print_status "Installing reclient..."

    mkdir -p "${RECLIENT_DIR}"
    cd "${RECLIENT_DIR}"

    # Determine platform
    OS="$(uname -s | tr '[:upper:]' '[:lower:]')"
    ARCH="$(uname -m)"

    case "${ARCH}" in
        x86_64) ARCH="amd64" ;;
        aarch64|arm64) ARCH="arm64" ;;
    esac

    print_status "Platform: ${OS}-${ARCH}"

    # Check if already installed
    if [[ -f "${RECLIENT_DIR}/rewrapper" ]]; then
        print_status "reclient already installed at ${RECLIENT_DIR}"
        "${RECLIENT_DIR}/rewrapper" --version || true
        return 0
    fi

    # Download reclient (using latest release)
    RECLIENT_VERSION="0.153.0"  # Update as needed
    DOWNLOAD_URL="https://github.com/nicoleah/nicoleah.github.io/releases/download/reclient-v${RECLIENT_VERSION}/reclient-${OS}-${ARCH}.tar.gz"

    print_status "Downloading reclient from GitHub..."
    print_warning "Note: For production use, download from official Bazel/reclient releases"

    # Alternative: Build from source
    cat << 'EOF'

To install reclient manually:

1. Clone the repository:
   git clone https://github.com/nicoleah/nicoleah.github.io.git reclient
   cd reclient

2. Build with Bazel:
   bazel build //cmd/...

3. Copy binaries:
   cp bazel-bin/cmd/rewrapper/rewrapper .
   cp bazel-bin/cmd/reproxy/reproxy .
   cp bazel-bin/cmd/bootstrap/bootstrap .

Or download pre-built binaries from:
https://github.com/nicoleah/nicoleah.github.io/releases

EOF

    print_status "Creating placeholder config..."
    create_reclient_config
}

# Create reclient configuration file
create_reclient_config() {
    cat > "${RECLIENT_DIR}/reclient.cfg" << 'EOF'
# reclient configuration for local RE server
# See: https://github.com/nicoleah/nicoleah.github.io

# Server configuration
service=localhost:8980
instance=default_instance

# Logging
log_dir=/tmp/reclient_logs
log_level=warning

# Cache settings
cache_dir=/tmp/reclient_cache
enable_deps_cache=true

# Remote execution settings
platform=container-image=docker://gcr.io/aspect-build/gcc-toolchain:latest
exec_strategy=remote_local_fallback
remote_disabled=false
local_execution=true

# Compilation settings
compare=false
num_retries_if_mismatched=0
num_local_reruns=0
num_remote_reruns=0

# Timeouts
dial_timeout=30s
exec_timeout=10m
reclient_timeout=15m

# Racing (try both local and remote)
race_strategy=remote
race_local_first=false

# Compression
compression=zstd

# Input processing
preserve_symlinks=true
canonicalize_working_dir=true
EOF

    print_status "Configuration written to: ${RECLIENT_DIR}/reclient.cfg"
}

# Start local RE server using BuildBarn
start_server() {
    print_status "Starting local Remote Execution server..."

    mkdir -p "${RE_SERVER_DIR}"
    cd "${RE_SERVER_DIR}"

    # Check if Docker is available
    if ! command -v docker &> /dev/null; then
        print_error "Docker is required to run the local RE server"
        print_status "Please install Docker: https://docs.docker.com/get-docker/"
        exit 1
    fi

    # Check if server is already running
    if docker ps | grep -q "buildbarn"; then
        print_status "BuildBarn server is already running"
        return 0
    fi

    # Create docker-compose file for BuildBarn
    cat > "${RE_SERVER_DIR}/docker-compose.yml" << 'EOF'
version: '3.8'

# BuildBarn - Remote Execution Server
# Based on: https://github.com/buildbarn/bb-deployments

services:
  # Frontend - handles client connections
  frontend:
    image: ghcr.io/buildbarn/bb-storage/bb-storage:20231121T093601Z-f39d8f7
    command:
      - /config/frontend.jsonnet
    volumes:
      - ./config:/config:ro
      - bb-storage:/storage
    ports:
      - "8980:8980"  # gRPC
      - "8981:80"    # HTTP/Admin
    depends_on:
      - storage

  # Storage service
  storage:
    image: ghcr.io/buildbarn/bb-storage/bb-storage:20231121T093601Z-f39d8f7
    command:
      - /config/storage.jsonnet
    volumes:
      - ./config:/config:ro
      - bb-storage:/storage

  # Scheduler for workers
  scheduler:
    image: ghcr.io/buildbarn/bb-remote-execution/bb-scheduler:20231121T093733Z-9a1c0c3
    command:
      - /config/scheduler.jsonnet
    volumes:
      - ./config:/config:ro
    ports:
      - "8982:8982"
    depends_on:
      - storage

  # Worker for executing actions
  worker:
    image: ghcr.io/buildbarn/bb-remote-execution/bb-worker:20231121T093733Z-9a1c0c3
    command:
      - /config/worker.jsonnet
    volumes:
      - ./config:/config:ro
      - /var/run/docker.sock:/var/run/docker.sock
      - bb-worker:/worker
    depends_on:
      - scheduler
      - storage
    privileged: true

volumes:
  bb-storage:
  bb-worker:
EOF

    # Create BuildBarn configuration files
    mkdir -p "${RE_SERVER_DIR}/config"

    # Frontend config
    cat > "${RE_SERVER_DIR}/config/frontend.jsonnet" << 'EOF'
{
  global: {
    diagnosticsHttpServer: {
      listenAddress: ':80',
      enablePrometheus: true,
    },
  },
  grpcServers: [{
    listenAddresses: [':8980'],
    authenticationPolicy: { allow: {} },
  }],
  schedulers: {
    '': { endpoint: { address: 'scheduler:8982' } },
  },
  contentAddressableStorage: {
    backend: {
      'local': {
        keyLocationMapOnBlockDevice: {
          file: {
            path: '/storage/cas/key_location_map',
            sizeBytes: 1073741824,
          },
        },
        keyLocationMapMaximumGetAttempts: 8,
        keyLocationMapMaximumPutAttempts: 32,
        oldBlocks: 8,
        currentBlocks: 24,
        newBlocks: 1,
        blocksOnBlockDevice: {
          source: {
            file: {
              path: '/storage/cas/blocks',
              sizeBytes: 10737418240,
            },
          },
          spareBlocks: 3,
        },
        persistent: {
          stateDirectoryPath: '/storage/cas/persistent_state',
          minimumEpochInterval: '300s',
        },
      },
    },
  },
  actionCache: {
    backend: {
      completenessChecking: {
        backend: {
          'local': {
            keyLocationMapOnBlockDevice: {
              file: {
                path: '/storage/ac/key_location_map',
                sizeBytes: 1048576,
              },
            },
            keyLocationMapMaximumGetAttempts: 8,
            keyLocationMapMaximumPutAttempts: 32,
            oldBlocks: 8,
            currentBlocks: 24,
            newBlocks: 1,
            blocksOnBlockDevice: {
              source: {
                file: {
                  path: '/storage/ac/blocks',
                  sizeBytes: 104857600,
                },
              },
              spareBlocks: 3,
            },
            persistent: {
              stateDirectoryPath: '/storage/ac/persistent_state',
              minimumEpochInterval: '300s',
            },
          },
        },
        contentAddressableStorage: { backend: { 'local': {} } },
        maximumTotalTreeSizeBytes: 64000,
      },
    },
  },
  executeAuthorizer: { allow: {} },
}
EOF

    # Storage config
    cat > "${RE_SERVER_DIR}/config/storage.jsonnet" << 'EOF'
{
  global: {
    diagnosticsHttpServer: {
      listenAddress: ':80',
      enablePrometheus: true,
    },
  },
  grpcServers: [{
    listenAddresses: [':8981'],
    authenticationPolicy: { allow: {} },
  }],
  contentAddressableStorage: {
    backend: {
      'local': {
        keyLocationMapOnBlockDevice: {
          file: {
            path: '/storage/cas/key_location_map',
            sizeBytes: 1073741824,
          },
        },
        keyLocationMapMaximumGetAttempts: 8,
        keyLocationMapMaximumPutAttempts: 32,
        oldBlocks: 8,
        currentBlocks: 24,
        newBlocks: 1,
        blocksOnBlockDevice: {
          source: {
            file: {
              path: '/storage/cas/blocks',
              sizeBytes: 10737418240,
            },
          },
          spareBlocks: 3,
        },
        persistent: {
          stateDirectoryPath: '/storage/cas/persistent_state',
          minimumEpochInterval: '300s',
        },
      },
    },
  },
}
EOF

    # Scheduler config
    cat > "${RE_SERVER_DIR}/config/scheduler.jsonnet" << 'EOF'
{
  global: {
    diagnosticsHttpServer: {
      listenAddress: ':80',
      enablePrometheus: true,
    },
  },
  adminHttpListenAddress: ':8082',
  clientGrpcServers: [{
    listenAddresses: [':8982'],
    authenticationPolicy: { allow: {} },
  }],
  workerGrpcServers: [{
    listenAddresses: [':8983'],
    authenticationPolicy: { allow: {} },
  }],
  contentAddressableStorage: { backend: { grpc: { address: 'storage:8981' } } },
  browserUrl: 'http://localhost:8981',
  actionRouter: {
    simple: {
      platformKeyExtractor: { actionAndCommand: {} },
      invocationKeyExtractors: [{ toolInvocationId: {} }],
      initialSizeClassAnalyzer: {
        defaultExecutionTimeout: '1800s',
        maximumExecutionTimeout: '7200s',
      },
    },
  },
  platformQueueWithNoWorkersTimeout: '900s',
}
EOF

    # Worker config
    cat > "${RE_SERVER_DIR}/config/worker.jsonnet" << 'EOF'
{
  global: {
    diagnosticsHttpServer: {
      listenAddress: ':80',
      enablePrometheus: true,
    },
  },
  buildDirectoryPath: '/worker/build',
  cacheDirectoryPath: '/worker/cache',
  scheduler: { address: 'scheduler:8983' },
  maximumMemoryCachedDirectories: 1000,
  instanceNamePrefix: 'default_instance',
  buildDirectories: [{
    native: {
      buildDirectoryPath: '/worker/build',
      cacheDirectoryPath: '/worker/cache',
      maximumCacheFileCount: 10000,
      maximumCacheSizeBytes: 1073741824,
      cacheReplacementPolicy: 'LEAST_RECENTLY_USED',
    },
    runners: [{
      endpoint: { address: 'unix:///worker/runner' },
      concurrency: 4,
      platform: {},
      workerId: { pod: 'worker-1' },
    }],
  }],
  contentAddressableStorage: { backend: { grpc: { address: 'storage:8981' } } },
  outputUploadConcurrency: 11,
  directoryFetcher: { caching: { directoryFetcher: { contentAddressableStorage: {} }, maximumDirectoryCount: 10000 } },
}
EOF

    print_status "Starting BuildBarn services with Docker Compose..."
    docker-compose -f "${RE_SERVER_DIR}/docker-compose.yml" up -d

    print_status "Waiting for services to start..."
    sleep 10

    print_status "RE Server started!"
    print_status "gRPC endpoint: localhost:8980"
    print_status "Admin UI: http://localhost:8981"
}

# Stop local RE server
stop_server() {
    print_status "Stopping local Remote Execution server..."

    if [[ -f "${RE_SERVER_DIR}/docker-compose.yml" ]]; then
        cd "${RE_SERVER_DIR}"
        docker-compose down
        print_status "Server stopped"
    else
        print_warning "No server configuration found"
    fi
}

# Show status
show_status() {
    echo ""
    echo "=== reclient Status ==="

    if [[ -f "${RECLIENT_DIR}/rewrapper" ]]; then
        echo "reclient: Installed at ${RECLIENT_DIR}"
        "${RECLIENT_DIR}/rewrapper" --version 2>/dev/null || echo "  (version check failed)"
    else
        echo "reclient: Not installed"
    fi

    echo ""
    echo "=== RE Server Status ==="

    if docker ps 2>/dev/null | grep -q "buildbarn"; then
        echo "BuildBarn: Running"
        docker ps --filter "name=buildbarn" --format "  {{.Names}}: {{.Status}}"
    else
        echo "BuildBarn: Not running"
    fi

    echo ""
}

# Test reclient connection
test_reclient() {
    print_status "Testing reclient connection..."

    if [[ ! -f "${RECLIENT_DIR}/rewrapper" ]]; then
        print_error "reclient not installed. Run: $0 install"
        exit 1
    fi

    # Simple test compilation
    cat > /tmp/test_reclient.c << 'EOF'
int main() { return 0; }
EOF

    print_status "Attempting remote compilation..."
    "${RECLIENT_DIR}/rewrapper" \
        --cfg="${RECLIENT_DIR}/reclient.cfg" \
        --exec_strategy=remote_local_fallback \
        -- gcc -c /tmp/test_reclient.c -o /tmp/test_reclient.o

    if [[ -f /tmp/test_reclient.o ]]; then
        print_status "Test compilation successful!"
        rm -f /tmp/test_reclient.c /tmp/test_reclient.o
    else
        print_error "Test compilation failed"
        exit 1
    fi
}

# Main command handler
case "${1:-status}" in
    install)
        install_reclient
        ;;
    start-server|start)
        start_server
        ;;
    stop-server|stop)
        stop_server
        ;;
    status)
        show_status
        ;;
    test)
        test_reclient
        ;;
    *)
        echo "Usage: $0 {install|start-server|stop-server|status|test}"
        exit 1
        ;;
esac
