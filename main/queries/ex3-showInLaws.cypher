// =============================================================================
// ex3-showInLaws.cypher
// Author:  Kent Stroker
// Date:    2026-03-14
//
// Lists all in-law relationships in the family tree, showing each person,
// the relationship type, and their in-law's name.
//
// The 6 in-law relationship types:
//   FATHER_IN_LAW_OF, MOTHER_IN_LAW_OF, SON_IN_LAW_OF, DAUGHTER_IN_LAW_OF,
//   BROTHER_IN_LAW_OF, SISTER_IN_LAW_OF
//
// Usage: Run in Neo4j Browser.
// Requires: data loaded and neo4j-materialize_new_rules.cypher executed.
// =============================================================================

MATCH (person:Person)-[r]->(inLaw:Person)
WHERE type(r) IN [
  'FATHER_IN_LAW_OF',
  'MOTHER_IN_LAW_OF',
  'SON_IN_LAW_OF',
  'DAUGHTER_IN_LAW_OF',
  'BROTHER_IN_LAW_OF',
  'SISTER_IN_LAW_OF'
]
RETURN person.fullName AS personName,
       type(r)         AS relationship,
       inLaw.fullName  AS inLawName
ORDER BY relationship, personName;
