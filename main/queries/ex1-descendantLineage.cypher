// =============================================================================
// ex1-descendantLineage.cypher — Exercise 1: Inference vs. No Inference
// Author:  Kent Stroker
//
// Tabular lineage report starting from Anthony Blanchard (person/0-0),
// walking down the PARENT_OF chain through all generations.  For each
// descendant the query returns the generation number, full name, the
// kinship relationship from person/0-0 to them, and the descendant's name
// (e.g. "Anthony Blanchard — FATHER OF → Russell Blanchard").
//
// The key observation: this query is run RIGHT AFTER data loading — before
// neo4j-materialize_rules.cypher has been executed.  The Relationship column will
// be EMPTY for every row because Neo4j only stores what you explicitly
// put in.  No FATHER_OF, GRANDFATHER_OF, or GREAT_GRANDFATHER_OF edges
// exist yet — only raw PARENT_OF.
//
// Compare the output with ex1-descendantLineage.sparql in GraphDB, where
// every row already has a Relationship value thanks to automatic inference.
//
// Usage: Run in Neo4j Browser (returns table).
// Requires: loadFromCSV.cypher (or data-000.cypher) loaded.
// =============================================================================

MATCH path = (root:Person {fullName: 'Anthony Blanchard'})-[:PARENT_OF*1..3]->(descendant:Person)
WITH root, descendant, min(length(path)) AS generation

// Attempt to find a kinship edge from root to descendant.
// Before materialization this OPTIONAL MATCH returns nothing — proving
// that Neo4j has no knowledge beyond what was explicitly loaded.
OPTIONAL MATCH (root)-[k]->(descendant)
  WHERE type(k) IN [
    'FATHER_OF', 'GRANDFATHER_OF', 'GREAT_GRANDFATHER_OF',
    'MOTHER_OF', 'GRANDMOTHER_OF', 'GREAT_GRANDMOTHER_OF'
  ]

RETURN
  generation          AS Generation,
  root.fullName       AS Name,
  COALESCE(
    REPLACE(type(k), '_', ' '),
    ''
  )                   AS Relationship,
  descendant.fullName AS DescendantName
ORDER BY generation, descendant.fullName;