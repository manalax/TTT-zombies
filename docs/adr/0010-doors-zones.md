# ADR 0010 — Doors, Zones & Interaction

- **Status:** Accepted (F017, 2026-11-10)
- **Code:**
  - `src/world/zones/`: `Zone`, `Door` + `door.tscn`;
  - `src/world/interact/interactable.gd`;
  - `EnemySpawnPoint.is_active()`, `EnemyRegistry.active_spawn_points()`;
  - `RuntimeNavRegion` (`nav_blockers`);
  - `Player.get_interact_target()` / `try_interact()` / `interact_denied`;
  - `TempHud` (prompt, deny flash, feed);
  - sandbox annex.
- **Tests:**
  - `tests/world/test_doors_zones.gd` (the AC) + `zone_test_world.gd`;
  - `tests/world/test_interactable.gd`;
  - arena coverage in `test_runtime_nav_region.gd`, `tests/ui/test_debug_actions.gd`, `test_temp_hud.gd`.

## Context
DESIGN §11 says maps are zones linked by doors with a point cost, and that doors toggle navigation. §8.3 says the director only spawns in unlocked zones.

**AC:** opening a door unlocks a zone and spawn points.

It builds on F016 (`try_spend`, `PointRules.door_price`) and F015 (the runtime navmesh and spawn points).

## Decisions

### Zones
- **`Zone`** (Area3D, group `zones`): `zone_id`, `starts_unlocked`.
  - `unlock()` is authority-only and idempotent. It emits `unlocked_changed` and `Events.zone_unlocked(zone_id)` exactly once.
  - Box-shape children define the volume for `contains(point)`, which F019 can use for "zones near players".
  - The area doesn't monitor anything (no physics cost).
- **Spawn gating:** an `EnemySpawnPoint` belongs to its nearest `Zone` ancestor. `is_active()` is true with no zone, or when that zone is unlocked. `EnemyRegistry.spawn_many` (and so F10/Shift+F10) only uses active points.
- **`ambient_spawns_in_closed_zones` was moved to F044 by F019** (ADR 0012). Enemies spawned in a locked zone can't reach anyone until a door opens.

### Doors
- **`Door`** (StaticBody3D on WORLD, group `nav_blockers`) reads `DoorData` (`cost`, `unlocks_zone_id`, `prompt_text`) from ContentDB.
- **Buying:**
  - an `Interactable` child shows `E: Open <name> [price]`, where the price is `PointRules.door_price(cost)` (× `door_cost_mult`, rounded up to 10);
  - on use (authority): `player.points.try_spend(price, &"door")`, then `open(peer_id)`.
- **`open()` is permanent and idempotent:**
  1. collision off (deferred);
  2. the `NavigationLink3D` across the doorway is enabled;
  3. the slab sinks (tween) and the prompt is disabled;
  4. `Zone.find(unlocks_zone_id).unlock()`;
  5. `opened` + `Events.door_opened(door_id, peer_id)`.
- **Multiple doors into one zone:** any of them unlocks it (once), but the others stay closed and are bought separately (CoD style).
- A door's two zones are its local −Z/+Z sides. Only `unlocks_zone_id` is unlocked, since the other side is where the buyer stands.

### Navigation: bake with doors shut, open with links
- `RuntimeNavRegion` adds every body in `nav_blockers` to the bake (they don't have to be under its `source`). Closed doors are therefore walls, and each zone is a separate nav island.
- Each door's `NavigationLink3D` (endpoints 1.2 m either side, bidirectional) is disabled until it opens. Enabling it connects the islands, and agents repath through it on their next repath (≤ 0.3 s).
- **Why not one region per zone, or a re-bake:**
  - Per-zone regions can't represent a closed door between two already-unlocked zones, and still need a doorway connection.
  - Re-baking costs about 30 ms per door on the arena, and grows with map size.
  - Links cost nothing at runtime and work for doors added after the bake.
- Like region changes, link changes reach the map after a few physics frames (async sync, ADR 0008).

### Interaction: the `Interactable` component
- An `Interactable` child of any WORLD collider has `prompt`, `cost` (−1 = free), `enabled`, `deny_reason(player)` (`&"disabled"` / `&"points"`), `use(player)` and `used(player)`. It replaces F014's `interactable` group + duck-typed `interact()`.
- The owner decides what using it does, including charging: the door spends, the rifle stand swaps. `cost` is only for the prompt and the affordability check.
- `Player.get_interact_target()` casts the eye ray (WORLD, `interact_range_m`) and returns the collider's `Interactable`. `try_interact()` uses it, or emits `interact_denied(reason)`.
- **HUD (local):** the prompt above the bottom centre, red when unusable, and a 1 s "Not enough points" flash on a denied press.
- F018 wall-buys, ammo stations and perk altars use the same component, with a per-viewer `updater` and `disabled_text` (ADR 0011). Disabled prompts drop the "E:" prefix. The rifle stand was retired.

### Feed
`Events.door_opened` → a public `TempHud` feed line, "Player N opened the X". It lasts 4 s, at most 4 lines are shown, and the cost isn't shown. It's a Betrayal trust signal (who spends where). Real player names arrive with the lobby (F020/F025).

### Sandbox
- The arena is zone `arena` (start). Its spawn points live under it. *(Since F046 they sit in closets behind boarded windows, and so does the annex spawn; see ADR 0013.)*
- The **annex** (x −44…−30, z −10…10) is zone `annex`, with one spawn point.
- It's reached through two doorways in the split west wall: **Annex Postern** (250, z +6) and **Annex Gate** (750, z −6).
- The walkability test checks that the annex is unreachable until a door opens.

## Consequences
- **F018:** stations add an `Interactable` and spend with `try_spend(PointRules.shop_price/ammo_price(...))`.
- **F019:** spawn only at `is_active()` points; use `Zone.contains` for proximity; ambient closed-zone spawns were deferred to F044 (ADR 0012).
- **F021/F023:** clients mirror `Door.is_open` and `Zone.unlocked` (e.g. via `door_opened` / `zone_unlocked` RPCs); only the host calls `open()`/`unlock()`.
- **Pickups** (ammo drops, the death points bag, zone loot from `LootTable`) aren't in F017. They come with F034 (bags) and F053 (consumables) or a dedicated feature.
- **Lint:** `Player` now exceeds 20 public methods; it's the facade used by states, weapons, the HUD and tests, so it carries `# gdlint:disable=max-public-methods`.
