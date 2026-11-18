# CROWNFALL — The Shattered Realms

A stylized open-world action adventure on the island of Aldermere, built in
Godot 4.7. Explore a 2 km island of rolling hills, forests and a northern
mountain range; walk the cobbled lanes of Brightwater; and put the risen
dead of the Barrow of Ash back in the ground.

## Running it

```bash
GODOT=/Applications/Godot.app/Contents/MacOS/Godot
$GODOT --path .            # play
$GODOT --headless --path . --import   # after adding a class_name
```

The first start builds the island (about 10 s) and caches it in
`user://island_*.bin`; later starts are faster.

## Controls

| | |
|---|---|
| WASD · Shift · Space | move · sprint · jump |
| Left mouse | sword combo (three swings; two-handed weapons swing differently) |
| Left mouse (hold) | a charged heavy blow; in the air, a leaping blow on landing |
| Right mouse (hold) | shield up; with Perfect Guard, raise it just as a blow lands to parry |
| Ctrl / C | roll |
| Q / middle mouse | lock on |
| 1–5 | hotbar (drink, eat, or equip what is in the slot) |
| R | drink from the Flask (refills at a Waystone) |
| Z · X · V · B | the Knight's Arts: Whirlwind · Shield Bash · Charge · Battle Cry |
| F · G | your Inscription's powers, once it has woken |
| E | talk, trade, open, ring, rest at a Waystone, read, touch a bloodstain, climb aboard, take the helm, dig |
| At the helm | W / S sails · A / D rudder · Space anchor · left mouse a broadside toward where you look · E let go |
| In the water | swim (Shift to swim hard); swim into a shore or rock lip to climb out (Space for a higher one) |
| Tab | the Codex: Journey, Inventory, Skills, Inscription, Map, Archive |
| T | show the way to your tracked quest |
| K · M · J | Codex straight to Skills · Map · Archive |
| Esc | pause: save, load, settings |

## What's here

* **The island**: generated from a seed, then shaped by hand: beaches and a
  harbour bay, hills, a ridged mountain range, plateaus for the village and
  the castle, roads between the places. Terrain in 128 m chunks with four
  levels of detail; a painted terrain shader; Gerstner-wave ocean with
  clear shallows and shore foam; a day–night sky with drifting clouds and
  stars.
* **Places**: Brightwater (19 houses assembled from the Medieval Village
  kit, a market square, gardens, villagers), the harbour (pier and ships),
  Highmoor Keep, the Barrow of Ash, Gull's Watch.
* **Forests and fields**: 12,000 trees and rocks from the Stylized Nature
  kit, with wind; grass that grows out of the ground's own colour, bends in
  gusts and away from you.
* **Combat**: a three-hit combo with hit-stop and camera shake, shield
  block, i-frame roll, lock-on, potions. Skeletons patrol their camps, chase,
  telegraph their blows, stagger, die and rise again.
* **Items and gear**: weapons and shields that show in the knight's hands
  and change how he fights; draughts and food; loot that drops from the
  risen and flies to you; four chests; Tobin's forge to buy and sell.
* **Skills that grow by use** (Blade, Guard, Agility, Vitality), each level
  a point in that skill's tree; every perk changes something real (parry,
  cleave, Last Stand, faster stamina…).
* **The Knight's Arts**: a basic power at the root of each combat tree, on
  Z X V B, long before the Law wakes. Whirlwind (spin, hit everything
  around you) is known from the start; a new knight has a point each in
  Guard, Agility and Vitality to learn Shield Bash (stagger what's in
  front), Charge (dash and bowl foes aside) or Battle Cry (heal and +25%
  damage for 8 s). Each has a cooldown shown on the HUD beside the hotbar.
* **The Law**: latent potential gathers near the Barrow and as the risen
  fall; badly hurt in a fight with enough of it, your Inscription wakes —
  principle, condition and price drawn from how you have played. Its
  manifest power is on F; a hidden one reveals itself through what you do
  and goes on G. Mastery, a Law skill tree, and ascension with a catalyst
  (the Stilled Tide Shard the Barrow Warden drops).
* **Quests**: the main story and side quests, with a card when each starts,
  moves on and finishes; a tracker (objective and distance), a waypoint over
  the goal that points from the screen's edge when it is behind you, a
  marker on the compass and the map, and **T** to send a trail of golden
  wisps along the roads toward it. The Journey tab lists them and picks
  which to track. The Archive keeps what you have noticed, places, people
  and what you have put down. Hidden
  threads (Highmoor's bell at night, a light on Gull's Watch) are found by
  being in the right place at the right time.
* **Gates**: rifts that open as the story disturbs the Law, each a pocket
  dimension of stone chambers (KayKit dungeon kit) — fights behind barred
  doors, spike traps, pages of the Rupture on lecterns, a treasure room, and
  a keeper with a ground slam and summons. Clear one and its keeper's
  catalyst opens the next rank of ascension. Gates never close; you can go
  back in.
* **The story**: the Barrow → the Drowned Stair (at the cove, once the
  Warden falls) → the Hall of Still Hours (in Highmoor Keep) → the Sundered
  Crown (on the peak). Told in story cards, in what villagers say as the
  world changes, and in nine Fragments of the Rupture.
* **Ascension**: III Ascendant (powers chain), IV Exalted (Overflow on H),
  V Sovereign (an aura that weakens foes) — each needs mastery, both powers
  found, a catalyst, and a trial survived.
* **The sea**: your own ship, the Gull, rides at Brightwater's pier. Climb
  aboard (from the pier or the water), take the helm and sail: the wind
  swings round over minutes, running before it is quick, a beam reach
  quickest, close-hauled slow, straight into it almost nothing. Let go of
  the wheel and walk her deck while she sails. She cannot sail onto land;
  the keel finds the shallows. Broadsides from either side. Call her to any
  seaside Waystone.
* **The isles**: Skull Key (a corsair camp under a watchtower), Wreck
  Shoals (a galleon's bones on a sandbar) and Sable Isle (a ruined fort on a
  green hill), out past Aldermere's shore, each with a landing Waystone and a
  crew of Drowned Corsairs.
* **Buried treasure**: Treasure Maps (you start with one; thieves,
  corsairs, the Captain, the Galleon, bounties and other chests give more)
  put an X on the compass, the map and the ground. Dig there for a chest.
* **The Drowned Galleon**: a ghost ship on a round of the isles once you
  have found one. It circles you and fires as it passes; sink it and its
  hold floats free. Lose your own ship and she is back at her mooring
  twenty seconds later.
* **Swimming and climbing**: deep water floats you; swim to a beach and walk
  out, or into a rock or cliff lip to haul yourself up. On land, jump at a
  ledge you can reach to climb it.
* **Gates** look like Gates now: a broken ring of rune-cut stones on a dais
  round a swirling hole in the world, motes drawn into it, a rune circle on
  the ground and a faint column of light over an open one. They stand on dry
  land (the Drowned Stair used to be out in the sea). Inside, every chamber
  has a rune circle on its floor and motes in the air.
* **Waystones**: six old stones along the roads. Kindle one and rest there:
  health and the Flask refill, and every risen thing you have put down gets
  up again (the fallen otherwise stay down for five minutes). Travel between
  kindled stones, work the anvil, strengthen the Flask with Hearthseeds and
  Bright Tears, or wait for nightfall. You get up at the last one you rested
  at.
* **The Flask**: four draughts on R, refilled only by resting. Potions are
  still sold and still go on the hotbar.
* **Falling costs something**: the silver you carry stays where you fell,
  under a pale column you can see from far off (and on the compass and the
  map). Walk back into it to take it back; fall again first and it is gone.
* **Stance and critical blows**: every enemy has a stance (the thin gold
  line under its health). Hits fill it, charged and leaping blows far more,
  and a parry or a Shield Bash breaks an ordinary foe outright. A broken
  stance leaves it reeling: attack then for a critical blow, about three
  times the damage.
* **The Forge**: the anvil at every Waystone (or Tobin's). Make your own
  weapon from a form (longsword, axe, dagger, greatsword, great axe, war
  staff), a metal (iron; bone-wrought: faster; grave-iron: harder;
  star-iron: hardest) and an etching (Ember: burns; Rime: chills and
  softens; Grave: drinks life). Three timed hammer blows decide its quality;
  three perfect ones make a Masterwork. Temper any weapon to +5, etch an
  old one, or break spare gear back into materials. Etched and fine metals
  glow in the knight's hand.
* **Field bosses**: the Drowned Captain on the harbour shore, and the
  Night's Grave Knight, who walks the Crossroads road only after dark. Each
  drops Star-Iron and a unique piece of gear.
* **Messages and bloodstains**: words left on the ground by other knights
  (hints, warnings, a joke or two), and bloodstains where a red shade replays
  how its knight died.
* **Renown**: everything worth doing (kills, quests, places, chests,
  forging, bounties) fills a gold bar under the hotbar. Each level heals you
  whole, adds health, and brings the reward shown at the bar's end: a
  Renown point for any skill tree on even levels; a Hearthseed, Star-Iron,
  a Bright Tear, a rare weapon or a purse on odd ones; a relic every tenth.
* **Loot**: the risen carry weapons and shields rolled fresh each time
  (common, fine, rare, relic: grey, blue, purple, gold beams), with their own
  metals, etchings and numbers; relics have names. A notice says when one
  beats what you hold. Break the rest down at the anvil.
* **Elites**: some risen are Elites (Swift, Hulking, Brutal, Warded,
  Vampiric; two traits from Renown 6), with a name over them, a light about
  them, and much better loot.
* **Grave Thieves**: every few minutes in the wilds, a glowing thief with a
  sack of silver. It runs; coin falls out every time you hit it; catch it
  within 26 seconds for a rare weapon, Star-Iron and a pile of silver.
* **Kill chains**: kills within seven seconds of each other build a chain
  (×N on the right of the screen), each step adding 10% to Renown and silver.
* **Bounties**: three short goals at a time (break stances, land criticals,
  catch a thief, reach a chain…), each replaced the moment it is done. The
  nearest one shows under the quest tracker; all three in the Journey.
* **Rift Surge nights**: every third night (from the second) the Rift
  surges until dawn: more Elites, more thieves, half again the Renown, and
  twice the loot.
* **Exploration**: the map counts what you have found of Aldermere's 50
  things (stones, places, chests, messages, bloodstains, pages, Gates,
  great foes), and a notice marks each new percent.
* **When you fall**: what this life was worth (risen, best chain, Renown)
  and how close the next Renown level is.
* **Save and load**: three slots, from the pause menu or the title.
* **Interface** ("Heraldry"): opaque ink cards with gold rims and hard
  shadows, chunky buttons that lift and squash, engraved Cinzel titles,
  3D-rendered item icons, a Law sigil by the health bar, a compass that only
  shows places you have found, slide-in notices, speech cards.

## Quality presets

Medium is the default. On an Apple M4 at a full 3420×2084 Retina window it
runs about 29 fps in the village and 23 from a high viewpoint (much faster in
a smaller window). The 3D image is drawn at about 1080 lines and upscaled
with MetalFX Spatial (sharper and cheaper than FSR here) with SMAA; far trees
are impostor cards. High adds MSAA, SSAO, four
shadow splits and longer draw distances.

## Art and sound

All third-party, all free: Quaternius, Kay Lousberg (KayKit) and Kenney
(CC0); Cinzel and Inter (SIL OFL). Details in `assets/LICENSES.md`.
