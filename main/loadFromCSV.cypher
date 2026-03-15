// loadFromCSV.cypher
// Bulk-loads family tree data from CSV files into Neo4j.
//
// Paste each section into the Neo4j Browser and run in order.
// Each section is a separate statement -- run them one at a time.
//
// Requires Neo4j 5.x+.

// -- Step 1: Constraint -------------------------------------------------------

CREATE CONSTRAINT person_id IF NOT EXISTS FOR (p:Person) REQUIRE p.id IS UNIQUE;

// -- Load persons from persons.csv ------------------------------------

LOAD CSV WITH HEADERS FROM 'file:///persons.csv' AS row
CALL {
  WITH row
  MERGE (p:Person {id: row.id})
  SET p.givenName = row.givenName,
      p.surname   = row.surname,
      p.fullName  = row.fullName,
      p.female    = (row.female = 'true'),
      p.male      = (row.male   = 'true'),
      p.dateOfBirth  = CASE WHEN row.dateOfBirth  <> '' THEN date(row.dateOfBirth)  ELSE null END,
      p.dateOfDeath  = CASE WHEN row.dateOfDeath  <> '' THEN date(row.dateOfDeath)  ELSE null END
} IN TRANSACTIONS OF 500 ROWS;

// -- Load PARENT_OF edges from parent_of.csv --------------------------

LOAD CSV WITH HEADERS FROM 'file:///parent_of.csv' AS row
CALL {
  WITH row
  MATCH (a:Person {id: row.from_id})
  MATCH (b:Person {id: row.to_id})
  MERGE (a)-[:PARENT_OF]->(b)
} IN TRANSACTIONS OF 500 ROWS;

// -- Load MARRIED_TO edges from married_to.csv ------------------------

LOAD CSV WITH HEADERS FROM 'file:///married_to.csv' AS row
CALL {
  WITH row
  MATCH (a:Person {id: row.from_id})
  MATCH (b:Person {id: row.to_id})
  MERGE (a)-[:MARRIED_TO]->(b)
} IN TRANSACTIONS OF 500 ROWS;

