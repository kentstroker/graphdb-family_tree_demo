#!/usr/bin/env bash
# =============================================================================
# run.sh  (sandboxes/neo4j/)
# Author:  Kent Stroker
# Date:    2026-03-09
#
# Container lifecycle management for the Neo4j instance used in this demo.
# Wraps podman or docker with a simple command interface (auto-detected).
# Must be run from the neo4j/ subdirectory (or the repo root — the script
# resolves its own path).
#
# Usage:
#   ./run.sh setup   First-time setup: creates network, starts Neo4j
#   ./run.sh up      Start a previously set-up Neo4j container
#   ./run.sh down    Stop Neo4j (data is preserved)
#   ./run.sh purge   Remove container, image, network, and all data (irreversible)
#
# Neo4j Browser: http://localhost:7474   credentials: neo4j / neo4jadmin
# Neo4j Bolt:    bolt://localhost:7687
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
VERSION="2026.02.2-enterprise"
export VERSION
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
NETWORK="demo-network"

# ── Usage ────────────────────────────────────────────────────────────────────
usage() {
    echo "Usage: $(basename "$0") <command>"
    echo ""
    echo "Commands:"
    echo "  setup   First-time setup: copies license, creates network, starts Neo4j"
    echo "  up      Start a previously set-up Neo4j container"
    echo "  down    Stop Neo4j (data is preserved)"
    echo "  purge   Stop and remove container, image, network, and all data"
    echo ""
    echo "Neo4j version: ${VERSION}"
}

# ── Commands ─────────────────────────────────────────────────────────────────
cmd_setup() {
    if $CONTAINER_CMD network exists "$NETWORK" 2>/dev/null; then
        echo "Network '${NETWORK}' already exists, skipping creation."
    else
        echo "Creating network '${NETWORK}'..."
        $CONTAINER_CMD network create "$NETWORK"
    fi

    echo "Starting Neo4j ${VERSION} (using ${CONTAINER_CMD})..."
    $COMPOSE_CMD up -d

    echo ""
    echo "Neo4j has been set up and started."
    echo "Open a browser to http://localhost:7474 to access the Neo4j console."
}

cmd_up() {
    echo "Starting Neo4j ${VERSION} (using ${CONTAINER_CMD})..."
    $COMPOSE_CMD up -d

    echo ""
    echo "Neo4j has been started."
    echo "Open a browser to http://localhost:7474 to access the Neo4j console."
}

cmd_down() {
    echo "Stopping Neo4j..."
    $COMPOSE_CMD down

    echo ""
    echo "Neo4j has been stopped. Data is preserved in ./data."
}

cmd_purge() {
    echo "WARNING: This will remove the Neo4j container, image, network, and all data in ./data."
    read -r -p "Are you sure? [y/N] " confirm
    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
        echo "Purge cancelled."
        exit 0
    fi

    echo "Stopping and removing container..."
    $COMPOSE_CMD down 2>/dev/null || echo "Compose down failed (container or network may already be gone), continuing."

    echo "Removing image neo4j:${VERSION}..."
    $CONTAINER_CMD rmi "neo4j:${VERSION}" 2>/dev/null || echo "Image not found, skipping."

    echo "Removing network '${NETWORK}'..."
    $CONTAINER_CMD network rm "$NETWORK" 2>/dev/null || echo "Network '${NETWORK}' not found, skipping."

    echo "Removing data directory..."
    rm -rf ./data

    echo ""
    echo "Neo4j container, image, network, and data have been purged."
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
