// =============================================================================
// neo4j-materialize_rules.cypher
// Author:  Kent Stroker
// Date:    2026-03-09
//
// Materializes all 41 derived kinship relationships in Neo4j by traversing
// the base :PARENT_OF and :MARRIED_TO edges and writing explicit MERGE
// statements for every derived relationship type. Safe to re-run (MERGE).
// Must be run in strict dependency order — later tiers use edges from earlier.
//
// Usage: Run in Neo4j Browser (paste full script, run once).
// Requires: data-NNN.cypher files (or loadFromCSV.cypher) loaded first.
// =============================================================================
// Materializes all derived kinship relationships in Neo4j.
// Run AFTER loading data.cypher (which provides :PARENT_OF and :MARRIED_TO edges).
// Safe to re-run: all statements use MERGE.
//
// Derivation order follows the dependency chain in rules.ttl:
//   parentOf → childOf, grandparentOf, greatGrandparentOf
//   grandparentOf → grandchildOf, greatGrandparentOf
//   greatGrandparentOf → greatGrandchildOf
//   parentOf × parentOf → siblingOf
//   siblingOf + parentOf → auntUncleOf
//   siblingOf + grandparentOf → greatAuntUncleOf
//   parentOf + greatAuntUncleOf → secondAuntUncleOf
//   auntUncleOf → nieceNephewOf
//   parentOf + auntUncleOf → cousinOf
//   parentOf + secondAuntUncleOf → secondCousinOf
//   cousinOf + parentOf → firstCousinOnceRemovedOf
//   all of the above + gender property → gendered variants


// ── Tier 1: direct derivations from parentOf ─────────────────────────────────

// childOf(X,Y) :- parentOf(Y,X)
MATCH (y:Person)-[:PARENT_OF]->(x:Person)
MERGE (x)-[:CHILD_OF]->(y);

// grandparentOf(X,Y) :- parentOf(X,Z), parentOf(Z,Y)
MATCH (x:Person)-[:PARENT_OF]->(z:Person)-[:PARENT_OF]->(y:Person)
MERGE (x)-[:GRANDPARENT_OF]->(y);

// siblingOf(X,Y) :- parentOf(Z,X), parentOf(Z,Y), X <> Y
MATCH (z:Person)-[:PARENT_OF]->(x:Person), (z)-[:PARENT_OF]->(y:Person)
WHERE x <> y
MERGE (x)-[:SIBLING_OF]->(y);


// ── Tier 2: depend on grandparentOf ──────────────────────────────────────────

// greatGrandparentOf(X,Y) :- parentOf(X,Z), grandparentOf(Z,Y)
MATCH (x:Person)-[:PARENT_OF]->(z:Person)-[:GRANDPARENT_OF]->(y:Person)
MERGE (x)-[:GREAT_GRANDPARENT_OF]->(y);

// grandchildOf(X,Y) :- grandparentOf(Y,X)
MATCH (y:Person)-[:GRANDPARENT_OF]->(x:Person)
MERGE (x)-[:GRANDCHILD_OF]->(y);


// ── Tier 3: depend on greatGrandparentOf ─────────────────────────────────────

// greatGrandchildOf(X,Y) :- greatGrandparentOf(Y,X)
MATCH (y:Person)-[:GREAT_GRANDPARENT_OF]->(x:Person)
MERGE (x)-[:GREAT_GRANDCHILD_OF]->(y);


// ── Tier 4: depend on siblingOf ──────────────────────────────────────────────

// auntUncleOf(X,Y) :- siblingOf(X,Z), parentOf(Z,Y)
MATCH (x:Person)-[:SIBLING_OF]->(z:Person)-[:PARENT_OF]->(y:Person)
MERGE (x)-[:AUNT_UNCLE_OF]->(y);

// greatAuntUncleOf(X,Y) :- siblingOf(X,Z), grandparentOf(Z,Y)
MATCH (x:Person)-[:SIBLING_OF]->(z:Person)-[:GRANDPARENT_OF]->(y:Person)
MERGE (x)-[:GREAT_AUNT_UNCLE_OF]->(y);


// ── Tier 5: depend on auntUncleOf / greatAuntUncleOf ─────────────────────────

// nieceNephewOf(X,Y) :- auntUncleOf(Y,X)
MATCH (y:Person)-[:AUNT_UNCLE_OF]->(x:Person)
MERGE (x)-[:NIECE_NEPHEW_OF]->(y);

// secondAuntUncleOf(X,Y) :- parentOf(Z,X), greatAuntUncleOf(Z,Y)
MATCH (z:Person)-[:PARENT_OF]->(x:Person), (z)-[:GREAT_AUNT_UNCLE_OF]->(y:Person)
MERGE (x)-[:SECOND_AUNT_UNCLE_OF]->(y);

// cousinOf(X,Y) :- parentOf(Z,X), auntUncleOf(Z,Y)
MATCH (z:Person)-[:PARENT_OF]->(x:Person), (z)-[:AUNT_UNCLE_OF]->(y:Person)
MERGE (x)-[:COUSIN_OF]->(y);


// ── Tier 6: depend on secondAuntUncleOf / cousinOf ───────────────────────────

// secondCousinOf(X,Y) :- parentOf(Z,X), secondAuntUncleOf(Z,Y)
MATCH (z:Person)-[:PARENT_OF]->(x:Person), (z)-[:SECOND_AUNT_UNCLE_OF]->(y:Person)
MERGE (x)-[:SECOND_COUSIN_OF]->(y);

// firstCousinOnceRemovedOf(X,Y) :- cousinOf(Y,Z), parentOf(Z,X)
MATCH (y:Person)-[:COUSIN_OF]->(z:Person)-[:PARENT_OF]->(x:Person)
MERGE (x)-[:FIRST_COUSIN_ONCE_REMOVED_OF]->(y);


// ── Gendered variants ─────────────────────────────────────────────────────────
// Gender is stored as the `female` boolean property on each Person node.
// female=true → female; female=false → male.

// parentOf → motherOf / fatherOf
MATCH (x:Person)-[:PARENT_OF]->(y:Person) WHERE x.female = true  MERGE (x)-[:MOTHER_OF]->(y);
MATCH (x:Person)-[:PARENT_OF]->(y:Person) WHERE x.female = false MERGE (x)-[:FATHER_OF]->(y);

// childOf → daughterOf / sonOf
MATCH (x:Person)-[:CHILD_OF]->(y:Person) WHERE x.female = true  MERGE (x)-[:DAUGHTER_OF]->(y);
MATCH (x:Person)-[:CHILD_OF]->(y:Person) WHERE x.female = false MERGE (x)-[:SON_OF]->(y);

// siblingOf → sisterOf / brotherOf
MATCH (x:Person)-[:SIBLING_OF]->(y:Person) WHERE x.female = true  MERGE (x)-[:SISTER_OF]->(y);
MATCH (x:Person)-[:SIBLING_OF]->(y:Person) WHERE x.female = false MERGE (x)-[:BROTHER_OF]->(y);

// grandparentOf → grandmotherOf / grandfatherOf
MATCH (x:Person)-[:GRANDPARENT_OF]->(y:Person) WHERE x.female = true  MERGE (x)-[:GRANDMOTHER_OF]->(y);
MATCH (x:Person)-[:GRANDPARENT_OF]->(y:Person) WHERE x.female = false MERGE (x)-[:GRANDFATHER_OF]->(y);

// grandchildOf → granddaughterOf / grandsonOf
MATCH (x:Person)-[:GRANDCHILD_OF]->(y:Person) WHERE x.female = true  MERGE (x)-[:GRANDDAUGHTER_OF]->(y);
MATCH (x:Person)-[:GRANDCHILD_OF]->(y:Person) WHERE x.female = false MERGE (x)-[:GRANDSON_OF]->(y);

// greatGrandparentOf → greatGrandmotherOf / greatGrandfatherOf
MATCH (x:Person)-[:GREAT_GRANDPARENT_OF]->(y:Person) WHERE x.female = true  MERGE (x)-[:GREAT_GRANDMOTHER_OF]->(y);
MATCH (x:Person)-[:GREAT_GRANDPARENT_OF]->(y:Person) WHERE x.female = false MERGE (x)-[:GREAT_GRANDFATHER_OF]->(y);

// greatGrandchildOf → greatGranddaughterOf / greatGrandsonOf
MATCH (x:Person)-[:GREAT_GRANDCHILD_OF]->(y:Person) WHERE x.female = true  MERGE (x)-[:GREAT_GRANDDAUGHTER_OF]->(y);
MATCH (x:Person)-[:GREAT_GRANDCHILD_OF]->(y:Person) WHERE x.female = false MERGE (x)-[:GREAT_GRANDSON_OF]->(y);

// auntUncleOf → auntOf / uncleOf
MATCH (x:Person)-[:AUNT_UNCLE_OF]->(y:Person) WHERE x.female = true  MERGE (x)-[:AUNT_OF]->(y);
MATCH (x:Person)-[:AUNT_UNCLE_OF]->(y:Person) WHERE x.female = false MERGE (x)-[:UNCLE_OF]->(y);

// nieceNephewOf → nieceOf / nephewOf
MATCH (x:Person)-[:NIECE_NEPHEW_OF]->(y:Person) WHERE x.female = true  MERGE (x)-[:NIECE_OF]->(y);
MATCH (x:Person)-[:NIECE_NEPHEW_OF]->(y:Person) WHERE x.female = false MERGE (x)-[:NEPHEW_OF]->(y);

// greatAuntUncleOf → greatAuntOf / greatUncleOf
MATCH (x:Person)-[:GREAT_AUNT_UNCLE_OF]->(y:Person) WHERE x.female = true  MERGE (x)-[:GREAT_AUNT_OF]->(y);
MATCH (x:Person)-[:GREAT_AUNT_UNCLE_OF]->(y:Person) WHERE x.female = false MERGE (x)-[:GREAT_UNCLE_OF]->(y);

// secondAuntUncleOf → secondAuntOf / secondUncleOf
MATCH (x:Person)-[:SECOND_AUNT_UNCLE_OF]->(y:Person) WHERE x.female = true  MERGE (x)-[:SECOND_AUNT_OF]->(y);
MATCH (x:Person)-[:SECOND_AUNT_UNCLE_OF]->(y:Person) WHERE x.female = false MERGE (x)-[:SECOND_UNCLE_OF]->(y);

// cousinOf → girlCousinOf / boyCousinOf
MATCH (x:Person)-[:COUSIN_OF]->(y:Person) WHERE x.female = true  MERGE (x)-[:GIRL_COUSIN_OF]->(y);
MATCH (x:Person)-[:COUSIN_OF]->(y:Person) WHERE x.female = false MERGE (x)-[:BOY_COUSIN_OF]->(y);

// secondCousinOf → girlSecondCousinOf / boySecondCousinOf
MATCH (x:Person)-[:SECOND_COUSIN_OF]->(y:Person) WHERE x.female = true  MERGE (x)-[:GIRL_SECOND_COUSIN_OF]->(y);
MATCH (x:Person)-[:SECOND_COUSIN_OF]->(y:Person) WHERE x.female = false MERGE (x)-[:BOY_SECOND_COUSIN_OF]->(y);

// firstCousinOnceRemovedOf → girlFirstCousinOnceRemovedOf / boyFirstCousinOnceRemovedOf
MATCH (x:Person)-[:FIRST_COUSIN_ONCE_REMOVED_OF]->(y:Person) WHERE x.female = true  MERGE (x)-[:GIRL_FIRST_COUSIN_ONCE_REMOVED_OF]->(y);
MATCH (x:Person)-[:FIRST_COUSIN_ONCE_REMOVED_OF]->(y:Person) WHERE x.female = false MERGE (x)-[:BOY_FIRST_COUSIN_ONCE_REMOVED_OF]->(y);
