#!/usr/bin/env bash
# =============================================================================
# generate.sh
# Author:  Kent Stroker
# Date:    2026-03-09
#
# Convenience script that runs both pipeline stages with default parameters:
#   Stage 1 — Generates a single-lineage family tree as RDF/Turtle via
#             FamilyTreeDataGeneratorV2.py
#   Stage 2 — Converts the TTL output to Neo4j Cypher (one file per sample)
#             and CSV (for LOAD CSV bulk import) via TTL2Cypher.py
#
# Usage:
#   source .venv/bin/activate    # activate the Python virtualenv first
#   ./generate.sh                # run from the repo root
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
OUT_DIR="out_graphdb"
GRAPHDB_IMPORT="sandboxes/graphdb/graphdb-import"
NEO4J_IMPORT="sandboxes/neo4j/import"
SEED=2
MIN_CHILDREN=2
MAX_CHILDREN=8
NUM_GENERATIONS=5

# ── Stage 0: Clean output directories ────────────────────────────────────────

echo ""
echo "Stage 0 — Clearing output directories..."

rm -rf "${OUT_DIR}"
mkdir -p "${OUT_DIR}/data"

mkdir -p "${GRAPHDB_IMPORT}" "${NEO4J_IMPORT}"
rm -f "${GRAPHDB_IMPORT}"/*
rm -f "${NEO4J_IMPORT}"/*

echo "  Cleared ${OUT_DIR}/, ${GRAPHDB_IMPORT}/, ${NEO4J_IMPORT}/"

# ── Stage 1: Generate TTL ────────────────────────────────────────────────────

echo ""
echo "Stage 1 — Generating single-lineage family tree TTL files..."
echo "  generations=${NUM_GENERATIONS}, children=${MIN_CHILDREN}–${MAX_CHILDREN}, seed=${SEED}"
echo ""

python3 main/FamilyTreeDataGeneratorV2.py \
  --out-dir        "${OUT_DIR}" \
  --seed           "${SEED}" \
  --min-children   "${MIN_CHILDREN}" \
  --max-children   "${MAX_CHILDREN}" \
  --num-generations "${NUM_GENERATIONS}" \
  --seventh-son

# ── Stage 2: Convert TTL → Cypher + CSV ──────────────────────────────────────

echo ""
echo "Stage 2 — Converting TTL to Neo4j Cypher and CSV..."
echo ""

python3 main/TTL2Cypher.py \
  --data-dir "${OUT_DIR}/data" \
  --out      "${OUT_DIR}" \
  --split \
  --csv

# ── Stage 3: Distribute files to container import directories ─────────────────

echo ""
echo "Stage 3 — Copying files to container import directories..."

# GraphDB: schema + rules + all TTL data files (base + lastgen)
cp "${OUT_DIR}/schema.ttl"          "${GRAPHDB_IMPORT}/"
cp "${OUT_DIR}/rules.ttl"           "${GRAPHDB_IMPORT}/"
cp "${OUT_DIR}/data"/*.ttl          "${GRAPHDB_IMPORT}/"
cp main/*-inlaws.ttl               "${GRAPHDB_IMPORT}/"
echo "  GraphDB : schema.ttl, rules.ttl, 000.ttl, 000-lastgen.ttl, *-inlaws.ttl → ${GRAPHDB_IMPORT}/"

# Neo4j: base CSV files
cp "${OUT_DIR}/persons.csv"    "${NEO4J_IMPORT}/"
cp "${OUT_DIR}/parent_of.csv"  "${NEO4J_IMPORT}/"
cp "${OUT_DIR}/married_to.csv" "${NEO4J_IMPORT}/"
echo "  Neo4j   : persons.csv, parent_of.csv, married_to.csv → ${NEO4J_IMPORT}/"

# Neo4j: incremental CSV files (if present)
if ls "${OUT_DIR}"/lastgen_*.csv 1>/dev/null 2>&1; then
    cp "${OUT_DIR}"/lastgen_*.csv "${NEO4J_IMPORT}/"
    echo "  Neo4j   : lastgen_persons.csv, lastgen_parent_of.csv, lastgen_married_to.csv → ${NEO4J_IMPORT}/"
fi

# ── Summary ───────────────────────────────────────────────────────────────────

echo ""
echo "Done."
echo "  Base TTL         : ${OUT_DIR}/data/000.ttl"
echo "  Incremental TTL  : ${OUT_DIR}/data/000-lastgen.ttl"
echo "  Base Cypher      : ${OUT_DIR}/data-000.cypher"
echo "  Incr Cypher      : ${OUT_DIR}/data-000-lastgen.cypher"
echo "  Base CSV         : ${OUT_DIR}/persons.csv, parent_of.csv, married_to.csv"
echo "  Incr CSV         : ${OUT_DIR}/lastgen_persons.csv, lastgen_parent_of.csv, lastgen_married_to.csv"
echo "  LOAD scripts     : ${OUT_DIR}/loadFromCSV.cypher, loadIncrementalCSV.cypher"
echo ""
echo "Next steps:"
echo "  Phase 1 (base data):"
echo "    GraphDB → Import → RDF → Server files: schema.ttl, then 000.ttl"
echo "              SPARQL Update: run 1-load_rules.sparql to activate inference"
echo "    Neo4j   → run loadFromCSV.cypher in Browser, then 3-materialize_rules.cypher"
echo ""
echo "  Phase 2 (incremental — last generation):"
echo "    GraphDB → Import → RDF → Server files: 000-lastgen.ttl"
echo "              (inference fires automatically on new data)"
echo "    Neo4j   → run loadIncrementalCSV.cypher, then re-run 3-materialize_rules.cypher"
echo ""
