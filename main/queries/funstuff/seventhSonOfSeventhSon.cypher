// =============================================================================
// seventhSonOfSeventhSon.cypher
// Find any person who is a 7th son of a 7th son.
// A "7th son" means the father has at least 7 male children and this son
// is the 7th by birth order (dateOfBirth).
// Run in Neo4j Browser at http://localhost:7474
// =============================================================================

// Find fathers with 7+ sons, identify the 7th son by birth order
MATCH (grandfather)-[:PARENT_OF]->(father:Person {male: true})
MATCH (father)-[:PARENT_OF]->(son:Person {male: true})
WITH grandfather, father, son
ORDER BY son.dateOfBirth
WITH grandfather, father, collect(son) AS sons
WHERE size(sons) >= 7
WITH grandfather, father, sons[6] AS seventhSon

// Now check if father is himself a 7th son
MATCH (grandfather)-[:PARENT_OF]->(uncle:Person {male: true})
WITH grandfather, father, seventhSon, uncle
ORDER BY uncle.dateOfBirth
WITH grandfather, father, seventhSon, collect(uncle) AS fatherBrothers
WHERE size(fatherBrothers) >= 7
  AND fatherBrothers[6] = father
RETURN grandfather.fullName AS grandfather,
       father.fullName AS father,
       seventhSon.fullName AS seventhSon,
       seventhSon.dateOfBirth AS dateOfBirth;
