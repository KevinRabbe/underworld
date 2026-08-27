# Underworld — Development Rulebook

## 1. Architecture before feature code — LOCKED

When a new subsystem affects world structure, persistence, streaming, generation, building, combat architecture or save compatibility, define the architecture first.

Do not use prototype implementation convenience as the reason to choose a permanent architecture.

Before coding a major subsystem, answer:

- what data owns the truth;
- what is deterministic versus persistent;
- what is generated versus instantiated;
- what IDs remain stable across regeneration;
- what can run off the main thread;
- how the subsystem is validated without manual playtesting;
- what future systems need to hook into it.

## 2. Batch implementation — LOCKED

Do not require a manual playtest for every small change.

The normal cadence is:

`design -> architecture -> implementation batch -> automated/simple validation -> next batch -> milestone playtest`

Manual playtests are reserved for questions that tests cannot answer well, such as:

- combat feel;
- mining satisfaction;
- traversal pacing;
- spatial readability/confusion;
- generated-world atmosphere;
- progression feel.

Parser/runtime sanity checks may still be run whenever useful, but the user should not be asked to manually validate every commit.

## 3. Automated/headless generation tests — LOCKED

Procedural systems must be testable without rendering the full game.

For underground generation, tests should eventually cover large seed batches and validate at least:

- deterministic regeneration;
- generation-order independence;
- valid graph references;
- entrance constraints;
- reachable required components;
- valid depth ranges/transitions;
- bounded connection/loop counts;
- no invalid topology edges;
- stable IDs;
- serialize/reload equivalence where applicable;
- save migration behavior.

A failure must print enough information to reproduce the exact seed/region/network.

## 4. Determinism is a feature — LOCKED

Generation must not depend on:

- chunk load order;
- frame timing;
- thread scheduling;
- iteration order of unordered containers when that order influences output;
- incidental accepted-array indices used as persistent identities.

When randomness is required, derive local deterministic seeds from stable addresses.

## 5. Persistence is delta-based — LOCKED

Untouched procedural content regenerates from seed.

Only meaningful changes are persisted.

Do not solve save problems by serializing entire generated regions unless a later technical design explicitly proves that this is necessary.

## 6. Stable IDs before generator tuning — LOCKED

Do not substantially retune procedural object densities/distributions while persistent IDs depend on array order.

The current prototype's index-based surface object/pickup identities are known technical debt. Migrate/generalize stable IDs before future generation changes can invalidate existing saves.

## 7. Separate system responsibility — LOCKED

Avoid giant manager scripts that own unrelated responsibilities.

Examples of boundaries that should remain distinct:

- world definition/topology;
- geometry generation;
- streaming;
- persistence;
- combat;
- resource/mining logic;
- presentation/HUD;
- audio.

Cross-system communication should use explicit data/interfaces/signals rather than hidden knowledge of another subsystem's internals.

## 8. Prototype visuals are disposable — LOCKED

Placeholder meshes/colors/UI may be crude when proving systems.

Do not architect gameplay around temporary placeholder geometry or UI.

Conversely, do not spend production-art time solving a system whose architecture is still uncertain.

## 9. Scope gate — LOCKED

Before adding a feature, ask:

1. Is it required by the current milestone?
2. Does an existing locked design require architectural support for it now?
3. Will postponing it create expensive rework?

If all three answers are no, postpone it.

Interesting future ideas belong in design notes, not automatically in the active development cycle.

## 10. Open decisions stay open — LOCKED

Do not accidentally hard-code an undecided design just because implementation needs a temporary value.

Examples currently open include exact world dimensions, exact depth boundaries, exact tree-harvesting model, exact terrain-deformation limits, exact future combat defense system and exact final resource roster.

Temporary prototype values should be clearly configurable or isolated.

## 11. Evidence can change rules — LOCKED

A rulebook exists to prevent accidental drift, not to prevent learning.

Change a locked rule when there is a concrete reason: playtest evidence, technical constraints, performance measurements or a clearly superior design.

Any deliberate rule change must update the docs and `DECISION_LOG.md` before or together with the implementation change.

## 12. Milestone completion — LOCKED

A milestone is complete when its architectural and behavioral success criteria are met, not when every imaginable adjacent feature exists.

Prefer a clean, validated subsystem over a broad feature pile.
