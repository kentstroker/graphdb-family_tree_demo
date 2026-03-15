# Family Tree Demo: RDF (GraphDB) vs. LPG (Neo4j)

A hands-on demonstration that compares two fundamentally different approaches to representing and querying knowledge in a graph database — **ontology-driven inference** in GraphDB versus **explicit materialization** in Neo4j — using a synthetic multi-generation family tree as the shared dataset.

---

## What This Demo Does

At its heart, this demo asks a simple question: *if you only store the bare minimum facts about a family, how much can a database figure out on its own?*

The dataset captures just two kinds of relationships:
- **Parent → Child** links
- **Spouse** links

That's it. No siblings. No cousins. No grandparents. No aunts and uncles. Just those two raw edges, plus each person's name and gender.

From those minimal facts, the demo shows two databases arriving at the **same rich set of kinship relationships** — but getting there in very different ways.

### GraphDB (Ontotext) — Inference Engine

GraphDB is a semantic graph database built on RDF and OWL standards. It includes a **reasoning engine** that can apply logical rules to infer new facts automatically. In this demo, a set of SHACL SPARQLRules (stored in `rules.ttl`) defines the complete kinship vocabulary as logical axioms:

> "X is a sibling of Y if they share a parent."
> "X is an aunt of Y if X is a sister of Y's parent."
> "X is a cousin of Y if X's parent is an aunt or uncle of Y."

You load your data, trigger the reasoning engine, and every derived relationship — siblings, grandparents, great-grandparents, cousins, second cousins, first cousins once removed, nieces, nephews, great-aunts, great-uncles, and all their gendered variants — **appears automatically**. You don't write the logic to compute them; you declare what they mean, and GraphDB does the rest.

### Neo4j — Labeled Property Graph (LPG)

Neo4j is a highly popular property graph database that uses the Cypher query language. It is fast, expressive, and excellent for traversal queries — but it has no built-in reasoning engine. It stores exactly what you put in, and nothing more.

To get the same set of kinship relationships in Neo4j, the demo provides `neo4j-materialize_rules.cypher`: a script of approximately 50 Cypher statements that manually traverse the graph in strict dependency order to compute and store every relationship tier by tier:

1. Compute `CHILD_OF`, `GRANDPARENT_OF`, `SIBLING_OF` from raw `PARENT_OF` edges
2. Compute `AUNT_UNCLE_OF`, `NIECE_NEPHEW_OF`, `COUSIN_OF` from those
3. Compute `SECOND_COUSIN_OF`, `FIRST_COUSIN_ONCE_REMOVED_OF` from those
4. Apply gender to produce `MOTHER_OF`, `FATHER_OF`, `AUNT_OF`, `UNCLE_OF`, etc.

Every step must be run manually. If you add new people later, you must run the script again. If you run the steps out of order, you get wrong or missing results. The logic lives in application code, not in the database.

### The Punchline

Both systems end up with the same answers. But GraphDB gets there by **understanding the domain** — the rules are part of the knowledge graph itself. Neo4j gets there by **brute-force computation** — a developer encoded every inference step by hand.

---

## What You Will Learn

By working through this demo yourself, you will come away with a solid intuition for:

- **Why ontologies matter.** An ontology isn't just documentation. When paired with a reasoning engine, it actively produces new knowledge. This demo makes that concrete and observable.

- **The difference between a knowledge graph and a property graph.** Both are "graph databases," but they solve fundamentally different problems. You'll see the tradeoffs firsthand.

- **How SHACL rules work.** The `rules.ttl` file is heavily annotated. Reading it alongside the GraphDB Workbench is an excellent introduction to SHACL SPARQLRules.

- **Why inference is powerful for evolving data.** Add a new family to GraphDB and all their kinship relationships materialize automatically. Add a new family to Neo4j and you have to re-run a 50-statement script — and hope you remembered.

- **The maintenance cost of brute-force approaches.** Looking at `neo4j-materialize_rules.cypher` is instructive. It works. But it's also a maintenance liability: every new relationship type multiplies the number of statements you have to write and keep synchronized.

- **How to query both systems.** The demo includes ready-to-run query pairs in `main/queries/` — SPARQL files for GraphDB with matching Cypher equivalents (`.cypher`) for Neo4j, organized by exercise number (`ex0-` through `ex3-`).

---

## Prerequisites

### Python (for data generation)

You need Python3 with a virtual environment, the author uses Jetbrains PyCharm for most of his work. The generator uses the `faker` library to produce realistic names.

```bash
python3 -m venv .venv
source .venv/bin/activate
pip install faker
```

### Container Runtime — Podman (preferred) or Docker

To check which container image versions are pinned in this repo and whether newer ones are available on Docker Hub, run:

```bash
./newVersionsCheck.sh
```

The script reads the pinned versions from each `run.sh`, queries Docker Hub for the latest available tags, and — if a newer version exists — interactively asks whether you want to update the `run.sh` file in place. If you accept an update, the script also reminds you to run `./run.sh purge` followed by `./run.sh setup` to pull the new image.

> **macOS only:** `newVersionsCheck.sh` uses `sed -i ''` syntax, which is macOS-specific. On Linux, edit the script and remove the empty string argument: `sed -i "s/..."`.

Both databases run in containers. **Podman is the preferred runtime** for this demo — the `run.sh` scripts in each subdirectory call `podman` and `podman compose` directly. Podman is a daemonless, rootless alternative to Docker that is increasingly the default on Linux and is available on macOS via Homebrew.

If you only have Docker installed, you can still run the demo: the `docker-compose.yaml` files are standard and compatible. You will just need to substitute `docker` for `podman` in the commands, or alias `podman` to `docker` in your shell.

**To install Podman on macOS:**
```bash
brew install podman podman-compose
podman machine init
podman machine start
```

**To install Podman on Linux (Debian/Ubuntu):**
```bash
sudo apt-get install podman podman-compose
```

### GraphDB License

GraphDB Free requires a license file. You can obtain one at no cost from Ontotext:

> https://www.ontotext.com/products/graphdb/graphdb-free/

Place the downloaded binary license file (`GRAPHWISE_GRAPHDB_FREE_v11.3.license`) in the `sandboxes/graphdb/` directory before running setup. The `run.sh setup` command will copy it into the container's data volume automatically.

Neo4j does not require a license for this demo (the compose file sets `NEO4J_ACCEPT_LICENSE_AGREEMENT=yes` for the enterprise image, which allows evaluation use).

---

## Repository Structure

```
family-tree-demo/
├── README.md                        # This file — full walkthrough and reference
├── GRAPHWISE.md                     # Background on the Graphwise/Ontotext merger
├── KINSHIP.md                       # Reference: the full kinship vocabulary and derivation chain
├── KINSHIP-LPG.md                   # Deep dive: how kinship is materialized in Neo4j (LPG approach)
├── TODO.md                          # Planned enhancements, especially LLM/agent integration
├── generate.sh                      # Convenience script: runs both pipeline stages with defaults
├── newVersionsCheck.sh              # Checks/updates pinned container image versions
├── switch-ruleset.sh                # Switch between base and full (incl. in-laws) rulesets
├── ontology.asp                     # Original ASP ontology by Patrick Hohenecker (source of rules)
├── out_graphdb/                     # Pre-staged data — ready to load, no generation needed
│   ├── data/
│   │   ├── 000.ttl                  # Base family tree (gens 0–3)
│   │   └── 000-lastgen.ttl          # Incremental last generation (gen 4)
│   ├── data-000.cypher              # Neo4j Cypher for base data
│   ├── data-000-lastgen.cypher      # Neo4j Cypher for incremental data
│   ├── persons.csv                  # Base persons — bulk load via LOAD CSV
│   ├── parent_of.csv                # Base PARENT_OF edges
│   ├── married_to.csv               # Base MARRIED_TO edges
│   ├── lastgen_persons.csv          # Incremental persons
│   ├── lastgen_parent_of.csv        # Incremental PARENT_OF edges
│   ├── lastgen_married_to.csv       # Incremental MARRIED_TO edges
│   ├── loadFromCSV.cypher           # Neo4j LOAD CSV script (base data)
│   ├── loadIncrementalCSV.cypher    # Neo4j LOAD CSV script (incremental)
│   ├── schema.ttl                   # Copy of the OWL ontology
│   └── rules.ttl                    # Copy of the SHACL inference rules
├── main/
│   ├── FamilyTreeDataGeneratorV2.py     # Generates single-lineage family tree as TTL
│   ├── TTL2Cypher.py                    # Converts TTL output to Neo4j Cypher
│   ├── schema.ttl                       # OWL ontology (commented)
│   ├── schema-inlaws.ttl                # OWL schema for in-law relationship types
│   ├── rules.ttl                        # SHACL SPARQLRules (commented)
│   ├── rules-inlaws.ttl                 # SHACL rules for in-law inference
│   ├── kinship.pie                      # GraphDB custom ruleset (base kinship)
│   ├── kinship-full.pie                 # GraphDB custom ruleset (incl. in-laws)
│   ├── kinship-inlaws.pie              # GraphDB custom ruleset (in-laws only)
│   │
│   └── queries/                         # Active queries organized by exercise
│       ├── ex0-explicitRelationships.*  # Count explicit relationship types
│       ├── ex0-implicitRelationships.sparql  # Count inferred relationship types
│       ├── ex1-descendantLineage.*      # Tabular lineage with inferred kinship labels
│       ├── ex1-schemaQuery.*            # Display schema/vocabulary triples
│       ├── ex2-lastGenKinship.*         # Last-gen kinship after incremental load
│       ├── ex3-showInLaws.*             # All 6 in-law relationship types
│       ├── ex3-husbandsAndMotherInLaws.*  # Husbands and mothers-in-law
│       ├── neo4j-materialize_rules.cypher   # Neo4j kinship materialization
│       ├── neo4j-materialize_new_rules.cypher  # Neo4j in-law materialization
│       ├── util-*.sparql                # GraphDB utility queries (ruleset switching, re-inference)
│       └── funstuff/                    # Fun/advanced queries
│           ├── patrilinealSurname.sparql
│           └── seventhSonOfSeventhSon.*
├── sandboxes/
│   ├── graphdb/
│   │   ├── run.sh                       # Container lifecycle management
│   │   ├── docker-compose.yaml
│   │   └── graphdb-import/              # Copy TTL files here before running setup
│   └── neo4j/
│       ├── run.sh                       # Container lifecycle management
│       └── docker-compose.yaml
```

### Companion Documents

The repository includes several standalone markdown files intended as reading material alongside the hands-on exercise:

| File | Purpose |
|---|---|
| `GRAPHWISE.md` | Explains the October 2024 merger of Ontotext and Semantic Web Company into Graphwise — useful context for understanding who makes GraphDB, why the license file carries the Graphwise name, and where the product is headed with AI and GraphRAG. |
| `KINSHIP.md` | A complete reference for the kinship relationship vocabulary used in the demo. Covers every relationship type, its plain-English definition, the derivation chain from `parentOf` to all 49 relationship types, and the logic behind gendered specializations. Read this if you want to deeply understand what the SHACL rules and Cypher script are computing. |
| `KINSHIP-LPG.md` | A step-by-step walkthrough of the Neo4j materialization approach. Each of the 10 computation steps is explained with its Cypher, the reasoning behind it, and callouts on important LPG-specific considerations (execution ordering, symmetric relationships, materialization vs. query-time computation). Closes with a comparison of when to choose LPG vs. RDF/OWL. |

---

## Step-by-Step Walkthrough

### Step 1 — Generate the synthetic dataset *(optional — pre-built data is included)*

> **You can skip this step entirely.** The repository already includes ready-to-use generated data in `out_graphdb/`:
> - `out_graphdb/data/000.ttl` — base family tree (gens 0–3, ~480 people)
> - `out_graphdb/data/000-lastgen.ttl` — incremental last generation (gen 4, ~1,880 people)
> - `out_graphdb/data-000.cypher`, `data-000-lastgen.cypher` — Neo4j Cypher equivalents
> - `out_graphdb/persons.csv`, `parent_of.csv`, `married_to.csv` + `loadFromCSV.cypher` — base bulk loading
> - `out_graphdb/lastgen_*.csv` + `loadIncrementalCSV.cypher` — incremental bulk loading
> - `out_graphdb/schema.ttl` — OWL ontology
> - `out_graphdb/rules.ttl` — SHACL inference rules
>
> Jump straight to **Step 2** if you just want to get the databases running. Come back here when you want to explore larger datasets or different family structures.

---

If you want to generate fresh data — or experiment with different sizes and shapes — activate the virtual environment and run the generator:

```bash
source .venv/bin/activate

python3 main/FamilyTreeDataGeneratorV2.py \
  --out-dir out_graphdb \
  --seed 2 \
  --min-children 2 \
  --max-children 8 \
  --num-generations 5 \
  --seventh-son
```

#### Generator options explained

| Option | Default | Description |
|---|---|---|
| `--out-dir` | `out_graphdb` | Output directory for all generated files |
| `--seed` | `1` | Random seed — change this to produce a completely different family with different names and structure, fully reproducibly |
| `--min-children` | `2` | Minimum number of children per couple |
| `--max-children` | `8` | Maximum number of children per couple |
| `--num-generations` | `5` | Total generational tiers (Gen 0 = founding couple, Gen N-1 = leaf generation married but childless) |
| `--childless-from-gen` | `3` | Generation from which couples may be childless |
| `--childless-prob` | `0.05` | Probability (5%) a couple is childless from the above generation onward |
| `--seventh-son` | *(off)* | Guarantee one "7th son of a 7th son" in the tree |
| `--faker-locale` | *(English)* | Locale for name generation, e.g. `de_DE` for German names, `ja_JP` for Japanese names |

The generator produces a single-lineage family tree (pure DAG) from one founding couple. Every child marries a unique outside spouse (a leaf node with no parents). Output is split into a base file (`000.ttl`, gens 0–N-2) and an incremental file (`000-lastgen.ttl`, gen N-1) to demonstrate inference on new data.

Then generate the Neo4j Cypher and CSV equivalents from the TTL data:

```bash
python3 main/TTL2Cypher.py \
  --data-dir out_graphdb/data \
  --out      out_graphdb \
  --split \
  --csv
```

Or use `generate.sh` which runs all stages (generate, convert, distribute to container import dirs) with these defaults.

Both representations describe **identical people and relationships**. The difference is only in format and target database.

### Step 2 — Start the containers

Both containers share a Podman network called `demo-network`. Start GraphDB first (it creates the network during setup):

```bash
cd sandboxes/graphdb
./run.sh setup    # First time only — copies license, creates network, starts container
# ./run.sh up     # Subsequent starts after initial setup
```

Then start Neo4j in a separate terminal:

```bash
cd sandboxes/neo4j
./run.sh setup    # First time only
# ./run.sh up     # Subsequent starts
```

Give each container 30–60 seconds to fully initialize before proceeding.

| Database | URL | Credentials |
|---|---|---|
| GraphDB Workbench | http://localhost:7200 | (none required) |
| Neo4j Browser | http://localhost:7474 | `neo4j` / `neo4jadmin` |
| Neo4j Bolt | bolt://localhost:7687 | `neo4j` / `neo4jadmin` |

### Step 3 — Load data

#### GraphDB

1. If you ran `generate.sh`, the data files are already in `sandboxes/graphdb/graphdb-import/`. Otherwise, copy them manually:
   ```bash
   cp out_graphdb/data/0*.ttl sandboxes/graphdb/graphdb-import/
   cp main/schema.ttl sandboxes/graphdb/graphdb-import/
   ```

2. Open the GraphDB Workbench at http://localhost:7200

3. Create a new repository: **Setup → Repositories → Create new repository**. Name it e.g. `family-tree`, select RDFS (Optimized), click **Custom Ruleset** and select the `kinship.pie` file from `main/`, click **Create**. This embeds the inference rules directly into the repository — no separate rule-loading step is needed.

4. Make it the active repository: use the repository selector in the top-right corner of the Workbench to select `family-tree`.

5. Navigate to **Import → RDF → Server files**. Import in this order (order matters):
   - `schema.ttl` — ontology must load first
   - `000.ttl` — the base family tree data

6. Verify the load by running these queries in the SPARQL tab (SELECT mode):
   - Run `ex0-explicitRelationships.sparql` — shows only 2 relationship types (`parentOf`, `marriedTo`)
   - Run `ex0-implicitRelationships.sparql` — shows 47 inferred relationship types, automatically derived by the `.pie` ruleset on import

> **Do not import `000-lastgen.ttl` yet** — the incremental data load is part of Exercise #2 below.

#### Neo4j

1. If you ran `generate.sh`, the CSV files are already in `sandboxes/neo4j/import/`. Open the Neo4j Browser at http://localhost:7474, log in with `neo4j` / `neo4jadmin`, paste the contents of `out_graphdb/loadFromCSV.cypher`, and run it. This bulk-loads all persons and relationships in a single batched transaction.

   *(Alternative: paste and run `out_graphdb/data-000.cypher` directly. All statements use `MERGE` so they are safe to re-run.)*

2. Verify the load: run `ex0-explicitRelationships.cypher` — shows only 2 relationship types. Same raw data as GraphDB.

> **Do not run `neo4j-materialize_rules.cypher` yet** — that happens as part of Exercise #1 below.

> **First observation**: GraphDB already knows 49 relationship types from 2 asserted facts. Neo4j knows only the 2 that were explicitly loaded.

---

## Run the Demonstration

Both databases are now loaded with base data — `PARENT_OF` and `MARRIED_TO` edges. GraphDB's `.pie` ruleset is already active, so inference has already fired on the imported data. Neo4j has only raw edges — no derived relationships exist yet. The demonstration follows three exercises.

---

### Exercise #1 — Out-of-the-Box Inference

**In GraphDB** (SPARQL tab, SELECT mode):
1. Run `ex1-schemaQuery.sparql` — shows the schema/vocabulary triples
2. Run `ex1-descendantLineage.sparql` — the Relationship column shows `fatherOf`, `grandfatherOf`, `greatGrandfatherOf` for each descendant. These were inferred automatically.

**In Neo4j Browser**:
1. Run `ex1-schemaQuery.cypher` — same schema view
2. Run `ex1-descendantLineage.cypher` — same rows exist (PARENT_OF edges are there) but the Relationship column is **empty**. Neo4j has no idea Anthony Blanchard is a grandfather — only that he is a parent of a parent.
3. Paste and run `main/queries/neo4j-materialize_rules.cypher` — a ~290-line Cypher script of individually ordered `MERGE` statements, each tier depending on the previous. Watch it run. This is the brute-force approach in full view.
4. Re-run `ex1-descendantLineage.cypher` — the Relationship column is now populated. Both databases match.

> **Observation**: same answers, fundamentally different architectures. GraphDB derived everything from logical rules loaded once; Neo4j required a developer to script every inference step by hand in the correct order.

---

### Exercise #2 — Add New Data (latest generation)

You will add the last generation (previously withheld) and watch the two systems diverge.

**GraphDB**:
1. Import `000-lastgen.ttl` via **Import → RDF → Server files**. No SPARQL update needed — the rules already embedded in the repository fire immediately on the new data.
2. Run `ex2-lastGenKinship.sparql` — the new generation's kinship vocabulary is already there. Siblings, grandchildren, cousins, aunts/uncles — every relationship derived automatically, with zero extra steps.

**Neo4j**:
1. Paste and run `out_graphdb/loadIncrementalCSV.cypher` (or `data-000-lastgen.cypher`). The new people now exist with their `PARENT_OF` and `MARRIED_TO` edges.
2. Run `ex2-lastGenKinship.cypher` — the new people appear but with **no kinship relationships**. The Relationship column is empty for all of them. They are structurally present but semantically invisible.
3. Re-run `main/queries/neo4j-materialize_rules.cypher` — because every statement uses `MERGE`, re-running is safe; it only creates what is missing.
4. Re-run `ex2-lastGenKinship.cypher` — the new family is now fully represented. Both databases match.

> **Observation**: GraphDB updated the moment new data arrived. Neo4j required an import *plus* re-running a ~290-line script — and if you forgot that second step, the graph would silently return incomplete results with no warning.

---

### Exercise #3 — Add New Rules (the in-laws)

This exercise demonstrates the power of adding new rules without touching existing data.

**GraphDB**:
1. Run `switch-ruleset.sh` to prepare the ruleset switch
2. Run `util-addRuleset.sparql` — loads `kinship-full.pie` which adds in-law rules
3. Run `util-defaultRuleset.sparql` — sets the full ruleset as default
4. Import `schema-inlaws.ttl` via **Import → RDF → Server files**
5. Run `util-reinfer.sparql` — forces re-inference with the new rules
6. Run `ex3-showInLaws.sparql` — all 6 in-law relationship types appear immediately

**Neo4j**:
1. Run `ex3-showInLaws.cypher` — returns nothing; Neo4j has no in-law edges
2. Paste and run `main/queries/neo4j-materialize_new_rules.cypher` — a new Cypher script that computes the 6 in-law relationship types
3. Re-run `ex3-showInLaws.cypher` — in-law relationships now appear

> **Final takeaway**: In GraphDB, adding new relationship types required loading a new ruleset and re-inferring — the data was never touched. In Neo4j, every new relationship type requires writing and running additional Cypher code. As your domain model evolves, this gap compounds: GraphDB adapts by editing rules; Neo4j requires editing, testing, and maintaining an ever-growing body of application code.

---

## Shut Down

When finished with a session, stop both containers gracefully:

```bash
cd sandboxes/graphdb && ./run.sh down
cd sandboxes/neo4j   && ./run.sh down
```

Data is preserved in `sandboxes/graphdb/graphdb-data/` and `sandboxes/neo4j/data/`. Restart anytime with `./run.sh up`. When you are completely done with the demo, `./run.sh purge` removes containers, images, and data volumes entirely — see the **Container Management Reference** section below for details.

---

## The Data Model

Only two base relationships are stored in the generated data:

| Relationship | Description |
|---|---|
| `ex:parentOf` | Direct parent → child link |
| `ex:marriedTo` | Spouse link (one direction only; symmetry is inferred/materialized) |

Gender is encoded as RDF class membership: `rdf:type ex:female` or `rdf:type ex:male`. Each person also has `ex:givenName`, `ex:surname`, and `rdfs:label` (full name).

All other kinship relationships — and there are 47 of them — are derived:

```
parentOf
  → childOf, grandparentOf, siblingOf
    → greatGrandparentOf, grandchildOf, auntUncleOf, greatAuntUncleOf
      → greatGrandchildOf, nieceNephewOf, secondAuntUncleOf, cousinOf
        → secondCousinOf, firstCousinOnceRemovedOf
          + gender → motherOf, fatherOf, sisterOf, brotherOf, auntOf, uncleOf,
                     grandmotherOf, grandfatherOf, nieceOf, nephewOf, ...
marriedTo + parentOf/childOf/siblingOf + gender
  → fatherInLawOf, motherInLawOf, sonInLawOf, daughterInLawOf,
    brotherInLawOf, sisterInLawOf
```

This derivation chain is the same in both databases. In GraphDB it is expressed as logical rules in `kinship.pie`. In Neo4j it is expressed as ~50 imperative Cypher statements in `main/queries/neo4j-materialize_rules.cypher`.

---

## A Note on Transparency

This demo was developed with the assistance of [Claude Code](https://claude.ai/code), Anthropic's AI coding assistant. Claude helped generate and refine several components of this project, including the Python data generator, the SHACL rules and OWL ontology, the Neo4j Cypher materialization script, the SPARQL and Cypher example queries, and this README itself.

The goal of mentioning this isn't to disclaim the work — every piece was reviewed, tested, and intentionally shaped toward the learning objectives of the demo — but because the author believes transparency about AI-assisted development is important, especially in an educational context. If you are working through this exercise to learn, you should know that you can use the same tools to explore, extend, and question everything here. Asking an AI to explain a SHACL rule, suggest a new kinship relationship to model, or help you translate a SPARQL query to Cypher is a completely legitimate and productive way to learn.

---

## Key Takeaways

| | GraphDB | Neo4j |
|---|---|---|
| **Knowledge location** | In the graph (rules are data) | In application scripts |
| **Derived relationships** | Automatic via reasoning engine | Manual, ordered Cypher execution |
| **Data changes** | Re-run materialization; rules stay the same | Re-run the full script |
| **New relationship types** | Add a rule; all existing data benefits | Write new Cypher for every new type |
| **Query style** | SPARQL — reads inferred triples directly | Cypher — traverses explicit edges |
| **Standards basis** | RDF, OWL, SHACL (W3C standards) | Property graph (vendor-specific) |

Neither approach is universally better — they reflect genuine architectural tradeoffs. Neo4j's explicit model is fast, flexible, and familiar to developers. GraphDB's inference model is more expressive, more maintainable as complexity grows, and produces a self-describing knowledge graph. This demo gives you a concrete basis for making that choice in your own projects.

---

## Credits

The kinship relationship vocabulary at the heart of this demo — the full set of family relationships from `siblingOf` through `firstCousinOnceRemovedOf` and all their gendered variants — is derived from an Answer Set Programming (ASP) ontology originally authored by **Patrick Hohenecker**:

> `ontology.asp` — Family Tree Ontology
> Author: Patrick Hohenecker ([mail@paho.at](mailto:mail@paho.at))
> Version: 2018.1 (May 30, 2018)
> License: [2-Clause BSD License](https://opensource.org/licenses/BSD-2-Clause)
> Source: [github.com/phohenecker/family-tree-data](https://github.com/phohenecker/family-tree-data)

The original rules were written in ASP (a logic programming formalism used heavily in AI research) and translated into SHACL SPARQLRules for use with GraphDB in this demo. The relationship vocabulary, derivation chain, and logic structure are Patrick's original work. The `ontology.asp` file is included in this repository for reference. Attribution is also preserved in the header comments of `main/rules.ttl`.

---

## Troubleshooting

**GraphDB won't start** — Confirm `GRAPHWISE_GRAPHDB_FREE_v11.3.license` exists in the `sandboxes/graphdb/` directory before running `./run.sh setup`.

**`podman compose` not found** — Install with `pip install podman-compose` or `brew install podman-compose`. Alternatively, use `docker compose` and substitute `docker` for `podman` throughout.

**GraphDB shows no inferred relationships** — Ensure the repository was created with the `kinship.pie` custom ruleset selected. If you created it without, delete the repository and recreate it with the ruleset. Then re-import `schema.ttl` and `000.ttl`.

**Neo4j kinship queries return no results** — Ensure `data-000.cypher` (or `loadFromCSV.cypher`) was loaded before running `main/queries/neo4j-materialize_rules.cypher`. The materialization script depends on `PARENT_OF` edges existing.

**Port conflicts** — If ports 7200, 7474, or 7687 are in use, edit the `ports:` section of the relevant `docker-compose.yaml` before running setup.

---

## Container Management Reference

Both GraphDB and Neo4j are managed through a `run.sh` script in their respective subdirectories (`sandboxes/graphdb/run.sh` and `sandboxes/neo4j/run.sh`). All commands follow the same pattern:

```bash
cd sandboxes/graphdb   # or: cd sandboxes/neo4j
./run.sh <command>
```

### Commands

#### `setup` — First-time initialization
Run this once when you are setting up the demo for the first time. It performs all necessary preparation and then starts the container.

- For **GraphDB**: copies the license file into the data volume, creates the shared `demo-network` Podman network (if it does not already exist), and starts the container
- For **Neo4j**: creates the `demo-network` network (if it does not already exist) and starts the container

```bash
./run.sh setup
```

> Run `setup` only once. If the container already exists and you run `setup` again, it will attempt to re-create it and may produce errors. Use `up` for all subsequent starts.

---

#### `up` — Start a previously set-up container
Starts an existing container that was previously set up and has since been stopped. Data and configuration are preserved between stops — this picks up exactly where you left off.

```bash
./run.sh up
```

Use this for your day-to-day workflow after the initial setup: stop at the end of a session with `down`, start again next time with `up`.

---

#### `down` — Stop the container, preserve data
Gracefully stops the running container. All data is preserved in the local volume directories (`sandboxes/graphdb/graphdb-data/` and `sandboxes/neo4j/data/`). Nothing is deleted. The container can be restarted at any time with `./run.sh up`.

```bash
./run.sh down
```

This is the safe, everyday way to stop a container. Use it freely — your graph data, imported files, and repository configuration will all be waiting for you when you come back.

---

#### `purge` — Destructive full teardown
Stops the container and **permanently deletes** the container, its image, the `demo-network` network, and all local data directories. This is a full reset — after a purge, you would need to run `setup` again from scratch to use the database.

```bash
./run.sh purge
```

> **Warning: this is irreversible.** The script will prompt you to confirm before proceeding. Any data you have loaded into the database — imported graphs, repositories, query history — will be permanently lost. Use `down` instead if you just want to stop the container temporarily.

Purge is useful when you want to start completely fresh, free up disk space after you are done with the demo, or recover from a broken container state that `down` and `up` cannot fix.

---

### Quick Reference

| Command | What it does | Data preserved? | When to use |
|---|---|---|---|
| `setup` | Initialize and start (first time only) | N/A | Once, at the very beginning |
| `up` | Start a stopped container | Yes | Every subsequent session |
| `down` | Stop the container | Yes | End of each session |
| `purge` | Delete everything | No — irreversible | Done with demo, or full reset |