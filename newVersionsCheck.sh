#!/usr/bin/env bash
# =============================================================================
# newVersionsCheck.sh
# Author:  Kent Stroker
# Date:    2026-03-09
#
# Checks the currently pinned container image versions (read from
# sandboxes/graphdb/run.sh and sandboxes/neo4j/run.sh) against Docker Hub and
# offers to update the VERSION strings in those files if newer releases are
# available.
#
# Usage:
#   ./newVersionsCheck.sh    # run from the repo root
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# ── Read pinned versions from run.sh files ────────────────────────────────────
pinned_graphdb=$(grep '^VERSION=' "$SCRIPT_DIR/sandboxes/graphdb/run.sh" | cut -d'"' -f2)
pinned_neo4j=$(grep   '^VERSION=' "$SCRIPT_DIR/sandboxes/neo4j/run.sh"   | cut -d'"' -f2)

echo ""
echo "Pinned versions:"
echo "  GraphDB  →  ontotext/graphdb:${pinned_graphdb}"
echo "  Neo4j    →  neo4j:${pinned_neo4j}"
echo ""

# ── Query Docker Hub for latest available versions ────────────────────────────
echo "Checking Docker Hub for latest available versions..."

# GraphDB: filter tags matching x.y.z (numeric semver only, skip -rc / -beta / etc.)
# Sort by semantic version (not last_updated) to avoid picking old-branch patch releases.
latest_graphdb=$(curl -sf \
  "https://hub.docker.com/v2/repositories/ontotext/graphdb/tags/?page_size=200&ordering=last_updated" \
  | python3 -c "
import sys, json, re
tags = json.load(sys.stdin).get('results', [])
versions = [t['name'] for t in tags if re.fullmatch(r'[0-9]+\.[0-9]+\.[0-9]+', t['name'])]
versions.sort(key=lambda v: tuple(int(x) for x in v.split('.')), reverse=True)
print(versions[0] if versions else '')
" 2>/dev/null) || latest_graphdb=""

# Neo4j: filter tags matching YYYY.MM.patch-enterprise or x.y.z-enterprise.
# Sort by version tuple so YYYY.MM.x releases rank above legacy 5.x releases.
latest_neo4j=$(curl -sf \
  "https://hub.docker.com/v2/repositories/library/neo4j/tags/?page_size=200&ordering=last_updated" \
  | python3 -c "
import sys, json, re
tags = json.load(sys.stdin).get('results', [])
versions = [t['name'] for t in tags if re.fullmatch(r'[0-9]+\.[0-9]+\.[0-9]+-enterprise', t['name'])]
def ver_key(v):
    return tuple(int(x) for x in v.replace('-enterprise', '').split('.'))
versions.sort(key=ver_key, reverse=True)
print(versions[0] if versions else '')
" 2>/dev/null) || latest_neo4j=""

# ── Compare and report ────────────────────────────────────────────────────────
graphdb_needs_update=false
neo4j_needs_update=false

if [[ -z "$latest_graphdb" ]]; then
    echo "  GraphDB  →  could not reach Docker Hub (check network)"
elif [[ "$latest_graphdb" == "$pinned_graphdb" ]]; then
    echo "  GraphDB  →  up to date (${pinned_graphdb})"
else
    echo "  GraphDB  →  newer version available: ${latest_graphdb}  (pinned: ${pinned_graphdb})"
    graphdb_needs_update=true
fi

if [[ -z "$latest_neo4j" ]]; then
    echo "  Neo4j    →  could not reach Docker Hub (check network)"
elif [[ "$latest_neo4j" == "$pinned_neo4j" ]]; then
    echo "  Neo4j    →  up to date (${pinned_neo4j})"
else
    echo "  Neo4j    →  newer version available: ${latest_neo4j}  (pinned: ${pinned_neo4j})"
    neo4j_needs_update=true
fi

echo ""

# ── Offer to update run.sh files ──────────────────────────────────────────────
if [[ "$graphdb_needs_update" == false && "$neo4j_needs_update" == false ]]; then
    echo "All pinned versions are current. Nothing to update."
    echo ""
    exit 0
fi

if [[ "$graphdb_needs_update" == true ]]; then
    read -r -p "Update sandboxes/graphdb/run.sh to ${latest_graphdb}? [y/N] " confirm
    if [[ "$confirm" =~ ^[Yy]$ ]]; then
        sed -i '' "s/^VERSION=\"${pinned_graphdb}\"/VERSION=\"${latest_graphdb}\"/" \
            "$SCRIPT_DIR/sandboxes/graphdb/run.sh"
        echo "  sandboxes/graphdb/run.sh updated to ${latest_graphdb}"
        echo "  NOTE: run './run.sh purge' then './run.sh setup' to pull the new image."
    else
        echo "  sandboxes/graphdb/run.sh left unchanged."
    fi
    echo ""
fi

if [[ "$neo4j_needs_update" == true ]]; then
    read -r -p "Update sandboxes/neo4j/run.sh to ${latest_neo4j}? [y/N] " confirm
    if [[ "$confirm" =~ ^[Yy]$ ]]; then
        sed -i '' "s/^VERSION=\"${pinned_neo4j}\"/VERSION=\"${latest_neo4j}\"/" \
            "$SCRIPT_DIR/sandboxes/neo4j/run.sh"
        echo "  sandboxes/neo4j/run.sh updated to ${latest_neo4j}"
        echo "  NOTE: run './run.sh purge' then './run.sh setup' to pull the new image."
    else
        echo "  sandboxes/neo4j/run.sh left unchanged."
    fi
    echo ""
fi
