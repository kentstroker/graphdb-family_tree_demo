# Labeled Property Graph (LPG) — Neo4j Kinship Materialization

This document explains the Neo4j Cypher-based approach to materializing the full kinship vocabulary from the raw family tree data. It covers what an LPG is, why materialization is necessary in Neo4j, how the script is structured, and the key architectural trade-offs compared to the RDF/GraphDB inference approach.

---

## What Is a Labeled Property Graph?

A **Labeled Property Graph (LPG)** is the data model used by Neo4j and most mainstream graph databases. It consists of:

- **Nodes** — entities in the graph, each optionally tagged with one or more *labels* (e.g., `:Person`)
- **Relationships** — directed, named edges connecting two nodes (e.g., `(a)-[:PARENT_OF]->(b)`)
- **Properties** — key-value pairs attached to nodes or relationships (e.g., `fullName: "Anthony Blanchard"`, `female: true`)

LPGs are intuitive, fast for traversal queries, and well-suited to many real-world graph problems. However, they have no built-in reasoning engine — the database stores exactly what you put in and nothing more. Any derived or computed information must be explicitly calculated and stored.

---

## Why Materialization Is Necessary

In the RDF/GraphDB side of this demo, declaring `grandparentOf` as a logical axiom is enough — the reasoning engine applies the rule and the relationship appears automatically for every applicable pair of nodes. In Neo4j, no such engine exists.

To make `GRANDPARENT_OF`, `SIBLING_OF`, `AUNT_UNCLE_OF`, and the 39 other derived kinship relationships queryable, they must be **materialized** — computed by traversing the graph and written back as explicit edges. This is what `neo4j-materialize_rules.cypher` does.

The process is a one-time batch operation that must be re-run whenever new data is added.

---

## Script Structure and Execution Order

The materialization script is divided into numbered steps that must be run **in strict dependency order**. Later steps rely on edges created by earlier ones. Running them out of order produces missing or incorrect results.

All statements use `MERGE` rather than `CREATE`, making the script **idempotent** — safe to run multiple times without creating duplicate edges.

---

### Step 1 — `SIBLING_OF`

Two people are siblings if they share at least one common parent. Both directions are created explicitly because Neo4j relationships are directed, but siblings are a symmetric concept.

```cypher
MATCH (z:Person)-[:PARENT_OF]->(x:Person),
      (z:Person)-[:PARENT_OF]->(y:Person)
WHERE x <> y
MERGE (x)-[:SIBLING_OF]->(y);
```

> **Why both directions?** In RDF, `siblingOf` can be declared `owl:SymmetricProperty` and the reasoner fills in the reverse automatically. In Neo4j you must either create both directed edges or always query with an undirected pattern `-[:SIBLING_OF]-`. Creating both keeps queries simpler and more consistent.

---

### Step 2 — `GRANDPARENT_OF` / `GRANDCHILD_OF`

A grandparent is two `PARENT_OF` hops away. The inverse (`GRANDCHILD_OF`) is derived immediately after.

```cypher
MATCH (x:Person)-[:PARENT_OF]->(z:Person)-[:PARENT_OF]->(y:Person)
MERGE (x)-[:GRANDPARENT_OF]->(y);

MATCH (x:Person)-[:GRANDPARENT_OF]->(y:Person)
MERGE (y)-[:GRANDCHILD_OF]->(x);
```

---

### Step 3 — `GREAT_GRANDPARENT_OF` / `GREAT_GRANDCHILD_OF`

Depends on `GRANDPARENT_OF` from Step 2.

```cypher
MATCH (x:Person)-[:PARENT_OF]->(z:Person)-[:GRANDPARENT_OF]->(y:Person)
MERGE (x)-[:GREAT_GRANDPARENT_OF]->(y);

MATCH (x:Person)-[:GREAT_GRANDPARENT_OF]->(y:Person)
MERGE (y)-[:GREAT_GRANDCHILD_OF]->(x);
```

---

### Step 4 — `CHILD_OF`

The inverse of `PARENT_OF`. Placed here (after grandparent steps) because grandchild derivation uses `GRANDPARENT_OF` directly rather than chaining through `CHILD_OF`.

```cypher
MATCH (x:Person)-[:PARENT_OF]->(y:Person)
MERGE (y)-[:CHILD_OF]->(x);
```

---

### Step 5 — `AUNT_UNCLE_OF` / `NIECE_NEPHEW_OF`

A sibling of a parent is an aunt or uncle. Depends on `SIBLING_OF` from Step 1.

```cypher
MATCH (x:Person)-[:SIBLING_OF]->(z:Person)-[:PARENT_OF]->(y:Person)
MERGE (x)-[:AUNT_UNCLE_OF]->(y);

MATCH (x:Person)-[:AUNT_UNCLE_OF]->(y:Person)
MERGE (y)-[:NIECE_NEPHEW_OF]->(x);
```

---

### Step 6 — `GREAT_AUNT_UNCLE_OF`

A sibling of a grandparent is a great-aunt or great-uncle. Depends on both `SIBLING_OF` (Step 1) and `GRANDPARENT_OF` (Step 2).

```cypher
MATCH (x:Person)-[:SIBLING_OF]->(z:Person)-[:GRANDPARENT_OF]->(y:Person)
MERGE (x)-[:GREAT_AUNT_UNCLE_OF]->(y);
```

---

### Step 7 — `SECOND_AUNT_UNCLE_OF`

The child of a great-aunt or great-uncle is a second aunt or uncle. Depends on `GREAT_AUNT_UNCLE_OF` from Step 6.

```cypher
MATCH (z:Person)-[:GREAT_AUNT_UNCLE_OF]->(y:Person),
      (z:Person)<-[:PARENT_OF]-(x:Person)
MERGE (x)-[:SECOND_AUNT_UNCLE_OF]->(y);
```

---

### Step 8 — `COUSIN_OF`

Your parent is an aunt or uncle of your cousin. Both directions are explicitly created (symmetric relationship). Depends on `AUNT_UNCLE_OF` from Step 5.

```cypher
MATCH (z:Person)-[:PARENT_OF]->(x:Person),
      (z:Person)-[:AUNT_UNCLE_OF]->(y:Person)
MERGE (x)-[:COUSIN_OF]->(y)
MERGE (y)-[:COUSIN_OF]->(x);
```

---

### Step 9 — `SECOND_COUSIN_OF`

Your parent is a second aunt or uncle of your second cousin. Depends on `SECOND_AUNT_UNCLE_OF` from Step 7.

```cypher
MATCH (z:Person)-[:PARENT_OF]->(x:Person),
      (z:Person)-[:SECOND_AUNT_UNCLE_OF]->(y:Person)
MERGE (x)-[:SECOND_COUSIN_OF]->(y)
MERGE (y)-[:SECOND_COUSIN_OF]->(x);
```

---

### Step 10 — `FIRST_COUSIN_ONCE_REMOVED_OF`

One person is a cousin of the other's parent — a generational offset from a cousin relationship. Depends on `COUSIN_OF` from Step 8.

```cypher
MATCH (y:Person)-[:COUSIN_OF]->(z:Person)-[:PARENT_OF]->(x:Person)
MERGE (x)-[:FIRST_COUSIN_ONCE_REMOVED_OF]->(y);
```

---

### Gendered Variants

Once all gender-neutral relationships are in place, gendered specializations are derived by filtering on the `female` boolean property of the subject node. Each neutral relationship produces two gendered edges.

```cypher
-- Parent tier
MATCH (x:Person)-[:PARENT_OF]->(y:Person) WHERE x.female = true  MERGE (x)-[:MOTHER_OF]->(y);
MATCH (x:Person)-[:PARENT_OF]->(y:Person) WHERE x.female = false MERGE (x)-[:FATHER_OF]->(y);

-- Child tier
MATCH (x:Person)-[:CHILD_OF]->(y:Person) WHERE x.female = true  MERGE (x)-[:DAUGHTER_OF]->(y);
MATCH (x:Person)-[:CHILD_OF]->(y:Person) WHERE x.female = false MERGE (x)-[:SON_OF]->(y);

-- Sibling tier
MATCH (x:Person)-[:SIBLING_OF]->(y:Person) WHERE x.female = true  MERGE (x)-[:SISTER_OF]->(y);
MATCH (x:Person)-[:SIBLING_OF]->(y:Person) WHERE x.female = false MERGE (x)-[:BROTHER_OF]->(y);

-- (... and so on for all tiers through second cousin once removed)
```

The full gendered variant script covers 14 relationship pairs (28 individual statements). See `main/queries/neo4j-materialize_rules.cypher` for the complete file.

---

## Key Observations

### Order matters

Unlike SHACL rules in GraphDB, which are applied iteratively until no new triples can be inferred (a *fixpoint*), Neo4j Cypher statements are imperative. Step 6 will produce no results if Step 1 has not run, because `SIBLING_OF` edges won't exist yet. The developer is responsible for maintaining the correct execution order.

### Symmetric relationships require explicit handling

In RDF/OWL, a property can be declared `owl:SymmetricProperty`, and the reasoner automatically infers both directions. In Neo4j, symmetric relationships (`SIBLING_OF`, `COUSIN_OF`, `SECOND_COUSIN_OF`) must either:
- Be created in both directions explicitly (as this script does), or
- Be queried using undirected Cypher patterns: `(x)-[:SIBLING_OF]-(y)`

This script takes the explicit approach for consistency — any directional query will work.

### Materialization vs. query-time computation

An alternative to pre-materializing all these relationships is to compute them at query time using Cypher path patterns. For example, `GRANDPARENT_OF` could be expressed inline as:

```cypher
MATCH (x)-[:PARENT_OF]->()-[:PARENT_OF]->(y)
```

This avoids the materialization step but makes queries more complex, harder to read, and slower on large graphs. Pre-materializing trades storage space for query simplicity and performance — a reasonable trade-off for a demo and for many production use cases.

### Relationship type count

The complete materialization produces exactly **47 derived edge types** from two asserted base relationships (`PARENT_OF`, `MARRIED_TO`). Combined with the two base types, the graph contains **49 distinct edge type labels** in total. This vividly illustrates the cost of the LPG approach: every relationship that an inference engine would derive for free must instead be explicitly computed, stored, and maintained.

| | LPG (Neo4j) | RDF/OWL (GraphDB) |
|---|---|---|
| Asserted edge types | 2 (`PARENT_OF`, `MARRIED_TO`) | 2 (`ex:parentOf`, `ex:marriedTo`) |
| Derived edge types | 47 (explicit, via `neo4j-materialize_rules.cypher`) | 47 (inferred, via `kinship.pie` or `rules.ttl`) |
| Developer effort to add new relationship | Write new Cypher, re-run script | Add one rule to `rules.ttl` |
| Stays current when data changes | Only after re-running script | Automatically on next materialization |

---

## When to Use Each Approach

**Use Neo4j / LPG when:**
- Your relationship vocabulary is small and stable
- Query performance is the primary concern
- Your team is more comfortable with SQL-like imperative thinking
- You need fine-grained control over exactly what is stored

**Use GraphDB / RDF+OWL when:**
- Your domain knowledge is complex and evolving
- You want the database to reason about data on your behalf
- Interoperability with W3C standards (SPARQL, OWL, SKOS) matters
- You are building a knowledge graph intended to grow and integrate with other datasets
