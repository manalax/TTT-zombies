# ADR 0011 — Wall-buys, Ammo Stations & Perks

- **Status:** Accepted (F018, 2026-11-10)
- **Code:**
  - `src/world/shop/`: `ShopStation`, `WallBuy`, `AmmoStation`, `PerkAltar` + scenes;
  - `src/player/components/perk_component.gd`;
  - `Player.apply_perks()`, `HealthComponent.set_max()`;
  - perk hooks in `firearms/states/reloading.gd` and `MeleeWeapon.start_swing`;
  - `Interactable.updater` / `disabled_text`;
  - `Events.item_purchased`;
  - `TempHud` feed and perk line;
  - perk content (`second_wind`, `sure_grip`, `riposte`).
- **Tests:**
  - `tests/world/test_shop.gd` (the AC);
  - `tests/player/test_perks.gd`;
  - updates in `test_loadout.gd`, `test_temp_hud.gd`, `test_events.gd`.

## Context
DESIGN §10.2 lists the point sinks: wall-buys (weapons and ammo; ammo is costly for scarcity) and perk altars. Doors were F017.

**AC:** purchases deduct points and replace loadout slots correctly.

It builds on:
- F016 (`try_spend`, `PointRules.shop_price` / `ammo_price`);
- F014 (`Loadout.replace_slot`, `grant_ammo`, `firearm_slot_for_pickup`, `AmmoRules`);
- F017 (`Interactable`, the feed).

## Decisions

### Stations
- **`ShopStation`** (StaticBody3D on WORLD) has an `Interactable` child and a `Label3D`.
  - It joins `nav_blockers`, so stations are baked as nav obstacles.
  - Subclasses implement `_configure(player)` (set the offer for that viewer through `set_offer(prompt, cost, disabled_reason)`) and `_purchase(player)` (authority: `charge()` = `try_spend`, then grant).
  - Colliders are 2 m tall so the eye-height interact ray hits them without looking down.
- **Per-viewer prompts:** `Interactable.updater` runs before every prompt, check and use. Each player sees their own case, and a stale prompt can't buy the wrong thing, because the authority re-evaluates on use. Disabled offers show "`<prompt> — <reason>`" without the "E:" prefix.
- **Never charge for nothing:** every branch that can't grant (owned melee, full reserve, perk limit, owned perk, not whitelisted) is disabled, so `use()` is refused before any spend.

### WallBuy
- **Not owned:**
  - price `shop_price(wall_cost)`;
  - a firearm goes to `firearm_slot_for_pickup()` (the active firearm slot, else an empty one, else FIREARM_A); a melee weapon goes to MELEE;
  - `replace_slot` gives fresh ammo (`fill`, scarcity-scaled) and the old weapon is **discarded** (there's no pickup system, as in CoD);
  - the new slot is drawn (`request_slot`, with the draw time);
  - it's announced.
- **Owned firearm:** "`<gun> ammo`" at `ammo_price(ammo_cost)` → `grant_ammo(slot, reserve_cap)`. Disabled ("Ammo full") when the reserve is full. It isn't announced.
- **Owned melee:** disabled ("Owned").

### AmmoStation
It refills the **held** firearm: `ammo_price(held.ammo_cost)` → `grant_ammo(slot, reserve_cap)`. Scarcity scales the grant and the price (ADR 0007), and the cap holds. It's disabled with melee out ("Draw a firearm") or a full reserve ("Ammo full").

### Perks
- **`PerkAltar`** sells one `PerkData` at `shop_price(cost)`. It's disabled when the perk is owned ("Owned"), at `MatchSettings.max_perks` ("Perk limit"), or when the perk isn't whitelisted.
- **`PerkComponent`** (on the Player) holds `owned` (each perk at most once).
  - `stat(key)`: `*_add` keys sum (base 0) and `*_mult` keys multiply (base 1).
  - `add()` and `clear()` are authority-only, and call `Player.apply_perks()`.
- **Where effects apply:**
  | Stat | Applied | Perk |
  |---|---|---|
  | `max_health_add` | `apply_perks` → `HealthComponent.set_max` (current health moves by the same amount) | Iron Constitution +25 |
  | `stamina_regen_mult` | `apply_perks` → `StaminaComponent.regen_per_s` | Second Wind ×1.5 |
  | `reload_speed_mult` | `Reloading` advances `elapsed` by `delta × mult` | Sure Grip ×1.4 |
  | `riposte_mult` | `MeleeWeapon.start_swing` multiplies `SwingSpec.riposte_mult` | Riposte ×1.3 |
  | `parry_window_add`, `loot_luck_mult`, `special_damage_mult` | **Not yet** (recognised by `PerkData`; no effect) | — |
- Losing perks on death or respawn is decided with F034/F038 (`clear()` exists).

### Whitelists
A non-empty `allowed_weapons` / `allowed_perks` disables stations for other items ("Unavailable").

### Feed
`Events.item_purchased(peer_id, kind, item_id)` with `kind` `&"weapon"` or `&"perk"`. The `TempHud` shows "Player N bought the X" or "Player N took the X sacrament". **Ammo refills are silent** (too frequent), and prices are never shown. The owned perks are listed under POINTS, and on the F3 overlay.

### Retired: the dev rifle stand
`WeaponPickupStand` (F014) is deleted. The sandbox has wall-buys instead:
- **Arena:** revolver, ammo station, Iron Constitution.
- **Annex:** rifle, blunderbuss, greatsword, Second Wind, Sure Grip, Riposte.

## Consequences
- **F019 / F045:** station layout and prices are per map. Costs stay in `WeaponData` / `FirearmStats` / `PerkData`.
- **F021/F022:** clients send the interact intent; the host runs `use()` and replicates the loadout, perks and points to the owner.
- **F053:** adds the remaining perk effects (and more perks) at the hook points above, plus consumables.
- **Pickups** (a dropped old gun, ammo drops) are still deferred (ADR 0010).
