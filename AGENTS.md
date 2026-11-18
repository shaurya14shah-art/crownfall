# Working on CROWNFALL

Godot 4.7, typed GDScript, macOS (Apple M4, Metal, Forward+). Rebuilt from
scratch on 2026-11-05: stylized look, free asset packs, open world.

## Rules

* Never commit or push unless asked.
* Screenshots before claiming anything looks right. Headless Godot compiles
  no shaders and renders nothing.
* Measure frame time after any visual change (`scenes/tools/Bench.tscn`).
* Unreal is ruled out ("it will fry my mac").

## Commands

```bash
G=/Applications/Godot.app/Contents/MacOS/Godot
$G --headless --path . --import                       # after adding a class_name
$G --path . scenes/tools/Capture.tscn -- /tmp/out [shot...]   # world viewpoints
$G --path . scenes/tools/CaptureUI.tscn -- /tmp/out   # title, HUD, dialogue, fight, pause
$G --headless --path . scenes/tools/TestSystems.tscn  # NO WINDOW: plays through every system, ok/FAIL
$G --path . scenes/tools/CaptureArts.tscn -- /tmp/out # tests each Art (PASS/FAIL) + HUD and tree shots
$G --path . scenes/tools/Bench.tscn                   # fps with each system switched off
$G --headless --script tools/contact_sheet.gd -- <dir> <out.png> 2 800
$G --headless --path . --script tools/inspect_assets.gd -- res://assets/<dir> [anim]
```

## Systems

* `Run` (autoload) holds the playthrough: bag, gear, hotbar, silver, skills
  and perks, behaviour profile, Inscription (`law`), Archive, flags. All UI
  reads it and listens to `Run.changed(what)`; notices go out on
  `Run.toast(text, kind)`. Save/load is `Run.to_dict` / `from_dict` plus the
  player and time (`SaveSystem`).
* Every perk effect key in `data/skills.json` must be read by gameplay code
  via `Run.perk(effect)`; don't add a perk that does nothing.
* `Law` (static) generates and advances an Inscription from
  `data/laws.json` + `data/inscription_parts.json`; `LawPowers` (on the
  player) checks the condition, pays the price, runs the effect.
* Interactables are anything in group `interactables` with
  `prompt_text()` and `interact(player)` (villagers are handled in main).
* Quests, pop-ups and a tracker exist **at the user's explicit request
  (2026-11-06)**, overriding the design doc's old "no quest log, no markers"
  rule. `Quests` defines them (steps finish on Run facts); `Run.update_quests`
  advances them; HUD draws the tracker, waypoint and compass marker; T sends
  a `GuideTrail` of wisps along the roads toward the goal.
* `Arts` (on the player) are the Knight's Arts on Z X V B: the `effect: "art"`
  root node of each combat tree in `data/skills.json` (the one exception to
  the perk rule above: `Arts.ALL` reads them by id). Whirlwind is unlocked in
  `Run.new_run` and on every load.
* Difficulty was eased on 2026-11-06 at the user's request ("too hard,
  movement too slow"): faster run/sprint, cheaper stamina, softer skeletons
  and Gate scaling, cheaper skill levels, more potions. Don't harden it back
  without asking.
* The Elden-Ring-shaped loop (2026-11-06, the user asked for "the key
  elements" plus weapon crafting): `Waystone`s placed by `Wilds` along
  `Island.road_paths` (rest = `Player.rest_full` + `Wilds.rest`, which
  raises everything in group `fallen`); `Run.flask*`; `Wilds.drop_silver` /
  `LostSilver` on death; skeleton stance (`posture`, `S.BROKEN`,
  `critical()`), `take_hit(damage, from, stance)`; `Forge` (data in
  `data/forge.json`, results in `Run.forged`, `Run.temper`, `Run.etch`;
  `Run.item()` lays tempering and etching over the base definition);
  `ForgePanel` + its `HammerGame`; `RestPanel`. Field bosses are Skeleton
  KINDS with `drops`; the Grave Knight is spawned by `Wilds` at night only.
* The "hook" layer (2026-11-07, "make me feel like I can't stop playing"):
  `Run.renown()` (Renown level/xp; `Renown.reward_for` is the reward track;
  each level adds `Renown.HEALTH_PER_LEVEL` in `Player.max_health`);
  `Run.renown_points` spend in any tree (`Run.unlock`). Deeds are reported
  with `Run.record(kind)` / `record_max` and counted by `Bounties`; kills go
  through `Run.on_kill` (chain, life tally). `Loot` rolls weapons/shields
  into `Run.forged` as `loot_<n>`. Elites (`Skeleton.affixes`, rolled in
  `_roll_elite` on spawn and respawn) and the `thief` kind live in
  skeleton.gd; `Wilds` spawns thieves and runs Rift Surge nights
  (`Run.surge`, `Run.nights`). Anything new worth doing should call
  `Run.renown()` and, if a bounty could count it, `Run.record()`.
* The sea (2026-11-07, "the pirate journey essence"): `World.ground(x, z)`
  is Aldermere *or* an isle (`Isles.height_at`); use it, not
  `island.height_at`, for anything at sea. `Ship` is an AnimatableBody3D on
  collision layer 16 (the player's mask includes 16) whose collision is the
  hull mesh; `refloat()` is how to move one (it carries a deck rider), and
  its position only updates on the next physics tick (tests must wait for
  physics frames, not process frames). `Player.helm` is the ship being
  steered; `S.SWIM` / `S.CLIMB` are the water and ledge states. `Treasure`
  nodes are dig sites; maps are `map_<n>` items in `Run.forged`.
  Bow is +Z on the Kenney pirate ships; main deck 2.1, quarterdeck 3.5
  (model units, ×1.6).
* UI style is `Kit` + `ChunkyButton` + `HUD.chip()` — opaque, gold-rimmed,
  hard shadows. No translucent "glass" panels, no blur.

## Where things live

```
scripts/core/     game.gd (autoload: input, quality presets, fonts), audio.gd (autoload), fx.gd
scripts/world/    island.gd (height field, paint map, sites, roads), terrain.gd, ocean.gd, sky_rig.gd,
                  foliage.gd, grass.gd, village.gd, landmarks.gd, world.gd (builds everything)
scripts/actors/   character_model.gd (KayKit loader + anims), skeleton.gd, villager.gd
scripts/player/   player.gd, camera_rig.gd
scripts/ui/       ui_style.gd, main_menu.gd, loading_screen.gd, hud.gd, pause_menu.gd, settings_panel.gd, menu_item.gd
scripts/main.gd   flow: loading -> title -> play; pause; quest; death
shaders/          terrain, grass, foliage, ocean, sky
assets/           third-party packs (see assets/LICENSES.md)
```

## Traps already paid for

* **UI roots under a CanvasLayer need `set_anchors_and_offsets_preset`.**
  `set_anchors_preset` alone left every screen collapsed in the top-left.
* **The shadow atlas is a fixed cost.** 4096² with leafy trees cost ~10 ms
  regardless of render scale. It follows the quality preset
  (`shadow_size`).
* **Region-sized tree batches must not cast shadows**: a 128 m batch draws
  every tree into every split. `Foliage` keeps shadow-only copies of the
  trees within 75 m of the camera instead, rebuilt every 20 m.
* **Merge kit pieces by material *name*.** Each glTF imports its own copy of
  the same material, so merging by instance merged nothing (1,600 draws).
* **Each glTF kit piece is a draw call** until merged (`Village._merge`).
* **A realtime Sky forces a 256 px radiance probe every frame.** The sky
  uses incremental mode at 128.
* **`match` inside a lambda failed to parse**; use a method.
* **Grass fades by shrinking, not `discard`** (discard disables hidden
  surface removal on Apple GPUs). Leaves need alpha test and pay for it.
* **The island is cached** in `user://island_<seed>_v<N>.bin`; bump
  `Island.CACHE_VERSION` when generation changes.
* **KayKit characters face +Z**; `model.rotation.y = atan2(dir.x, dir.z)`.
  Held items are children of `handslot_l/_r` attachments in the adventurer
  models; skeleton models have no attachments, so `Skeleton._hold` adds one.
* **Never set the camera's `position` under the SpringArm3D.** The arm
  owns it; camera shake goes through `h_offset` / `v_offset`. Setting the
  position put the camera inside the knight on some frames and not others.
* **On a Retina Mac the window is ~3420 px wide.** Benchmark with
  `Bench.tscn -- --retina` (and `--overlook`, `--quick`); 1600×900 numbers
  flatter everything. MetalFX Spatial measured sharper *and* cheaper than
  FSR1. Long benchmark runs throttle (fanless M4): later rows read slower;
  compare in fresh runs.
* **Close the user's running game before captures**: a window covered by
  another stops drawing and the capture hangs on `frame_post_draw`. Ask.
* **Far trees are impostors** (`Impostors`: baked cards past 130 m).
  Region tree batches never cast shadows; a stray `cast_shadow = ON` once
  put the whole forest back into the shadow map.
* **Gates** (`GateRun`) are built at `World.POCKET`; entering hides terrain,
  ocean, foliage, grass and village and switches the sky to the pocket's
  fog (`SkyRig.enter_pocket`). Story facts live in `Run.flags`; `Story`
  holds the Gates, beats and pages.
* **New class_name scripts need `--import`** before a capture, or the run
  dies on "Nonexistent function 'new'" and the window hangs.
* **A test whose script fails to parse hangs forever** (nothing calls
  quit). Run TestSystems under `perl -e 'alarm 480; exec @ARGV' ...`.
* **Headless never draws**: `frame_post_draw` never fires, so anything
  awaiting it hangs. `Impostors.bake` returns a blank card headless, which
  is what lets `TestSystems.tscn` build the whole world with no window.
  Prefer it whenever the user is busy; screenshots need a window and a yes.
