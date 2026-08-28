# Content Registry Architecture

Status: **LOCKED boundary, implementation deferred**

The future content registry is the authoritative resolver between semantic content IDs and authored definitions/assets.

This architecture is defined before implementation so gameplay systems do not grow incompatible lookup patterns in the meantime.

## Responsibilities

The registry will eventually:
- discover/register authored content definitions;
- enforce unique semantic IDs;
- expose typed lookup by semantic ID;
- resolve definition references;
- provide category/capability metadata to validation and authoring tools;
- expose a deterministic/canonical content manifest for compatibility checks;
- report missing/duplicate/incompatible definitions clearly.

## Non-responsibilities

The registry must not:
- own live scene-tree instances;
- execute combat, crafting, AI or worldgen;
- become a global bag of gameplay state;
- silently fix invalid definitions at runtime;
- use Resource paths as stable public identity.

## Lookup direction

Preferred direction:
```text
semantic content ID
        ↓
ContentRegistry
        ↓
validated definition
        ↓
runtime system/factory interprets definition
```

Avoid scattered patterns such as:
```text
load("res://some/current/path.tres")
```
inside unrelated gameplay systems when the target represents semantic game content.

## Typed lookup

Where practical, consumers should request/expect a definition family or role.

Conceptual API direction:
```text
get_definition(content_id)
get_item(content_id)
get_attack_set(content_id)
require_reference(source_id, role)
```

Exact Godot API is deferred until implementation.

## Registration model

Implementation may use Resources, manifests, generated indexes or editor tooling, but the public semantic contract remains independent of storage strategy.

Registration order must not alter authoritative content identity.

## Content manifest

A future canonical content manifest should include compatibility-relevant information such as:
- registry/schema version;
- all semantic IDs;
- definition family/schema revision;
- category/capability schema revisions;
- explicit aliases/migrations where applicable.

The manifest is distinct from the deterministic world-generator manifest, though save compatibility may depend on both.

## Modularity

Family-specific registries/indexes may exist internally for performance/tooling, but they should participate in one coherent identity/reference architecture rather than inventing incompatible lookup semantics per subsystem.

## Failure policy

Authored core content should fail validation/CI on structural registry errors rather than degrade silently.

Runtime fallback behavior may exist for optional presentation assets, but gameplay-critical missing definitions must be explicit.

## Migration path from prototype code

Existing hard-coded tool/attack catalogs are allowed as prototype implementations.

Migration should happen family by family:
1. define family rulebook/schema;
2. create validated definitions;
3. register definitions;
4. switch consumers to semantic lookup;
5. remove old ID/path special cases only after equivalent behavior is covered by tests.

Do not perform a giant content-registry rewrite before the first family proves the pattern.
