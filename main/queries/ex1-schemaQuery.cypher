// =============================================================================
// ex1-schemaQuery.cypher — Exercise 1: Schema Inspection
// Author:  Kent Stroker
//
// Shows the implicit schema of the Neo4j graph: which node labels connect
// via which relationship types.  This is the closest Cypher equivalent to
// querying the OWL triples in GraphDB (ex1-schemaQuery.sparql).
//
// Key contrast: in GraphDB the schema is queryable data (OWL triples with
// domain, range, symmetry declarations).  In Neo4j the schema is metadata
// accessible only through system procedures — you cannot ask "what is the
// domain and range of PARENT_OF?" because Neo4j does not store that concept.
//
// Usage: Run in Neo4j Browser (returns table).
// Requires: data loaded (loadFromCSV.cypher or data-000.cypher).
// =============================================================================

CALL db.schema.visualization()
YIELD nodes, relationships
UNWIND relationships AS rel
RETURN
  labels(startNode(rel))[0] AS FromLabel,
  type(rel)                 AS Relationship,
  labels(endNode(rel))[0]   AS ToLabel
ORDER BY FromLabel, Relationship;