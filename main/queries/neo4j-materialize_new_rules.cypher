// =============================================================================
// neo4j-materialize_new_rules.cypher
// Author:  Kent Stroker
// Date:    2026-03-12
//
// Materializes the 6 in-law relationship types in Neo4j (8 MERGE statements —
// brother/sister-in-law each have two derivation paths).
//
// Depends on: CHILD_OF and SIBLING_OF must already exist from
// neo4j-materialize_rules.cypher before running this script.
//
// Safe to run multiple times — all statements use MERGE (idempotent).
//
// Usage:
//   Run each statement one at a time in Neo4j Browser.
//   Requires: neo4j-materialize_rules.cypher to have been run first.
// =============================================================================


// ═══════════════════════════════════════════════════════════════════════════════
// IN-LAW RELATIONSHIPS (6 designations, 8 MERGE statements)
//
// The six standard in-law designations used in genealogy.  Derived from
// MARRIED_TO combined with PARENT_OF, CHILD_OF, or SIBLING_OF plus gender.
// Brother/sister-in-law each have two derivation paths (two statements).
// ═══════════════════════════════════════════════════════════════════════════════

// -- Parent-in-law ------------------------------------------------------------

// fatherInLawOf: X is father of Z, Z is married to Y, X is male
// "Y's father-in-law is X" — the father of Y's spouse
MATCH (x:Person)-[:PARENT_OF]->(z:Person)-[:MARRIED_TO]-(y:Person)
WHERE x.female = false
MERGE (x)-[:FATHER_IN_LAW_OF]->(y);

// motherInLawOf: X is mother of Z, Z is married to Y, X is female
// "Y's mother-in-law is X" — the mother of Y's spouse
MATCH (x:Person)-[:PARENT_OF]->(z:Person)-[:MARRIED_TO]-(y:Person)
WHERE x.female = true
MERGE (x)-[:MOTHER_IN_LAW_OF]->(y);

// -- Child-in-law -------------------------------------------------------------

// sonInLawOf: X is married to Z, Z is a child of Y, X is male
// "Y's son-in-law is X" — the husband of Y's child
MATCH (x:Person)-[:MARRIED_TO]-(z:Person)-[:CHILD_OF]->(y:Person)
WHERE x.female = false
MERGE (x)-[:SON_IN_LAW_OF]->(y);

// daughterInLawOf: X is married to Z, Z is a child of Y, X is female
// "Y's daughter-in-law is X" — the wife of Y's child
MATCH (x:Person)-[:MARRIED_TO]-(z:Person)-[:CHILD_OF]->(y:Person)
WHERE x.female = true
MERGE (x)-[:DAUGHTER_IN_LAW_OF]->(y);

// -- Sibling-in-law (two paths each) -----------------------------------------

// brotherInLawOf — path A: spouse's brother
// X is brother-in-law of Y when Y is married to Z, Z is sibling of X, X is male
MATCH (y:Person)-[:MARRIED_TO]-(z:Person)-[:SIBLING_OF]-(x:Person)
WHERE x.female = false AND x <> y
MERGE (x)-[:BROTHER_IN_LAW_OF]->(y);

// brotherInLawOf — path B: sibling's husband
// X is brother-in-law of Y when X is married to Z, Z is sibling of Y, X is male
MATCH (x:Person)-[:MARRIED_TO]-(z:Person)-[:SIBLING_OF]-(y:Person)
WHERE x.female = false AND x <> y
MERGE (x)-[:BROTHER_IN_LAW_OF]->(y);

// sisterInLawOf — path A: spouse's sister
// X is sister-in-law of Y when Y is married to Z, Z is sibling of X, X is female
MATCH (y:Person)-[:MARRIED_TO]-(z:Person)-[:SIBLING_OF]-(x:Person)
WHERE x.female = true AND x <> y
MERGE (x)-[:SISTER_IN_LAW_OF]->(y);

// sisterInLawOf — path B: sibling's wife
// X is sister-in-law of Y when X is married to Z, Z is sibling of Y, X is female
MATCH (x:Person)-[:MARRIED_TO]-(z:Person)-[:SIBLING_OF]-(y:Person)
WHERE x.female = true AND x <> y
MERGE (x)-[:SISTER_IN_LAW_OF]->(y);
