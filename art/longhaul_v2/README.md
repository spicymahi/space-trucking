# Longhaul exterior — Blender study, 2026-10-06

An authored exterior interpretation of the cream-and-orange Longhaul concept in the existing game's cassette-futurist, blocky visual language. Built in Blender through MCP; no generated or downloaded mesh assets.

## Review

Open `longhaul_v2.blend`. The active scene is **LONGHAUL • Exterior study**, with the forward camera ready. The original startup scene was preserved separately. Three review cameras and their actual Blender renders are included:

- `renders/01-forward.png` — forward silhouette, cockpit, hab, airlock and cargo panels.
- `renders/02-loading.png` — four aft engines and lowered cargo ramp.
- `renders/03-profile.png` — room proportions and landing stance.

Frame **1** closes the ramp. Frame **80** lowers it. Scrub the timeline between these frames to inspect the hinge animation. The rest of the exterior hardware is static in this study.

The hull is organized into named cockpit, hab, service, cargo, engineering, engine, underframe, landing-gear, marking and ramp groups. Text stays editable in the Blender source, and one-segment bevels remain modifiers. The six landing feet and four engine pods are modeled; no flight or landing behavior is implemented here.

## Scale and palette

Approximate closed dimensions: **26.46 m long × 10.88 m across the engine pods × 5.66 m tall**, including landing gear and antenna. Main cargo hull is roughly 6.5 m wide. Room boundaries follow the current Godot layout: flight deck ahead of z=-9, hab -9 to -4, service -4 to -1, cargo -1 to 7, engineering 7 to 11.1. This is a dimensional reference, not a completed fit or collider audit against the interior.

Palette comes from `longhaul_room.gd`: warm ivory `b4ab91`, pale cream `d4c7a7`, charcoal `292e2a`, burnt orange `a95e2b`, green status lights and amber work lights. Flat-color materials, faceted nozzles, restrained bevels and coarse mechanical detail preserve the game style. Studio illumination is presentation lighting, not a Godot screenshot.

## Export and limits

`longhaul_v2.glb` contains only the exterior assembly and ramp animation, with bevels evaluated and text converted to mesh on temporary copies. The source remains editable. About **66,440 triangles**, including lettering. This is a review asset; draw-call consolidation, LODs, collision and integration are still needed before shipping.

The GLB is Y-up with the nose pointing -Z. Its root is lowered 1.4 m to place the deck at the existing Godot origin. Do not add another orientation or deck offset when importing it. The Blender scene itself places the landing feet just above the studio ground.

The current cockpit and hab shells are exterior solids with opaque glazing; they must be replaced by suitable hollow surfaces and aligned with existing interior windows before this can wrap the walkable ship. The aft ramp passage is modeled open. It is not a new playable interior.

The `art/.gdignore` file keeps Blender source files and the review GLB out of automatic Godot imports. The playable scenes, flight code, collisions and save files are unchanged. After design approval, integrate a production copy under `assets/ships/` and validate cockpit visibility, airlock alignment, engine envelopes and loading access.

## Rebuild and verification

Run `build_longhaul.py` inside Blender to create the separate study scene, then `export_longhaul.py` to make the game-oriented GLB. The builder refuses to overwrite an existing study scene. Renders use the three named cameras; frame 80 for the loading view and frame 1 for the others.

Reviewed forward, rear/open-ramp and profile renders. Corrected lettering crossing cargo ribs and trimmed rear frame braces. Verified finite evaluated mesh vertices, GLB binary structure, a single exported scene, absence of studio/startup objects, and an animation targeting the ramp. `asset_stats.json` records the measured geometry.
