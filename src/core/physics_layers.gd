class_name PhysicsLayers
extends RefCounted
## 3D physics layer bits (names are set in project.godot [layer_names]).
## Use these constants, never raw numbers, for collision_layer / collision_mask / ray masks.

const WORLD := 1 << 0
const PLAYERS := 1 << 1
const ENEMIES := 1 << 2
## Hurtbox Area3Ds only. Melee shape casts and hitscan rays target this layer.
const HURTBOXES := 1 << 3

## What character bodies collide with.
const CHARACTER_MASK := WORLD | PLAYERS | ENEMIES
## What attacks query: world geometry stops them, hurtboxes take the hit.
const ATTACK_MASK := WORLD | HURTBOXES
