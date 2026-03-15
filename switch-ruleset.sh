#!/usr/bin/env bash
# =============================================================================
# switch-ruleset.sh
# Author:  Kent Stroker
# Date:    2026-03-14
#
# Copies kinship-full.pie into the GraphDB repository directory.
# After running this script, execute the SPARQL updates in
# main/queries/ex3-activateInLaws.sparql to activate the ruleset and reinfer.
#
# Usage:
#   ./switch-ruleset.sh
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_DIR="$SCRIPT_DIR/sandboxes/graphdb/graphdb-data/data/repositories/family-tree"
SOURCE="$SCRIPT_DIR/main/kinship-full.pie"

# ── Validate paths ──────────────────────────────────────────────────────────
if [ ! -f "$SOURCE" ]; then
    echo "ERROR: Source file not found: $SOURCE"
    exit 1
fi

if [ ! -d "$REPO_DIR" ]; then
    echo "ERROR: Repository directory not found: $REPO_DIR"
    echo "Has GraphDB been set up? Run: cd sandboxes/graphdb && ./run.sh setup"
    exit 1
fi

# ── Copy .pie file ──────────────────────────────────────────────────────────
echo "Copying kinship-full.pie → $REPO_DIR/"
cp "$SOURCE" "$REPO_DIR/kinship-full.pie"

echo ""
echo "Done. Next steps:"
echo "  1. Import schema-inlaws.ttl via GraphDB Workbench (Import → RDF → Server files)"
echo "  2. Run main/queries/ex2-activateInLaws.sparql in the SPARQL tab (SPARQL Update mode)"
