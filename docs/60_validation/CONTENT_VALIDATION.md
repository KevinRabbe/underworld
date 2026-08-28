# Content Validation Architecture

Status: **LOCKED validation direction, implementation deferred**

The content architecture is intended to become machine-enforced. Documentation alone is not sufficient once content volume grows.

## Validation layers

### 1. Identity validation
Check:
- valid semantic ID format;
- allowed top-level namespace;
- unique ID;
- no illegal reuse/alias conflict.

### 2. Category validation
Check:
- category exists;
- valid parent chain;
- no category cycles;
- category is legal for definition family;
- parent/category-required fields are satisfied.

### 3. Capability validation
Check:
- capability exists;
- capability allowed for family/category;
- required data/profile references exist;
- required/forbidden companion capabilities are respected.

### 4. Definition-schema validation
Check family-specific required/optional fields and value invariants.

### 5. Reference validation
Check:
- referenced ID exists;
- target family/type is compatible with role;
- required references exist;
- forbidden/cyclic reference structures are rejected where applicable.

### 6. Asset-role validation
Check required PackedScenes/resources/animations/audio/VFX roles exist and satisfy family-specific contracts where practical.

### 7. Dependency validation
Check definitions do not create forbidden architecture dependencies or unsupported cycles.

### 8. Manifest/compatibility validation
As persistence matures, compare compatibility-relevant content manifests and require migrations/aliases for breaking semantic identity changes.

## Diagnostics

Errors should be precise enough to fix without reproducing the issue in-game.

Preferred format direction:
```text
[CONTENT ERROR]
source: item.weapon.deep_iron_sword
rulebook: WEAPON_RULEBOOK
role: attack_set
value: attack_set.sword.deep_01
error: referenced definition does not exist
```

Avoid generic messages such as `invalid content`.

## Canonical result

A future validation run should produce deterministic/canonical summary output suitable for CI.

Example target:
```text
[CONTENT VALIDATION] PASS
categories: 74
capabilities: 31
definitions: 527
references: 1,846
broken references: 0
duplicate ids: 0
invalid definitions: 0
forbidden cycles: 0
```

Exact counts/output format are implementation details.

## CI policy

Once content validation exists, core authored content changes should not merge with structural content errors.

Runtime gameplay tests remain separate. Structural content validation does not prove balance/fun/visual quality.

## Staged implementation

Do not attempt to validate every future family at once.

Recommended sequence:
1. semantic ID/category/capability primitives;
2. one first real family (animation sets are a good candidate);
3. generic reference diagnostics;
4. weapon/item families;
5. creature/structure/world content families;
6. manifest/migration compatibility checks when persistent authored content depends on them.

The first family should prove that rulebook → authoring → validation can work end-to-end.

## Relationship to existing validation

Content validation complements, not replaces:
- deterministic worldgen validation;
- graph invariants;
- character/combat contracts;
- migration fixtures;
- runtime integration tests.

Each validation suite owns a different class of failure.
