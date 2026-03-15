# TODO / Future Work

This file tracks ideas and planned enhancements for the family tree demo. The current demo effectively illustrates the *mechanical* difference between GraphDB inference and Neo4j materialization — but the most compelling argument for knowledge graph inference is how it interacts with **AI and large language models**. That story is largely untold here, and it represents the most important direction for future development.

---

## Priority 1 — LLM + Agent Integration

### The Core Problem with Ungrounded LLMs

Large language models are impressive at generating fluent, confident-sounding answers — including answers about family relationships. Ask a raw LLM "who is Anthony Blanchard's second cousin?" and it will fabricate a plausible-sounding response with complete confidence, even though it has no knowledge of Anthony Blanchard at all. This is the hallucination problem, and it is not a minor quirk — it is a fundamental limitation of the transformer architecture when applied to specific, factual domains.

The standard mitigation is **Retrieval-Augmented Generation (RAG)**: retrieve relevant facts from a trusted source, inject them into the prompt, and let the LLM generate a response grounded in those facts. RAG works well for document retrieval, but it has a critical weakness when the question requires multi-hop reasoning — for example, "find all of Anthony Blanchard's cousins who are also grandchildren of someone named Patricia." A naive RAG pipeline retrieves flat text chunks; it has no way to traverse a relationship graph.

This is exactly where **GraphRAG** — grounding an LLM with a knowledge graph — becomes compelling.

### What to Build

#### Option A — SPARQL/Cypher Query Agent

Build a conversational agent that accepts natural language questions about the family tree and answers them by:

1. Using an LLM (e.g., Claude, GPT-4o) to translate the natural language question into a SPARQL query (for GraphDB) or a Cypher query (for Neo4j)
2. Executing the query against the live database
3. Feeding the structured results back to the LLM to generate a natural language answer

This creates a direct, demonstrable comparison:
- Ask GraphDB: *"Who are all of Anthony Blanchard's aunts?"* — the SPARQL query reads directly from inferred `ex:auntOf` triples. One clean triple pattern. Done.
- Ask Neo4j the same question: the Cypher must either traverse `SIBLING_OF → PARENT_OF` at query time, or rely on the pre-materialized `AUNT_OF` edges that someone remembered to run `neo4j-materialize_rules.cypher` to create.

The GraphDB version naturally produces better, more composable queries because the knowledge is *in the graph*. The Neo4j version requires the query author to know which edges have been materialized and whether they are up to date.

#### Option B — Graph-Grounded RAG Comparison Demo

Build a side-by-side demo that answers the same question three ways and displays all three responses:

1. **Ungrounded LLM** — raw prompt, no context. Shows hallucination or refusal.
2. **Neo4j RAG** — LLM grounded with Cypher results from the materialized LPG. Correct, but only as fresh as the last time `neo4j-materialize_rules.cypher` was run.
3. **GraphDB RAG** — LLM grounded with SPARQL results from the inferred RDF graph. Correct, always current, richer relationship vocabulary available.

This is the most powerful demo format because it makes the three failure modes visible side by side:
- The ungrounded LLM confidently invents family members
- The Neo4j RAG gives correct answers for relationships that were materialized, but may miss relationships if the script hasn't been re-run after new data was added
- The GraphDB RAG gives correct, complete answers derived from the live inference engine

#### Option C — Agentic Family Researcher

Build a multi-step agent that can answer complex, multi-hop questions like:

> *"Find everyone in the family tree who shares a great-grandparent with Anthony Blanchard but has a different last name, and tell me how they are related to him."*

This type of question is trivial to express as a SPARQL query over an inferred graph, but is nearly impossible for a flat-document RAG system to answer correctly. An agent equipped with a GraphDB SPARQL tool can decompose the question, execute sub-queries, and assemble a grounded, accurate answer — demonstrating that knowledge graph inference is not just a database curiosity but a practical enabler of reliable AI reasoning.

### Why This Matters for the Demo's Core Message

The current demo proves that GraphDB produces the same derived relationships as Neo4j with far less code. That is a valid and interesting point for a database audience. But for an AI audience — which is a much larger and more urgent audience right now — the more important point is:

> **Inference-based knowledge graphs are a natural, reliable grounding layer for LLMs. The less you have to materialize explicitly, the less there is to go stale, miss, or get wrong when an AI agent queries your data.**

An LLM querying a knowledge graph that has reasoned about its own contents is fundamentally more reliable than an LLM querying a property graph that only knows what a developer thought to pre-compute. When you add a new person to GraphDB, every kinship relationship they have is immediately available to an agent — no re-run, no script, no forgotten step. That is the story worth telling, and an agent integration makes it visceral.

### Suggested Technology Stack

- **LLM**: Claude (`claude-opus-4-6` or `claude-sonnet-4-6`) via the Anthropic API — well-suited for SPARQL/Cypher generation and natural language synthesis
- **Agent framework**: Claude Agent SDK or LangChain with tool-use for database query execution
- **GraphDB interface**: HTTP SPARQL endpoint at `http://localhost:7200/repositories/{repo}/sparql`
- **Neo4j interface**: `neo4j` Python driver or bolt connection at `bolt://localhost:7687`
- **UI**: Streamlit for a quick side-by-side comparison interface, or a simple CLI for a terminal demo

---

## Priority 2 — SPARQL UPDATE Materialization Track

Create a SPARQL UPDATE equivalent of `neo4j-materialize_rules.cypher` that performs kinship materialization via SPARQL INSERT statements — useful for RDF stores that support SPARQL Update but not GraphDB's native SHACL/`.pie` rules engine. This would enable a third comparison track: SPARQL Update materialization vs. SHACL inference vs. Cypher materialization.

---

## Priority 3 — Additional Data and Locales

- **Larger datasets**: Add pre-staged `out_graphdb/` samples with more generations and larger families to showcase reasoning at scale
- **Localized datasets**: Use `--faker-locale` to generate non-English family trees (German, Japanese, Spanish) to demonstrate the locale-agnostic nature of the graph model
- **Multiple locales side-by-side**: Generate several trees with different `--faker-locale` values and load them into the same graph to show locale-agnostic inference

---

## Priority 4 — GraphDB Repository Auto-Configuration

Currently, the user must manually create a GraphDB repository and import files through the Workbench UI. A future improvement would automate this via the GraphDB REST API:

- Script repository creation with SHACL support enabled
- Auto-import `schema.ttl`, `rules.ttl`, and `data/*.ttl` via the import API
- Trigger SHACL materialization via API call
- Print the SPARQL endpoint URL on completion

This would reduce the GraphDB setup from a multi-step UI process to a single shell command, making the demo more approachable for audiences unfamiliar with the GraphDB Workbench.

---

## Priority 5 — newVersionsCheck.sh Linux Compatibility

`newVersionsCheck.sh` currently uses `sed -i ''` which is macOS-specific BSD syntax. On Linux, `sed -i` does not accept the empty-string argument and will error. If this repo is ever used on Linux, the script needs a platform check:

```bash
if [[ "$OSTYPE" == "darwin"* ]]; then
    sed -i '' "s/..." file
else
    sed -i "s/..." file
fi
```

Consider adding this guard so the script works cross-platform without requiring the user to edit it manually.

---

## Priority 6 — Visual Diff of Graph State

Build a simple visualization that shows the graph *before* and *after* inference/materialization — illustrating concretely how many edges were added by the reasoning engine vs. what was explicitly stored. A before/after edge count comparison (e.g., "2 edge types → 42 edge types") would be a compelling slide for a presentation.
