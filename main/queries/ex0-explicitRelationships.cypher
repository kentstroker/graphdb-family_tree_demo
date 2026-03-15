// =============================================================================
// ex0-explicitRelationships.cypher — Exercise 0: What's actually in the data?
// Author:  Kent Stroker
//
// Counts the distinct relationship types that exist between persons.
//
// Before materialization, this returns exactly 2 relationship types:
//   PARENT_OF and MARRIED_TO
//
// After running neo4j-materialize_rules.cypher, this will show all 49
// relationship types.  This is the Neo4j equivalent of the SPARQL query
// that uses GraphDB's explicit graph to filter out inferred triples.
//
// Usage: Run in Neo4j Browser (returns table).
// Requires: loadFromCSV.cypher (or data-000.cypher) loaded.
// =============================================================================

MATCH (p:Person)-[r]->(q:Person)
RETURN type(r) AS Relationship, COUNT(*) AS Count
ORDER BY Relationship;