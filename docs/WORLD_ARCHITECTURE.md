# Underworld — World Architecture

## 1. Shared world coordinates — LOCKED

Surface and Underworld occupy one deterministic world coordinate system. They are not unrelated dungeon instances.

A position underground has a real X/Y/Z relationship to the surface above it. This enables genuine cases where a cave, structure, deposit or boss exists beneath a familiar surface location.

Streaming/storage representations may differ between surface and underground, but both must resolve into the same global world space.

## 2. Relative world scale — LOCKED

The surface is comparatively smaller, more readable and easier to learn.

The Underworld provides substantially more meaningful traversable space through depth, overlap, branching and connectivity. Exact kilometer dimensions are intentionally **OPEN** until traversal/content-density tests justify them.

The design target is not a fixed area ratio; the important rule is that the Underworld feels materially larger than the surface.

## 3. Underground macro topology — LOCKED

The Underworld is generated hierarchically rather than as uniform cave noise.

Conceptual pipeline:

1. world seed;
2. major underground regions;
3. regional cave/network graphs;
4. chambers, tunnels and vertical transitions;
5. depth grammar assignment/blending;
6. viable surface entrances;
7. topology analysis;
8. selective secondary connections/loops;
9. special locations/resources/ecology;
10. detailed runtime geometry.

Topology and geometry must remain separate architectural concepts. The graph decides what connects to what before final cave meshes are built.

## 4. Entrances — LOCKED

A regional cave/network can normally expose roughly **1–3 surface entrances**, but this is a procedural range rather than a universal guarantee for every underground region.

Entrances may connect to different depths of the same network.

Examples include:

- gradual cave mouth into shallow caves;
- steep sinkhole reaching mid depth quickly;
- constructed/old tunnel reaching a deeper section;
- other natural or structural entrance forms added later.

An apparently easy entrance is allowed to lead unexpectedly deep. The game should communicate danger through environment and behavior rather than hard level gates.

## 5. Three depth grammars — LOCKED

Depth bands are continuous tendencies, not hard floors.

### Shallow Underworld

Generation bias:

- more local/separate networks;
- smaller/tighter chambers and passages;
- stronger surface influence: roots, soil, groundwater, shafts/daylight where appropriate;
- more obvious natural entrances;
- lower deliberate long-distance connectivity;
- relatively more practical building pockets near access routes.

Gameplay bias: discovering and understanding individual cave systems and establishing access.

### Mid Underworld

Generation bias:

- larger chambers and longer tunnels;
- more verticality;
- underground water systems where appropriate;
- regional systems increasingly connect;
- stronger loop/connectivity opportunities;
- larger resource zones and more substantial structures.

Gameplay bias: navigation, longer expeditions, resource operations and discovering network relationships.

### Deep Underworld

Generation bias:

- very large spaces and extreme vertical variation;
- much weaker surface ecological influence;
- stranger geology and rare large-scale locations;
- few very large networks plus long branches and dangerous isolated pockets;
- rare bosses, unique resources and major mysteries may occur here;
- permanent settlement remains possible but naturally difficult.

Gameplay bias: high-risk long expeditions, major discoveries and navigation where returning safely is itself meaningful.

Local exceptions are required. A huge shallow cavern or claustrophobic deep region is valid. Profiles define probability distributions, not templates.

## 6. Connectivity philosophy — LOCKED

The design shorthand is **~10% Souls-style connectivity**.

This does **not** mean copying shortcut doors, elevators or authored Souls-map mechanics. It means occasionally producing strong spatial-revelation moments through procedural topology.

Two mechanisms are allowed:

### Natural proximity connections

If independent networks or branches pass near one another, a secondary generation pass may connect them with a tunnel, crack, shaft, shared chamber, water passage or other suitable geometry.

### Deliberate topology loops

Networks do not need to be physically close if a reasonably sized connector would significantly improve the regional graph.

Potential connection value should consider factors such as:

- topology/loop improvement;
- useful depth variation;
- linking meaningful entrances or regions;
- geographic plausibility;
- connector length/cost;
- existing connectivity/redundancy.

Not every layer or region requires these connections. Shallow regions can have almost none; mid-depth is a strong candidate; some deep regions may become heavily interconnected while others remain isolated.

The generator must avoid turning the Underworld into spaghetti.

## 7. Underground building — LOCKED

Building underground is allowed wherever normal building and placement rules permit.

There is no blanket "cannot build underground" rule.

Difficulty should emerge from:

- limited/irregular floor space;
- ceiling height and cave geometry;
- hostile creature ecology;
- access and transport problems;
- resource availability;
- expansion difficulty;
- structural areas that cannot be excavated.

A rare large, flat, defensible cavern can itself be a valuable discovery because good underground building geography should not be available everywhere.

## 8. Terrain modification — LOCKED

### Surface

The surface provides the greatest terrain-modification freedom. Long-term settlements should be able to meaningfully reshape their local landscape: flattening, shallow excavation, roads/paths, trenches, foundations and other supported terraforming.

Exact technical limits remain **OPEN**.

### Underworld

Underworld modification is intentionally limited so the game does not become unrestricted Minecraft-style tunneling.

Expected categories:

- structural cave walls/bedrock: normally permanent;
- removable rubble/collapses: selectively excavatable;
- resource-bearing material/deposits: mineable;
- small local obstructions: potentially removable;
- designated modifiable volumes: allowed when generation/gameplay calls for them.

Players must not be able to ignore cave topology by aiming toward a target and mining a straight tunnel through arbitrary structural rock.

## 9. Boss and special-location modification — LOCKED

Modification rules are encounter-specific.

- Critical structures may be immutable.
- Some encounter spaces may intentionally restrict terrain modification where geometry is essential.
- A small number of encounters may deliberately allow extensive terrain preparation/building because that freedom is part of their identity.
- Existing structures can sometimes be repurposed by players when doing so does not break required game state.

The project should prefer "protect only what must be protected" over universal no-build/no-dig boss zones.

## 10. Audio locality — LOCKED

Creature audio must not reveal deep hidden content through unlimited vertical propagation.

Audio behavior should account for:

- finite 3D distance;
- attenuation;
- vertical separation naturally through 3D distance;
- solid-rock/terrain occlusion or simplification approximating it;
- open tunnels, shafts and entrances allowing farther propagation where appropriate.

Ordinary creatures far below solid rock should be inaudible from the surface. Very loud events may use separate explicit rules later.

Only nearby/relevant audio needs active runtime simulation.

## 11. Streaming — LOCKED ARCHITECTURAL REQUIREMENT

The finished Underworld may be much larger than the active runtime scene.

The architecture must separate:

- deterministic world definition/topology;
- loaded geometry;
- nearby collision;
- active creatures/simulation;
- active audio.

A cave region may mathematically exist without any Godot nodes, meshes, physics bodies or AI currently instantiated.
