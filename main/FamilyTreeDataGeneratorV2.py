#!/usr/bin/env python3
# =============================================================================
# FamilyTreeDataGeneratorV2.py
# Author:  Kent Stroker
# Date:    2026-03-11
#
# Generates a single-lineage family tree as RDF/Turtle (.ttl) starting from
# one founding couple.  Every child marries a unique outside spouse (leaf node
# with no parents).  The graph is a pure DAG — branches only diverge, never
# reconverge.
#
# Only two relationships are asserted: ex:parentOf and ex:marriedTo.
# All 47 derived kinship relationships are produced by inference rules.
#
# Usage:
#   python3 FamilyTreeDataGeneratorV2.py \
#     --out-dir out_graphdb \
#     --num-samples 1 \
#     --seed 1 \
#     --min-children 2 \
#     --max-children 8 \
#     --num-generations 5 \
#     --min-seventh-sons 2
# =============================================================================
from __future__ import annotations

import argparse
import os
import random
import shutil
from dataclasses import dataclass, field
from typing import Dict, List, Optional, Set, Tuple

from faker import Faker

# Reference year for computing ages and death probabilities
_CURRENT_YEAR = 2026
# Average years between adjacent generations
_GENERATION_SPAN = 22
# Average birth year for the youngest (leaf) generation
_LEAF_BIRTH_CENTER = 2010

EX = "http://example.org/family/"


def iri(path: str) -> str:
    return f"<{EX}{path}>"


def ttl_str(s: str) -> str:
    return '"' + s.replace("\\", "\\\\").replace('"', '\\"') + '"'


@dataclass
class Person:
    id: int
    given_name: str
    surname: str          # active surname (father's surname for children; kept for men; acquired for married women)
    birth_surname: str    # maiden name — used internally for uniqueness tracking
    female: bool
    generation: int       # 0 = oldest, increases toward leaves
    is_lineage: bool      # True = descended from founding couple; False = incoming spouse

    parents: List[int] = field(default_factory=list)
    children: List[int] = field(default_factory=list)
    married_to: Optional[int] = None
    date_of_birth: Optional[str] = None   # YYYY-MM-DD
    date_of_death: Optional[str] = None   # YYYY-MM-DD; None means living

    @property
    def male(self) -> bool:
        return not self.female

    @property
    def full_name(self) -> str:
        return f"{self.given_name} {self.surname}"


class UniqueNameSource:
    """Generates unique given+surname combinations via faker."""

    def __init__(self, seed: int, locale: Optional[str] = None):
        self.faker = Faker(locale) if locale else Faker()
        self.faker.seed_instance(seed)
        self.used_full_names: Dict[str, int] = {}

    def given_name(self, female: bool) -> str:
        return (self.faker.first_name_female() if female else self.faker.first_name_male()).strip()

    def surname(self) -> str:
        return self.faker.last_name().strip()

    def unique_given(self, female: bool, surname: str) -> str:
        """Return a given name that forms a unique full name with *surname*."""
        for _ in range(500):
            given = self.given_name(female)
            full = f"{given} {surname}"
            if full not in self.used_full_names:
                self.used_full_names[full] = 1
                return given
        # Fallback: append numeric suffix if Faker's pool is exhausted
        given = self.given_name(female)
        suffix = 2
        while f"{given}{suffix} {surname}" in self.used_full_names:
            suffix += 1
        self.used_full_names[f"{given}{suffix} {surname}"] = 1
        return f"{given}{suffix}"


class UniqueSurnameSource:
    """Ensures every incoming spouse brings a surname never seen in the tree."""

    def __init__(self, names: UniqueNameSource):
        self.names = names
        self.used_surnames: Set[str] = set()

    def reserve(self, surname: str) -> None:
        """Mark a surname as taken (e.g. the founding couple's surnames)."""
        self.used_surnames.add(surname.lower())

    def next_surname(self) -> str:
        """Return a surname not yet used anywhere in the tree.

        If Faker's pool is exhausted after 500 raw attempts, fall back to
        appending a numeric suffix (e.g. "Smith2", "Smith3") to make a
        previously-seen surname unique.
        """
        for _ in range(500):
            s = self.names.surname()
            if s.lower() not in self.used_surnames:
                self.used_surnames.add(s.lower())
                return s
        # Fallback: recycle the last generated surname with a numeric suffix
        base = self.names.surname()
        suffix = 2
        while f"{base}{suffix}".lower() in self.used_surnames:
            suffix += 1
        unique = f"{base}{suffix}"
        self.used_surnames.add(unique.lower())
        return unique


def assign_dates(people: List[Person], num_generations: int, rng: random.Random) -> None:
    """
    Assign date_of_birth and date_of_death to every person.

    Birth years are anchored to the leaf generation (~2010) and step back by
    _GENERATION_SPAN years per generation.  Incoming spouses are placed at the
    same generation tier as the lineage person they marry.

    Death probability is age-based (same model as V1).
    """
    for person in people:
        depth = (num_generations - 1) - person.generation
        center_year = _LEAF_BIRTH_CENTER - depth * _GENERATION_SPAN
        birth_year = center_year + rng.randint(-5, 5)
        birth_month = rng.randint(1, 12)
        birth_day = rng.randint(1, 28)
        person.date_of_birth = f"{birth_year}-{birth_month:02d}-{birth_day:02d}"

        age = _CURRENT_YEAR - birth_year
        if age < 50:
            death_prob = 0.0
        elif age < 65:
            death_prob = 0.05
        elif age < 75:
            death_prob = 0.20
        elif age < 85:
            death_prob = 0.55
        else:
            death_prob = 0.85

        if rng.random() < death_prob:
            lifespan = int(rng.gauss(78, 8))
            lifespan = max(lifespan, 55)
            death_year = birth_year + lifespan
            if death_year <= _CURRENT_YEAR:
                death_month = rng.randint(1, 12)
                death_day = rng.randint(1, 28)
                person.date_of_death = f"{death_year}-{death_month:02d}-{death_day:02d}"


def generate_family_tree(
    *,
    seed: int,
    min_children: int = 2,
    max_children: int = 8,
    num_generations: int = 5,
    childless_from_gen: int = 3,
    childless_prob: float = 0.05,
    seventh_son: bool = False,
    faker_locale: Optional[str] = None,
) -> List[Person]:
    """
    Build a single-lineage family tree starting from one founding couple.

    When *seventh_son* is True, the founding couple is forced to have at
    least 7 sons, and the 7th son's family is also forced to have at least
    7 sons — guaranteeing one "7th son of a 7th son" in the tree.

    Couples at generation >= *childless_from_gen* have a *childless_prob*
    chance (default 5%) of producing zero children even when min_children > 0.

    Every child at every generation marries a unique outside spouse (a leaf
    node with no parents or ancestry).  Children inherit the father's surname.
    Female spouses acquire their husband's surname upon marriage; their maiden
    name is tracked internally for uniqueness.

    The last generation's children marry but produce no children.
    """
    rng = random.Random(seed)
    names = UniqueNameSource(seed=seed, locale=faker_locale)
    surnames = UniqueSurnameSource(names)
    people: List[Person] = []
    next_id = 0

    def add_person(
        generation: int,
        female: bool,
        surname: str,
        birth_surname: str,
        is_lineage: bool,
        parents: Optional[List[int]] = None,
    ) -> Person:
        nonlocal next_id
        given = names.unique_given(female, surname)
        p = Person(
            id=next_id,
            given_name=given,
            surname=surname,
            birth_surname=birth_surname,
            female=female,
            generation=generation,
            is_lineage=is_lineage,
            parents=parents or [],
        )
        next_id += 1
        people.append(p)
        return p

    def create_spouse(generation: int, for_person: Person) -> Person:
        """Create a unique outside spouse for *for_person*."""
        spouse_female = not for_person.female
        spouse_birth_surname = surnames.next_surname()

        if spouse_female:
            # Female spouse: born with her maiden name, acquires husband's surname
            spouse_surname = for_person.surname
        else:
            # Male spouse: keeps his own surname
            spouse_surname = spouse_birth_surname

        spouse = add_person(
            generation=generation,
            female=spouse_female,
            surname=spouse_surname,
            birth_surname=spouse_birth_surname,
            is_lineage=False,
        )
        for_person.married_to = spouse.id
        spouse.married_to = for_person.id

        # If the lineage person is female, she acquires husband's surname
        if for_person.female:
            for_person.surname = spouse.surname

        return spouse

    def make_children(father: Person, mother: Person, child_generation: int,
                      count: int, force_male_first_n: int = 0) -> List[Person]:
        children = []
        for i in range(count):
            if i < force_male_first_n:
                female = False
            else:
                female = rng.random() > 0.5
            child = add_person(
                generation=child_generation,
                female=female,
                surname=father.surname,
                birth_surname=father.surname,
                is_lineage=True,
                parents=[father.id, mother.id],
            )
            father.children.append(child.id)
            mother.children.append(child.id)
            children.append(child)
        return children

    # --- Generation 0: founding couple ---
    husband_surname = surnames.next_surname()
    wife_birth_surname = surnames.next_surname()

    husband = add_person(0, female=False, surname=husband_surname,
                         birth_surname=husband_surname, is_lineage=True)
    wife = add_person(0, female=True, surname=husband_surname,
                      birth_surname=wife_birth_surname, is_lineage=True)
    husband.married_to = wife.id
    wife.married_to = husband.id

    # --- Generation 0: founding couple's children ---
    # When seventh_son is requested, ensure at least 7 sons in the first family
    n_children = rng.randint(min_children, max_children)
    if seventh_son:
        n_children = max(n_children, 7)
        current_children = make_children(husband, wife, 1, n_children, force_male_first_n=7)
        seventh_son_person = current_children[6]   # the 7th son (index 6)
    else:
        current_children = make_children(husband, wife, 1, n_children)
        seventh_son_person = None

    # --- Generations 1 through num_generations-1 ---
    for gen in range(1, num_generations):
        next_children: List[Person] = []

        for child in current_children:
            spouse = create_spouse(gen, child)

            # Determine father/mother for children
            if child.male:
                father, mother = child, spouse
            else:
                father, mother = spouse, child

            # Last generation: married but no children
            if gen < num_generations - 1:
                # Childless probability kicks in from the configured generation
                if gen >= childless_from_gen and rng.random() < childless_prob:
                    n = 0
                else:
                    n = rng.randint(min_children, max_children)

                # Force the 7th son's family to also produce 7+ sons
                force_male = 0
                if seventh_son_person is not None and child.id == seventh_son_person.id:
                    n = max(n, 7)
                    force_male = 7
                    seventh_son_person = None  # only inject once

                grandkids = make_children(father, mother, gen + 1, n, force_male_first_n=force_male)
                next_children.extend(grandkids)

        current_children = next_children

    assign_dates(people, num_generations, rng)

    # Ensure children's DOBs are in creation order (by ID) within each family.
    # assign_dates randomizes DOBs within a ±5-year window, so the Nth child
    # by creation order may not be the Nth by birth date.  Sorting the DOBs
    # to match creation order keeps the "7th son" by index also the 7th by DOB.
    by_id: Dict[int, Person] = {p.id: p for p in people}
    for p in people:
        if not p.children:
            continue
        kids = [by_id[cid] for cid in p.children]
        kids.sort(key=lambda c: c.id)
        dobs = sorted(k.date_of_birth for k in kids)
        for kid, dob in zip(kids, dobs):
            kid.date_of_birth = dob

    return people


def count_seventh_son_of_seventh_son(people: List[Person]) -> int:
    """Return the number of males who are a 7th son of a 7th son."""
    by_id: Dict[str, Person] = {p.id: p for p in people}

    def son_rank(person: Person) -> Optional[int]:
        """Return 1-based rank among male siblings by DOB, or None if no parents."""
        if not person.parents or not person.male:
            return None
        # Find a parent and get their children
        parent = by_id[person.parents[0]]
        sons = [by_id[cid] for cid in parent.children if by_id[cid].male]
        # Sort by date of birth to match the SPARQL query's birth-order logic
        sons.sort(key=lambda p: p.date_of_birth or "")
        for i, s in enumerate(sons):
            if s.id == person.id:
                return i + 1
        return None

    count = 0
    for person in people:
        rank = son_rank(person)
        if rank == 7:
            father_id = next((pid for pid in person.parents if by_id[pid].male), None)
            if father_id and son_rank(by_id[father_id]) == 7:
                count += 1
    return count


def write_data_ttl(
    path: str,
    people: List[Person],
    sample_index: int,
    *,
    generations: Optional[set] = None,
) -> None:
    """Write a TTL file containing only persons in the given generations.

    If *generations* is None every person is included.
    Cross-boundary edges are assigned to the file that contains the
    later-generation endpoint.
    """
    by_id: Dict[int, Person] = {p.id: p for p in people}

    def include_person(p: Person) -> bool:
        return generations is None or p.generation in generations

    def p_iri(local_id: int) -> str:
        return iri(f"person/{sample_index}-{local_id}")

    lines: List[str] = [
        "@prefix ex:   <http://example.org/family/> .",
        "@prefix rdf:  <http://www.w3.org/1999/02/22-rdf-syntax-ns#> .",
        "@prefix rdfs: <http://www.w3.org/2000/01/rdf-schema#> .",
        "@prefix xsd:  <http://www.w3.org/2001/XMLSchema#> .",
        "",
    ]

    # Person nodes
    for p in people:
        if not include_person(p):
            continue
        gender_class = "ex:female" if p.female else "ex:male"
        lines.append(f"{p_iri(p.id)} rdf:type ex:Person, {gender_class} ;")
        lines.append(f"  ex:givenName {ttl_str(p.given_name)} ;")
        lines.append(f"  ex:surname {ttl_str(p.surname)} ;")
        lines.append(f"  rdfs:label {ttl_str(p.full_name)} ;")
        if p.date_of_birth is not None:
            lines.append(f"  ex:dateOfBirth \"{p.date_of_birth}\"^^xsd:date ;")
        if p.date_of_death is not None:
            lines.append(f"  ex:dateOfDeath \"{p.date_of_death}\"^^xsd:date ;")
        lines.append(f"  .")
        lines.append("")

    # parentOf triples — assigned to the file containing the child
    for p in people:
        for c_id in p.children:
            child = by_id[c_id]
            if include_person(child):
                lines.append(f"{p_iri(p.id)} ex:parentOf {p_iri(c_id)} .")
    lines.append("")

    # marriedTo triples (one direction) — assigned to the later-generation spouse
    seen: set[Tuple[int, int]] = set()
    for p in people:
        if p.married_to is None:
            continue
        a, b = sorted((p.id, p.married_to))
        if (a, b) in seen:
            continue
        seen.add((a, b))
        spouse = by_id[p.married_to]
        later_gen = max(p.generation, spouse.generation)
        if generations is None or later_gen in generations:
            lines.append(f"{p_iri(a)} ex:marriedTo {p_iri(b)} .")

    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w", encoding="utf-8") as f:
        f.write("\n".join(lines))
        f.write("\n")


def main() -> None:
    ap = argparse.ArgumentParser(
        description="Generate a single-lineage family tree as RDF/Turtle."
    )
    ap.add_argument("--out-dir", type=str, default="out_graphdb")
    ap.add_argument("--seed", type=int, default=1)
    ap.add_argument("--min-children", type=int, default=2,
                    help="Minimum children per couple (default: 2)")
    ap.add_argument("--max-children", type=int, default=8,
                    help="Maximum children per couple (default: 8)")
    ap.add_argument("--num-generations", type=int, default=5,
                    help="Total generational tiers (default: 5)")
    ap.add_argument("--childless-from-gen", type=int, default=3,
                    help="Generation from which childless couples may appear (default: 3)")
    ap.add_argument("--childless-prob", type=float, default=0.05,
                    help="Probability a couple is childless from --childless-from-gen onward (default: 0.05)")
    ap.add_argument("--seventh-son", action="store_true",
                    help="Guarantee one 7th-son-of-7th-son in the tree")
    ap.add_argument("--faker-locale", type=str, default=None)
    ap.add_argument("--overwrite-schema", action="store_true")
    args = ap.parse_args()

    base_dir = os.path.abspath(args.out_dir)
    data_dir = os.path.join(base_dir, "data")
    os.makedirs(data_dir, exist_ok=True)

    here = os.path.dirname(os.path.abspath(__file__))
    for fname in ("schema.ttl", "rules.ttl"):
        src = os.path.join(here, fname)
        dst = os.path.join(base_dir, fname)
        if args.overwrite_schema or not os.path.exists(dst):
            shutil.copyfile(src, dst)

    last_gen = args.num_generations - 1
    base_gens = set(range(last_gen))

    people = generate_family_tree(
        seed=args.seed,
        min_children=args.min_children,
        max_children=args.max_children,
        num_generations=args.num_generations,
        childless_from_gen=args.childless_from_gen,
        childless_prob=args.childless_prob,
        seventh_son=args.seventh_son,
        faker_locale=args.faker_locale,
    )

    if args.seventh_son:
        found = count_seventh_son_of_seventh_son(people)
        print(f"  7th-son-of-7th-son instances: {found}")

    lineage_count = sum(1 for p in people if p.is_lineage)
    spouse_count = sum(1 for p in people if not p.is_lineage)

    # Base file: generations 0 … N-2
    base_path = os.path.join(data_dir, "000.ttl")
    write_data_ttl(base_path, people, sample_index=0, generations=base_gens)
    base_count = sum(1 for p in people if p.generation in base_gens)
    print(f"Wrote {base_path}  ({base_count} people, gens 0–{last_gen - 1})")

    # Incremental file: last generation only
    inc_path = os.path.join(data_dir, "000-lastgen.ttl")
    write_data_ttl(inc_path, people, sample_index=0, generations={last_gen})
    inc_count = sum(1 for p in people if p.generation == last_gen)
    print(f"Wrote {inc_path}  ({inc_count} people, gen {last_gen})")

    print(f"  Total: {len(people)} people ({lineage_count} lineage, {spouse_count} incoming spouses)")

    print()
    print("Import order into GraphDB:")
    print("  Phase 1 (base): schema.ttl, rules.ttl, then 000.ttl")
    print("  Phase 2 (incremental): 000-lastgen.ttl")
    print("Then run SHACL Rules materialization.")


if __name__ == "__main__":
    main()
