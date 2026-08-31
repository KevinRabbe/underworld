# Underworld Documentation Architecture

Status: **LOCKED organization and authority contract**

The documentation tree is part of project architecture. It must remain navigable as the project grows from prototype systems into large content/runtime families.

## Top-level organization

```text
docs/
├─ 00_project/
├─ 10_architecture/
├─ 20_world/
├─ 30_gameplay/
├─ 40_content/
├─ 50_authoring/
└─ 60_validation/
```

Numeric prefixes are reading/organization markers only. They are not game versions, save IDs, content IDs or namespaces.

## Section responsibilities

### `00_project`
Project-wide intent/governance:
- game pillars;
- decision index;
- ADRs for substantial cross-system decisions;
- milestones/history;
- master roadmap;
- visual direction;
- glossary/documentation rules.

### `10_architecture`
System ownership/dependency boundaries:
- content architecture;
- runtime ownership;
- persistence boundaries;
- system ownership maps;
- performance/scalability;
- presentation boundaries.

Answers: **who owns what, and what may depend on what?**

### `20_world`
World-specific architecture/design:
- Overworld/Underworld relationship;
- deterministic generation;
- topology;
- gateways/transitions;
- streaming-facing world contracts;
- terrain/world-delta rules.

### `30_gameplay`
Runtime gameplay contracts:
- character/combat;
- survival;
- crafting;
- building;
- harvesting/resources;
- other player/simulation systems.

### `40_content`
Definition/rulebook contracts:
- semantic IDs;
- categories/capabilities;
- references;
- valid item/creature/build/attack/audio/VFX/etc. families.

Answers: **what makes one member of this content family valid?**

### `50_authoring`
Human workflows:
- adding content;
- asset-authoring procedures;
- validation commands/expected feedback.

Answers: **how do I create another valid member?**

### `60_validation`
Machine-enforced validation ownership:
- content validation;
- deterministic/worldgen validation;
- migration fixtures;
- runtime/scale contracts;
- dependency/reference checks.

Answers: **how do we prove the contract still holds?**

---

# Decision authority and supersession

## Chronological history

`docs/DECISION_LOG.md` preserves historical decision chronology. Do not delete or silently edit old decisions merely because architecture changed later.

## Decision index

`docs/00_project/DECISION_INDEX.md` is the current navigation/status layer. It tells workers whether a historical decision remains active, has been superseded, is recorded history or remains open.

The index cannot invent supersession by itself; it must point to an explicit later decision/ADR.

## ADRs

A dedicated ADR is appropriate when a change has substantial cross-system consequences, explicit alternatives/trade-offs or a meaningful migration/supersession story.

An **ACTIVE later ADR may supersede specifically named historical locked clauses** while preserving the old text as history.

Required ADR properties:
- date/status;
- normative new decision;
- rationale/trade-off;
- exact old clauses/decisions superseded;
- affected owning contracts;
- migration/compatibility consequences where relevant.

The current example is:
- [`ADR-001_TWO_WORLD_DOMAINS.md`](ADR-001_TWO_WORLD_DOMAINS.md)

which supersedes specifically named one-continuous-world assumptions from the 2026-08-27 history.

### Authority order for a changed rule

For one explicitly superseded topic, read in this order:

```text
latest explicit ACTIVE decision / ADR
        |
        v
current owning architecture contract
        |
        v
DECISION_INDEX current status
        |
        v
older DECISION_LOG entry as historical rationale
```

For untouched topics, the older locked decision remains active.

Never use a stale historical `LOCKED` label to override a later explicit supersession.

---

# Document-type boundaries

An **architecture document** defines ownership/invariants/dependency direction.

A **rulebook** defines validity for one semantic content family.

An **authoring guide** defines concrete human workflow.

A **validation document** defines executable proof/ownership of checks.

A **roadmap** defines sequencing/dependencies/integration gates but does not silently rewrite architecture.

A **task/issue** defines current execution state and acceptance work; completed task text is not automatically permanent architecture.

Do not collapse all of these into one giant document.

---

# Current-versus-historical conflicts

When a newer decision changes architecture:
1. preserve old history;
2. create the explicit replacement decision/ADR;
3. update the owning normative contracts;
4. update `DECISION_INDEX.md`;
5. update routing/ownership indexes affected by the change;
6. mark obsolete task cards not-planned/superseded where necessary;
7. retain historical milestone evidence unless the new decision explicitly invalidates the result itself.

A historical implementation can remain accepted evidence even if the final product architecture later uses a different composition boundary.

Example: a traversable continuous cave prototype remains evidence that Underworld topology/geometry/streaming worked, even if later world travel uses an explicit loading gateway.

---

# Existing flat root docs

Root-level documents under `docs/` remain authoritative until explicitly superseded/migrated.

When a root contract is replaced by a numbered destination:
- leave an explicit compatibility/supersession stub at the old path when other docs/code/tasks may still link to it;
- point to the new authoritative file;
- preserve historical text through Git history rather than maintaining two competing active copies.

This is the migration pattern used for the generation-pipeline contract after ADR-001.

---

# Naming rules

- numeric folder prefixes never enter semantic game IDs;
- filenames should describe their semantic purpose;
- avoid dates/version numbers in permanent architecture filenames except explicit historical records;
- ADR numbers are stable governance identifiers, not game/content versions;
- semantic content IDs remain forms such as `item.weapon.iron_sword` independent of documentation paths.

---

# Scaling rule for large families

Before a content/system family becomes large, establish where applicable:
1. architecture ownership;
2. stable identity rules;
3. category/capability rules;
4. rulebook/schema;
5. authoring workflow;
6. validation coverage;
7. scale-envelope/performance expectations.

The goal is to make later growth primarily an authoring/content problem rather than repeated infrastructure rewrites.

This is especially important for future 1000+ building-piece catalogs, world populations and multiplayer-scale runtime systems.

---

# Maintenance rule

Documentation must not knowingly present contradictory rules as simultaneously current.

Before freezing a major architecture documentation candidate:
- search affected ownership contracts for old locked assumptions;
- explicitly supersede or repair contradictions;
- keep historical evidence identifiable as historical;
- ensure task boards/roadmaps point to current authority;
- require independent review for substantial cross-system changes.
