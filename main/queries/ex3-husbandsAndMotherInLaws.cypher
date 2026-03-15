// =============================================================================
// ex3-husbandsAndMotherInLaws.cypher
// Author:  Kent Stroker
// Date:    2026-03-14
//
// Lists all husbands and their mothers-in-law.
// Uses the materialized MOTHER_IN_LAW_OF relationship.
//
// Usage: Run in Neo4j Browser.
// Requires: data loaded and neo4j-materialize_new_rules.cypher executed.
// =============================================================================

MATCH (motherInLaw:Person)-[:MOTHER_IN_LAW_OF]->(husband:Person {female: false})
RETURN husband.fullName    AS husbandName,
       motherInLaw.fullName AS motherInLawName
ORDER BY husbandName;