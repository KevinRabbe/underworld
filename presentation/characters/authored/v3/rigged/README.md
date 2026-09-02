# Character 2 Authored Rig

This package skins the approved `character2_styled` presentation without
changing its modeled silhouette. It preserves the public
`rig_profile.humanoid.prototype` bone names and adds internal finger bones for
the tool-grip pose.

The generated GLB is intentionally separate from the frozen editor base and
the styled review source. Rebuild it with:

```powershell
& 'C:\Program Files\Blender Foundation\Blender 5.2\blender.exe' --background --python 'presentation/characters/authored/v3/tools/build_v3_character2_rig.py'
```

Validation performed during generation:

- all 21 required public bones exist;
- every exported mesh vertex has a weight;
- no vertex exceeds four normalized influences;
- hair, face details, and beard follow the head;
- clothing follows the pelvis for the initial integration checkpoint.

The production Game composition now selects the authored presentation provider.
That provider imports this GLB, resolves the public humanoid bone contract,
creates the existing semantic sockets, and applies the internal finger grip
when a tool is equipped. The prototype mannequin provider remains the explicit
fallback if the authored asset cannot be loaded, and is still the default for
isolated Player tests.

The checked-in integration test verifies the imported 41-bone skeleton, all 21
public bone names, semantic animation runtime creation, fallback behavior, and
right-hand tool/grip realization through the production Game scene.
