# Kinship Relationship Vocabulary

This document describes the complete set of kinship relationships used in this demo — what they mean, how they are derived, and how they map to both the GraphDB (RDF/SHACL) and Neo4j (LPG/Cypher) implementations.

---

## Base Facts (Asserted, Not Inferred)

Only two relationships are directly stored in the generated data. Everything else is derived from them.

| Relationship | Description |
|---|---|
| `parentOf` | Directly asserted in the source data. The foundation of the entire derivation chain — all kinship relationships except spouse are derived from this one, combined with gender information. |
| `marriedTo` | Directly asserted. Written in one direction only per pair; symmetry (the reverse direction) is inferred by GraphDB or materialized explicitly in Neo4j. |

Gender is encoded as class membership (`ex:female`, `ex:male` in RDF; a `female` boolean property in Neo4j) and is used to specialize all gender-neutral relationships into their gendered variants.

---

## Gender-Neutral Relationships

These relationships are derived purely from the structure of the `parentOf` graph, without reference to gender. They are the backbone from which all gendered variants are produced.

### Top-Down (Ancestor Side)

These relationships flow *downward* from an ancestor toward a descendant.

| Relationship | Definition |
|---|---|
| `grandparentOf` | X is a grandparent of Y if X is a parent of someone who is also a parent of Y. |
| `greatGrandparentOf` | X is a great-grandparent of Y if X is a parent of someone who is a grandparent of Y. |
| `auntUncleOf` | X is an aunt or uncle of Y if X is a sibling of someone who is a parent of Y. |
| `greatAuntUncleOf` | X is a great-aunt or great-uncle of Y if X is a sibling of someone who is a grandparent of Y. |
| `secondAuntUncleOf` | X is a second aunt or uncle of Y if X's parent is a great-aunt or great-uncle of Y. |

### Bottom-Up (Descendant Side)

These are the inverses of the top-down relationships — they flow *upward* from a descendant toward an ancestor.

| Relationship | Definition |
|---|---|
| `childOf` | Inverse of `parentOf`. X is a child of Y if Y is a parent of X. |
| `grandchildOf` | Inverse of `grandparentOf`. |
| `greatGrandchildOf` | Inverse of `greatGrandparentOf`. |
| `nieceNephewOf` | Inverse of `auntUncleOf`. X is a niece or nephew of Y if Y is an aunt or uncle of X. |

### Sideways (Same-Generation / Cross-Generation)

These relationships link people who are in the same generation or who share a generational offset through a cousin relationship.

| Relationship | Definition |
|---|---|
| `siblingOf` | X and Y share at least one common parent and are not the same person. Symmetric — if X is a sibling of Y, then Y is a sibling of X. |
| `cousinOf` | X's parent is an aunt or uncle of Y. Symmetric. |
| `secondCousinOf` | X's parent is a second aunt or uncle of Y. Symmetric. |
| `firstCousinOnceRemovedOf` | Y is a cousin of someone who is a parent of X — one generation separates X from a cousin relationship. Not fully symmetric in the usual sense; the "removed" indicates a generational gap. |

---

## Gendered Relationships

Every gender-neutral relationship above has two gendered specializations — one for female subjects, one for male. These are inferred by combining the gender-neutral relationship with the gender of the *subject* (the person on the left side of the relationship).

In GraphDB, this is expressed as SHACL rules that match the neutral edge plus a class assertion (`?x a ex:female`). In Neo4j, it is expressed as Cypher `WHERE` clauses on the boolean `female` property.

| Gendered Relationship | Inferred From |
|---|---|
| `motherOf` / `fatherOf` | `parentOf` + female / male |
| `daughterOf` / `sonOf` | `childOf` + female / male |
| `sisterOf` / `brotherOf` | `siblingOf` + female / male |
| `grandmotherOf` / `grandfatherOf` | `grandparentOf` + female / male |
| `granddaughterOf` / `grandsonOf` | `grandchildOf` + female / male |
| `greatGrandmotherOf` / `greatGrandfatherOf` | `greatGrandparentOf` + female / male |
| `greatGranddaughterOf` / `greatGrandsonOf` | `greatGrandchildOf` + female / male |
| `auntOf` / `uncleOf` | `auntUncleOf` + female / male |
| `greatAuntOf` / `greatUncleOf` | `greatAuntUncleOf` + female / male |
| `secondAuntOf` / `secondUncleOf` | `secondAuntUncleOf` + female / male |
| `nieceOf` / `nephewOf` | `nieceNephewOf` + female / male |
| `girlCousinOf` / `boyCousinOf` | `cousinOf` + female / male |
| `girlSecondCousinOf` / `boySecondCousinOf` | `secondCousinOf` + female / male |
| `girlFirstCousinOnceRemovedOf` / `boyFirstCousinOnceRemovedOf` | `firstCousinOnceRemovedOf` + female / male |

---

## Derivation Chain

The full derivation chain illustrates the dependency order — each tier depends on the one above it. This ordering matters critically in Neo4j (Cypher statements must run in this order) and is handled automatically by GraphDB's reasoning engine.

```
parentOf                                           ← only asserted base fact
  │
  ├─→ childOf                                      (inverse)
  ├─→ siblingOf                                    (shared parent)
  ├─→ grandparentOf
  │     ├─→ grandchildOf                           (inverse)
  │     └─→ greatGrandparentOf
  │           └─→ greatGrandchildOf                (inverse)
  │
  ├─→ siblingOf + parentOf   → auntUncleOf
  │     └─→ nieceNephewOf                          (inverse)
  │
  ├─→ siblingOf + grandparentOf → greatAuntUncleOf
  │     └─→ parentOf + greatAuntUncleOf → secondAuntUncleOf
  │
  ├─→ parentOf + auntUncleOf → cousinOf
  │     └─→ cousinOf + parentOf → firstCousinOnceRemovedOf
  │
  └─→ parentOf + secondAuntUncleOf → secondCousinOf

All of the above + gender class → gendered variants
(motherOf, fatherOf, auntOf, uncleOf, cousinOf variants, etc.)
```

---

## Count Summary

| Category | Count |
|---|---|
| Base asserted relationships | 2 (`parentOf`, `marriedTo`) |
| Gender-neutral derived relationships | 13 |
| Gendered derived relationships | 28 (14 pairs) |
| In-law derived relationships | 6 |
| **Total relationship types in vocabulary** | **49** |

This illustrates the core value proposition of inference: two stored relationship types generate a vocabulary of 49 distinct kinship edges automatically, with no additional data entry required.
