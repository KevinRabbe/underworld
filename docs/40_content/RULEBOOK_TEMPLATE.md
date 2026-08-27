# `<FAMILY>` Rulebook Template

Status: **TEMPLATE**

Use this structure when a content family is ready to become a scalable authored contract. Remove sections that are genuinely irrelevant; do not silently omit important ownership/identity questions.

## 1. Purpose
What does this family represent? What does it explicitly not represent?

## 2. Stable identity
- semantic ID namespace/pattern;
- ID stability expectations;
- migration/alias rules.

## 3. Parent rulebooks
List inherited family contracts.

Example:
```text
ITEM_RULEBOOK
→ EQUIPMENT_RULEBOOK
→ WEAPON_RULEBOOK
```

## 4. Categories
- required categories;
- allowed child categories;
- forbidden combinations;
- category-specific additional requirements.

## 5. Capabilities
- required capabilities;
- allowed capabilities;
- required/forbidden combinations;
- capability-specific data roles.

## 6. Required definition data
List fields that must exist and their semantic meaning.

## 7. Optional definition data
List supported optional fields/default behavior.

## 8. References
For each role define:
```text
role
required/optional
expected target family/category/capability
cardinality
cycle policy if relevant
```

## 9. Asset roles
List required/optional PackedScenes, animation, audio, VFX, icons, etc.

Asset paths are not semantic content identity.

## 10. Runtime ownership
Which runtime system interprets this definition? Which system owns live instances/state?

Definitions themselves should not own scene-tree lifetime.

## 11. Persistence
What semantic ID/world-instance identity is persisted? Which fields are runtime-only?

## 12. World-generation relationship
Can deterministic generation reference/select this family? What pure-data boundary is required?

## 13. Versioning/migration
Which changes are compatibility-sensitive? What requires an explicit migration?

## 14. Validation rules
List executable invariants and expected diagnostic information.

## 15. Forbidden patterns
Record family-specific architecture traps/special-case shortcuts that should not be introduced.

## 16. Minimal valid example
Provide the smallest valid definition in conceptual form.

## 17. Production-ready example
Optional. Provide a richer example only when it improves authoring clarity.

## 18. Authoring guide link
Link to the corresponding `50_authoring` workflow once the family is actively authored.
