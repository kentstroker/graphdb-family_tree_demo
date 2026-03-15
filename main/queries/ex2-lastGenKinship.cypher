// =============================================================================
// ex2-lastGenKinship.cypher — Exercise 2: Adding Data (Incremental Load)
// Author:  Kent Stroker
//
// Shows all kinship relationships for the last generation — people born
// after 2000 who have no children of their own.  These are the people
// added in the incremental load (lastgen CSVs or data-000-lastgen.cypher).
//
// The key observation: this query is run RIGHT AFTER loading the last-
// generation data — before neo4j-materialize_rules.cypher has been re-run.
// The Relationship column will be EMPTY for every row because Neo4j only
// stores what you explicitly put in.  No SIBLING_OF, GRANDCHILD_OF, or
// COUSIN_OF edges exist yet — only raw PARENT_OF and MARRIED_TO.
//
// After running neo4j-materialize_rules.cypher, re-run this query to see
// the full set of derived relationships appear.
//
// Compare with ex2-lastGenKinship.sparql in GraphDB, where every row
// already has a Relationship value thanks to automatic inference.
//
// Usage: Run in Neo4j Browser (returns table).
// Requires: loadFromCSV.cypher + loadIncrementalCSV.cypher loaded
//           (or data-000.cypher + data-000-lastgen.cypher).
// =============================================================================

// Find last-gen people (born after 2000, no children) and their kinship edges
MATCH (person:Person)
WHERE person.dateOfBirth > date('2000-01-01')
  AND NOT EXISTS { MATCH (person)-[:PARENT_OF]->() }

// Look for any kinship relationship (everything except base edges)
OPTIONAL MATCH (person)-[k]->(related:Person)
  WHERE NOT type(k) IN ['PARENT_OF', 'MARRIED_TO']

RETURN
  person.fullName  AS PersonName,
  COALESCE(
    REPLACE(type(k), '_', ' '),
    ''
  )                AS Relationship,
  related.fullName AS RelatedToName
ORDER BY PersonName, Relationship, RelatedToName;