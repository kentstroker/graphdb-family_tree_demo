# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Setup

All Python scripts require the virtualenv:

```bash
source .venv/bin/activate
```

Dependencies: `faker` (name generation). No other third-party libraries are used by the pipeline scripts.

## Pipeline

Pre-built output already exists in `out_graphdb/` — regeneration is optional. To regenerate everything and distribute to container import directories in one step:

```bash
./generate.sh
```

This runs four stages:
0. Cleans `out_graphdb/`, `sandboxes/graphdb/graphdb-import/`, and `sandboxes/neo4j/import/`
1. Generates TTL via `FamilyTreeDataGeneratorV2.py`
2. Converts to Cypher + CSV via `TTL2Cypher.py --split --csv`
3. Copies files to container import directories (`sandboxes/graphdb/graphdb-import/` and `sandboxes/neo4j/import/`), including in-law schema/rules files for GraphDB

Output in `out_graphdb/`: `data/000.ttl`, `data/000-lastgen.ttl`, `data-000.cypher`, `data-000-lastgen.cypher`, `persons.csv`, `parent_of.csv`, `married_to.csv`, `lastgen_*.csv`, `loadFromCSV.cypher`, `loadIncrementalCSV.cypher`, plus copies of `schema.ttl` and `rules.ttl`.

To run the stages individually:

```bash
python3 main/FamilyTreeDataGeneratorV2.py \
  --out-dir out_graphdb --seed 2 \
  --min-children 2 --max-children 8 --num-generations 5 \
  --seventh-son

python3 main/TTL2Cypher.py \
  --data-dir out_graphdb/data --out out_graphdb --split --csv
```

## Containers

Both databases use **podman** / `podman compose` and share a `demo-network` network. Run from the respective subdirectory.

```bash
cd sandboxes/graphdb   # or: cd sandboxes/neo4j
./run.sh setup   # first-time only: copies license (GraphDB), creates network, starts container
./run.sh up      # start a previously set-up container
./run.sh down    # stop, preserve data
./run.sh purge   # destructive: removes container, image, network, and all data
```

- **GraphDB**: `http://localhost:7200` — requires a `GRAPHWISE_GRAPHDB_FREE_vX.Y.license` file in `sandboxes/graphdb/` matching the version in `sandboxes/graphdb/run.sh` (excluded from git via `.gitignore`; obtain free from graphwise.ai)
- **Neo4j**: `http://localhost:7474` (Browser), bolt `localhost:7687`, credentials `neo4j/neo4jadmin`

### Loading data into Neo4j

> If you ran `generate.sh`, CSV files are already in `sandboxes/neo4j/import/` — skip the copy step.

**Option A — LOAD CSV (fast, recommended):**
Paste and run `out_graphdb/loadFromCSV.cypher` in the Neo4j Browser. (CSV files must be in `sandboxes/neo4j/import/`; `generate.sh` does this automatically.)

**Option B — Browser paste:**
Run `out_graphdb/data-000.cypher` in the Neo4j Browser.

After loading base data, run `main/queries/neo4j-materialize_rules.cypher` to materialize all derived kinship edge types.

### Loading data into GraphDB

> If you ran `generate.sh`, files are already in `sandboxes/graphdb/graphdb-import/` — skip the copy step.

1. Create a repository with the `kinship.pie` custom ruleset (this embeds the inference rules — no separate rule-loading step needed)
2. Import via Workbench **Import → RDF → Server files** in this order:
   - `schema.ttl`
   - `000.ttl`

Inference fires automatically on import. Run `main/queries/ex0-implicitRelationships.sparql` to verify — all derived relationship counts should be non-zero.

### Switching rulesets (GraphDB)

The base ruleset (`main/kinship.pie`) covers kinship without in-laws. To add in-law inference:

```bash
./switch-ruleset.sh   # interactively switch between base and full (incl. in-laws) rulesets
```

Or manually via the utility SPARQL queries:
- `main/queries/util-defaultRuleset.sparql` — switch to base kinship ruleset
- `main/queries/util-addRuleset.sparql` — load an additional ruleset (e.g. in-laws)
- `main/queries/util-reinfer.sparql` — force re-inference after ruleset change

## Architecture

### Core Concept

The demo stores only two base relationships: `ex:parentOf` and `ex:marriedTo`. From these, 47 derived kinship relationships are produced (49 total including the 2 base types) — via SHACL inference in GraphDB, and via explicit Cypher statements in Neo4j. The contrast is in *how*: GraphDB's reasoning engine derives relationships automatically when `rules.ttl` is loaded; Neo4j requires 50+ imperative Cypher statements run in strict dependency order.

An optional in-laws extension (`rules-inlaws.ttl`, `schema-inlaws.ttl`) adds 6 more relationship types (fatherInLawOf, motherInLawOf, sonInLawOf, daughterInLawOf, brotherInLawOf, sisterInLawOf).

### Data Model

- Base IRI: `http://example.org/family/`
- Person IRIs: `ex:person/0-{local_id}` (prefix `0` is the sample index, always 0 for single-tree generation)
- Gender: encoded as RDF class membership (`rdf:type ex:female` / `ex:male`); as a boolean property `female` in Neo4j
- `ex:dateOfBirth` / `ex:dateOfDeath`: `xsd:date` typed literals on every person. Births are generation-anchored (~22-year spans); deaths are age-probability-based. Absent `dateOfDeath` means the person is still living — enables "show living grandparents" queries.
- `ex:marriedTo` is written one direction only; symmetry is inferred (GraphDB) or both directions are created (Neo4j)
- The founding patriarch is **Anthony Blanchard** (person/0-0) with seed 2.

### FamilyTreeDataGeneratorV2.py

Builds a single-lineage family tree (pure DAG) from one founding couple:
- **Gen 0**: one founding couple with 2–8 children
- **Gen 1 … N-2**: every child marries a unique outside spouse (leaf node, no parents). Children inherit the father's surname. Couples at gen >= 3 have a 5% chance of being childless.
- **Gen N-1**: last generation — married but no children (leaf tier for incremental loading demo)
- `--seventh-son` flag guarantees one "7th son of a 7th son" by forcing ≥ 7 male children in the founding family and the 7th son's family. Children's DOBs within each family are sorted to match creation order, ensuring the 7th child by index is also 7th by birth date.
- `UniqueSurnameSource` ensures every incoming spouse has a globally unique surname (falls back to numeric suffix when Faker's pool is exhausted)
- `UniqueNameSource` retries up to 500 times from Faker before falling back to numeric-suffix given names
- Output is split into base file (`000.ttl`, gens 0–N-2) and incremental file (`000-lastgen.ttl`, gen N-1)

### TTL2Cypher.py

A hand-rolled regex parser — no RDF library — tightly coupled to the exact output format of `FamilyTreeDataGeneratorV2.py`. Emits idempotent `MERGE`-based Cypher. Do not use this parser against arbitrary TTL files.

### Kinship Rules (`main/rules.ttl`, `main/queries/neo4j-materialize_rules.cypher`)

Derivation chain (each tier depends on the previous):
```
parentOf → childOf, grandparentOf, siblingOf
  → greatGrandparentOf, grandchildOf, auntUncleOf, greatAuntUncleOf
    → greatGrandchildOf, nieceNephewOf, secondAuntUncleOf, cousinOf
      → secondCousinOf, firstCousinOnceRemovedOf
        + gender class → all gendered variants (motherOf, auntOf, cousinOf variants, etc.)
        + marriedTo + gender → 6 in-law designations (fatherInLawOf, motherInLawOf, etc.)
```

Rules are derived from `ontology.asp` by Patrick Hohenecker (2-Clause BSD), translated from ASP to SHACL SPARQLRules. Attribution is in the file headers.

### Container Version Management

`newVersionsCheck.sh` (repo root) checks pinned versions in `sandboxes/graphdb/run.sh` and `sandboxes/neo4j/run.sh` against Docker Hub and interactively offers to update them. Uses `sed -i ''` — macOS only; Linux requires dropping the empty string argument. After updating a version, the container must be purged and re-set-up to pull the new image.

### Directory Layout

Active queries are in `main/queries/` organized by exercise number; fun/advanced queries are in `main/queries/funstuff/`.

### Key Files for Reference

| File | Purpose |
|---|---|
| `main/queries/neo4j-materialize_rules.cypher` | Neo4j kinship materialization — ordered tiers + gendered variants |
| `main/queries/neo4j-materialize_new_rules.cypher` | Neo4j in-law materialization |
| `main/queries/ex0-explicitRelationships.sparql` / `.cypher` | Counts explicit relationship types (should show 2: parentOf, marriedTo) |
| `main/queries/ex0-implicitRelationships.sparql` | Counts inferred relationship types (47 derived kinship types) |
| `main/queries/ex1-descendantLineage.sparql` / `.cypher` | Tabular lineage from Anthony Blanchard with inferred kinship labels |
| `main/queries/ex1-schemaQuery.sparql` / `.cypher` | Display schema/vocabulary triples |
| `main/queries/ex2-lastGenKinship.sparql` / `.cypher` | Last-gen kinship — shows inference after incremental data load |
| `main/queries/ex3-showInLaws.sparql` / `.cypher` | All 6 in-law relationship types |
| `main/queries/ex3-husbandsAndMotherInLaws.sparql` / `.cypher` | Husbands and their mothers-in-law |
| `main/queries/funstuff/patrilinealSurname.sparql` | Patrilineal surname tracing |
| `main/queries/funstuff/seventhSonOfSeventhSon.sparql` / `.cypher` | Seventh son of a seventh son query |
| `main/queries/util-defaultRuleset.sparql` | Switch to base kinship ruleset |
| `main/queries/util-addRuleset.sparql` | Load additional ruleset (e.g. in-laws) |
| `main/queries/util-reinfer.sparql` | Force re-inference of all rules |
| `main/queries/util-show-explicits.sparql` | Show only explicitly asserted triples |
| `main/queries/util-show-implicits.sparql` | Show only inferred triples |
| `generate.sh` | Full pipeline: clean → generate → convert → distribute to container import dirs |
| `switch-ruleset.sh` | Switch between base and full (incl. in-laws) GraphDB rulesets |
| `newVersionsCheck.sh` | Checks pinned container versions against Docker Hub; macOS only (`sed -i ''`) |
| `main/rules-inlaws.ttl` | SHACL rules for in-law inference (extends base rules) |
| `main/schema-inlaws.ttl` | OWL schema for in-law relationship types |
| `KINSHIP.md` | Full kinship vocabulary reference with derivation chain diagram |
| `KINSHIP-LPG.md` | Step-by-step explanation of the Neo4j materialization approach |
| `TODO.md` | Planned enhancements, especially LLM/agent integration |