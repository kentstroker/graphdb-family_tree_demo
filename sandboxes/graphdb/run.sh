#!/usr/bin/env bash
# =============================================================================
# run.sh  (sandboxes/graphdb/)
# Author:  Kent Stroker
# Date:    2026-03-09
#
# Container lifecycle management for the GraphDB instance used in this demo.
# Wraps podman or docker with a simple command interface (auto-detected).
# Must be run from the graphdb/ subdirectory (or the repo root — the script
# resolves its own path).
#
# Usage:
#   ./run.sh setup   First-time setup: copies license, creates network, starts GraphDB
#   ./run.sh up      Start a previously set-up GraphDB container
#   ./run.sh down    Stop GraphDB (data is preserved)
#   ./run.sh purge   Remove container, image, network, and all data (irreversible)
#
# GraphDB Workbench: http://localhost:7200
# =============================================================================
set -euo pipefail

# ── Container runtime detection ──────────────────────────────────────────────
# Prefer podman; fall back to docker. Abort if neither is found.
if command -v podman &>/dev/null; then
    CONTAINER_CMD="podman"
    COMPOSE_CMD="podman compose"
    export PODMAN_COMPOSE_WARNING_LOGS=false
elif command -v docker &>/dev/null; then
    CONTAINER_CMD="docker"
    COMPOSE_CMD="docker compose"
else
    echo "ERROR: Neither podman nor docker found in PATH."
    exit 1
fi

# ── Configuration ────────────────────────────────────────────────────────────
VERSION="11.3.0"
export VERSION
LICENSE="GRAPHWISE_GRAPHDB.license"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
NETWORK="demo-network"

# ── Usage ────────────────────────────────────────────────────────────────────
usage() {
    echo "Usage: $(basename "$0") <command>"
    echo ""
    echo "Commands:"
    echo "  setup   First-time setup: copies license, creates network, starts GraphDB"
    echo "  up      Start a previously set-up GraphDB container"
    echo "  down    Stop GraphDB (data is preserved)"
    echo "  purge   Stop and remove container, image, network, and all data"
    echo ""
    echo "GraphDB version: ${VERSION}"
}

# ── Commands ─────────────────────────────────────────────────────────────────
cmd_setup() {
    if [ ! -f "$SCRIPT_DIR/$LICENSE" ]; then
        echo "ERROR: License file not found: $SCRIPT_DIR/$LICENSE"
        exit 1
    fi

    echo "Copying license..."
    mkdir -p ./graphdb-data/conf
    cp "$SCRIPT_DIR/$LICENSE" ./graphdb-data/conf/graphdb.license

    if $CONTAINER_CMD network exists "$NETWORK" 2>/dev/null; then
        echo "Network '${NETWORK}' already exists, skipping creation."
    else
        echo "Creating network '${NETWORK}'..."
        $CONTAINER_CMD network create "$NETWORK"
    fi

    echo "Starting GraphDB ${VERSION} (using ${CONTAINER_CMD})..."
    $COMPOSE_CMD up -d

    echo ""
    echo "GraphDB has been set up and started."
    echo "Open a browser to http://localhost:7200 to access the GraphDB Workbench."
}

cmd_up() {
    if [ ! -f "./graphdb-data/conf/graphdb.license" ]; then
        echo "ERROR: No license found in ./graphdb-data/conf/. Run './run.sh setup' first."
        exit 1
    fi

    echo "Starting GraphDB ${VERSION} (using ${CONTAINER_CMD})..."
    $COMPOSE_CMD up -d

    echo ""
    echo "GraphDB has been started."
    echo "Open a browser to http://localhost:7200 to access the GraphDB Workbench."
}

cmd_down() {
    echo "Stopping GraphDB..."
    $COMPOSE_CMD down

    echo ""
    echo "GraphDB has been stopped. Data is preserved in ./graphdb-data."
}

cmd_purge() {
    echo "WARNING: This will remove the GraphDB container, image, network, and all data in ./graphdb-data."
    read -r -p "Are you sure? [y/N] " confirm
    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
        echo "Purge cancelled."
        exit 0
    fi

    echo "Stopping and removing container..."
    $COMPOSE_CMD down 2>/dev/null || echo "Compose down failed (container or network may already be gone), continuing."

    echo "Removing image ontotext/graphdb:${VERSION}..."
    $CONTAINER_CMD rmi "ontotext/graphdb:${VERSION}" 2>/dev/null || echo "Image not found, skipping."

    echo "Removing network '${NETWORK}'..."
    $CONTAINER_CMD network rm "$NETWORK" 2>/dev/null || echo "Network '${NETWORK}' not found, skipping."

    echo "Removing data directory..."
    rm -rf ./graphdb-data

    echo ""
    echo "GraphDB container, image, network, and data have been purged."
}

# ── Dispatch ─────────────────────────────────────────────────────────────────
if [ $# -ne 1 ]; then
    usage
    exit 1
fi

case "$1" in
    setup) cmd_setup ;;
    up)    cmd_up    ;;
    down)  cmd_down  ;;
    purge) cmd_purge ;;
    *)
        echo "ERROR: Unknown command '$1'"
        echo ""
        usage
        exit 1
        ;;
esac
