# Family Tree Domain Vocabulary

Namespace: `http://example.org/family/` (prefix `ex:`)

Formal definition: `schema.ttl` (OWL ontology)
Inference rules: `kinship.pie` (GraphDB) / `neo4j-materialize_rules.cypher` (Neo4j)

---

## Classes

| Class       | Parent    | Description                          |
|-------------|-----------|--------------------------------------|
| `ex:Person` | owl:Class | Any individual in the family tree    |
| `ex:female` | ex:Person | A female person (subclass of Person) |
| `ex:male`   | ex:Person | A male person (subclass of Person)   |

## Datatype Properties

| Property         | Domain    | Range      | Description                              |
|------------------|-----------|------------|------------------------------------------|
| `ex:givenName`   | ex:Person | xsd:string | First name                               |
| `ex:surname`     | ex:Person | xsd:string | Family name (current/active)             |
| `ex:dateOfBirth` | ex:Person | xsd:date   | Birth date (YYYY-MM-DD); always present  |
| `ex:dateOfDeath` | ex:Person | xsd:date   | Death date (YYYY-MM-DD); absent = living |

## Object Properties — Base (Asserted)

These two relationships are explicitly stored in the generated data.
All other relationships are **derived** by inference rules.

| Property       | Symmetric | Description                                |
|----------------|:---------:|--------------------------------------------|
| `ex:parentOf`  |     No    | Direct parent-child link (asserted)        |
| `ex:marriedTo` |    Yes    | Spouse link (one direction stored, symmetric inferred) |

## Object Properties — Derived (13 Gender-Neutral)

| Property                        | Symmetric | Derived From                               |
|---------------------------------|:---------:|--------------------------------------------|
| `ex:childOf`                    |     No    | inverse of parentOf                        |
| `ex:siblingOf`                  |    Yes    | shared parent, different person             |
| `ex:grandparentOf`              |     No    | parentOf + parentOf                        |
| `ex:grandchildOf`               |     No    | inverse of grandparentOf                   |
| `ex:greatGrandparentOf`         |     No    | parentOf + grandparentOf                   |
| `ex:greatGrandchildOf`          |     No    | inverse of greatGrandparentOf              |
| `ex:auntUncleOf`                |     No    | siblingOf + parentOf                       |
| `ex:nieceNephewOf`              |     No    | inverse of auntUncleOf                     |
| `ex:greatAuntUncleOf`           |     No    | siblingOf + grandparentOf                  |
| `ex:secondAuntUncleOf`          |     No    | parentOf + greatAuntUncleOf                |
| `ex:cousinOf`                   |    Yes    | parentOf + auntUncleOf                     |
| `ex:secondCousinOf`             |    Yes    | parentOf + secondAuntUncleOf               |
| `ex:firstCousinOnceRemovedOf`   |     No    | cousinOf + parentOf                        |

## Object Properties — Derived (28 Gendered)

Each gender-neutral property specializes into female and male variants
via the person's `rdf:type` (ex:female or ex:male).

| Gender-Neutral          | Female Variant                       | Male Variant                        |
|-------------------------|--------------------------------------|-------------------------------------|
| `ex:parentOf`           | `ex:motherOf`                        | `ex:fatherOf`                       |
| `ex:childOf`            | `ex:daughterOf`                      | `ex:sonOf`                          |
| `ex:siblingOf`          | `ex:sisterOf`                        | `ex:brotherOf`                      |
| `ex:grandparentOf`      | `ex:grandmotherOf`                   | `ex:grandfatherOf`                  |
| `ex:grandchildOf`       | `ex:granddaughterOf`                 | `ex:grandsonOf`                     |
| `ex:greatGrandparentOf` | `ex:greatGrandmotherOf`              | `ex:greatGrandfatherOf`             |
| `ex:greatGrandchildOf`  | `ex:greatGranddaughterOf`            | `ex:greatGrandsonOf`                |
| `ex:auntUncleOf`        | `ex:auntOf`                          | `ex:uncleOf`                        |
| `ex:nieceNephewOf`      | `ex:nieceOf`                         | `ex:nephewOf`                       |
| `ex:greatAuntUncleOf`   | `ex:greatAuntOf`                     | `ex:greatUncleOf`                   |
| `ex:secondAuntUncleOf`  | `ex:secondAuntOf`                    | `ex:secondUncleOf`                  |
| `ex:cousinOf`           | `ex:girlCousinOf`                    | `ex:boyCousinOf`                    |
| `ex:secondCousinOf`     | `ex:girlSecondCousinOf`              | `ex:boySecondCousinOf`              |
| `ex:firstCousinOnceRemovedOf` | `ex:girlFirstCousinOnceRemovedOf` | `ex:boyFirstCousinOnceRemovedOf` |

## Object Properties — Derived (6 In-Law)

The six standard in-law designations used in genealogy. Derived from
`marriedTo` combined with `parentOf`, `childOf`, or `siblingOf` plus gender.
Brother/sister-in-law each cover two derivation paths: spouse's sibling AND sibling's spouse.

| Property                | Derived From                                   |
|-------------------------|------------------------------------------------|
| `ex:fatherInLawOf`      | parentOf + marriedTo + male                    |
| `ex:motherInLawOf`      | parentOf + marriedTo + female                  |
| `ex:sonInLawOf`         | marriedTo + childOf + male                     |
| `ex:daughterInLawOf`    | marriedTo + childOf + female                   |
| `ex:brotherInLawOf`     | marriedTo + siblingOf + male (two paths)       |
| `ex:sisterInLawOf`      | marriedTo + siblingOf + female (two paths)     |

## Summary

| Category              | Count |
|-----------------------|------:|
| Classes               |     3 |
| Datatype properties   |     4 |
| Base object properties|     2 |
| Derived gender-neutral|    13 |
| Derived gendered      |    28 |
| Derived in-law        |     6 |
| **Total predicates**  |**56** |
| **Total edge types**  |**49** |
