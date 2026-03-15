# Family Tree Kinship Taxonomy

Two views of the taxonomy: the **class hierarchy** and the **property derivation chain**.

---

## Class Hierarchy

```
owl:Class
  └── ex:Person
        ├── ex:female
        └── ex:male
```

---

## Property Derivation Chain

Shows how 2 asserted base facts derive 47 relationships (13 gender-neutral + 28 gendered + 6 in-law).
Arrow (→) means "is derived from". Indentation shows dependency tiers.

```
ASSERTED (stored in data)
│
├── ex:parentOf ─────────────────────────────────────── ♀ ex:motherOf
│   │                                                    ♂ ex:fatherOf
│   │
│   ├─→ ex:childOf ─────────────────────────────────── ♀ ex:daughterOf
│   │                                                    ♂ ex:sonOf
│   │
│   ├─→ ex:grandparentOf ───────────────────────────── ♀ ex:grandmotherOf
│   │   │   (parentOf + parentOf)                        ♂ ex:grandfatherOf
│   │   │
│   │   ├─→ ex:grandchildOf ────────────────────────── ♀ ex:granddaughterOf
│   │   │       (inverse)                                ♂ ex:grandsonOf
│   │   │
│   │   └─→ ex:greatGrandparentOf ──────────────────── ♀ ex:greatGrandmotherOf
│   │       │   (parentOf + grandparentOf)               ♂ ex:greatGrandfatherOf
│   │       │
│   │       └─→ ex:greatGrandchildOf ───────────────── ♀ ex:greatGranddaughterOf
│   │               (inverse)                            ♂ ex:greatGrandsonOf
│   │
│   └─→ ex:siblingOf ──────────────────────────────── ♀ ex:sisterOf
│       │   (shared parent, X ≠ Y)                      ♂ ex:brotherOf
│       │
│       ├─→ ex:auntUncleOf ─────────────────────────── ♀ ex:auntOf
│       │   │   (siblingOf + parentOf)                   ♂ ex:uncleOf
│       │   │
│       │   ├─→ ex:nieceNephewOf ───────────────────── ♀ ex:nieceOf
│       │   │       (inverse)                            ♂ ex:nephewOf
│       │   │
│       │   └─→ ex:cousinOf ────────────────────────── ♀ ex:girlCousinOf
│       │       │   (parentOf + auntUncleOf)             ♂ ex:boyCousinOf
│       │       │
│       │       └─→ ex:firstCousinOnceRemovedOf ────── ♀ ex:girlFirstCousinOnceRemovedOf
│       │               (cousinOf + parentOf)            ♂ ex:boyFirstCousinOnceRemovedOf
│       │
│       └─→ ex:greatAuntUncleOf ────────────────────── ♀ ex:greatAuntOf
│           │   (siblingOf + grandparentOf)              ♂ ex:greatUncleOf
│           │
│           └─→ ex:secondAuntUncleOf ───────────────── ♀ ex:secondAuntOf
│               │   (parentOf + greatAuntUncleOf)        ♂ ex:secondUncleOf
│               │
│               └─→ ex:secondCousinOf ──────────────── ♀ ex:girlSecondCousinOf
│                       (parentOf + secondAuntUncleOf)   ♂ ex:boySecondCousinOf
│
└── ex:marriedTo (symmetric)
        │
        └─→ IN-LAW (marriedTo + parentOf/childOf/siblingOf + gender)
              ├── ex:fatherInLawOf        (parentOf + marriedTo + ♂)
              ├── ex:motherInLawOf        (parentOf + marriedTo + ♀)
              ├── ex:sonInLawOf           (marriedTo + childOf + ♂)
              ├── ex:daughterInLawOf      (marriedTo + childOf + ♀)
              ├── ex:brotherInLawOf       (marriedTo + siblingOf + ♂, two paths)
              └── ex:sisterInLawOf        (marriedTo + siblingOf + ♀, two paths)
```

---

## Derivation Tiers

Rules fire in dependency order. Each tier uses predicates from earlier tiers.

```
Tier 0 (asserted)    parentOf, marriedTo
                         │
Tier 1 (direct)      childOf, grandparentOf, siblingOf
                         │
Tier 2               greatGrandparentOf, grandchildOf
                         │
Tier 3               greatGrandchildOf
                         │
Tier 4               auntUncleOf, greatAuntUncleOf
                         │
Tier 5               nieceNephewOf, secondAuntUncleOf, cousinOf
                         │
Tier 6               secondCousinOf, firstCousinOnceRemovedOf
                         │
Gendered             28 variants (each gender-neutral + rdf:type → ♀/♂)
                         │
In-law               fatherInLawOf, motherInLawOf, sonInLawOf,
                     daughterInLawOf, brotherInLawOf, sisterInLawOf
```

---

## Counts

```
Asserted base facts:     2   (parentOf, marriedTo)
Derived gender-neutral: 13
Derived gendered:       28
Derived in-law:          6
                       ────
Total edge types:       49
```
