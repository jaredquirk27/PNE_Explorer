# REALMS Sprite Bible v1 — Implementation Prompt

You are working inside the REALMS project.

Your job is to establish and document the canonical 2D character sprite standard for REALMS based on the approved front-idle character sprites already created for Sirena, Adrian, Liara, Erika, Tali, and Astrid.

This is not a 3D, pseudo-3D, or isometric-character rendering pipeline. REALMS uses full-body 2D pixel-art character sprites.

## Core Visual Direction

The canonical REALMS sprite style is:

Grounded contemporary high-detail pixel characters with realistic proportions, strong individual silhouettes, selective facial detail, material-aware shading, and enough costume fidelity to preserve character identity.

The goal is to keep every character visually recognizable and expressive without drifting into chibi proportions, retro-RPG exaggeration, or overly noisy pixel detail.

## Reference Characteristics to Preserve

Use the existing approved sprites as the visual anchor.

### Proportions
- Characters should remain tall and relatively realistic in proportion.
- Target roughly seven heads in overall body height, with slight stylization where necessary for readability.
- Heads may be subtly enlarged compared with strict realism so facial identity survives at gameplay scale.
- Avoid oversized hands, feet, boots, torsos, or cartoon limbs unless a specific character design requires them.
- Body type differences must remain visible across the cast.

### Silhouette
Each character should be recognizable from silhouette before facial detail is considered.

Examples from the current cast:
- Sirena: long hair, white shirt, shorts, open-legged civilian stance.
- Adrian: broader shoulders, rolled sleeves, grounded older civilian/operations silhouette.
- Liara: technical gear, lab coat, layered equipment.
- Erika: pink hair, ears, oversized streetwear, exposed midriff, large pants and footwear.
- Tali: compact tactical silhouette, goggles, gloves, utility gear.
- Astrid: long dark coat, sharper vertical silhouette, more severe field-ready posture.

Do not homogenize body shapes or costume silhouettes.

## Detail Density

Use high detail selectively.

Concentrate the highest pixel detail in:
- face
- hair
- upper torso
- distinctive accessories
- belts and gear
- hands when important
- footwear
- signature costume features

Use broader value and shadow shapes on:
- long pants
- coats
- large fabric surfaces
- lower-detail body areas

Avoid covering every surface with small pixel noise.

The sprite should read cleanly at gameplay scale first and reward close inspection second.

## Face Rendering

Faces must preserve:
- age
- ethnicity
- general demeanor
- hairstyle framing
- jaw shape
- key eye/brow expression

Use only the minimum number of pixels necessary for:
- eyes
- brows
- nose bridge
- mouth
- jaw
- major shadow planes

Do not turn the sprite face into a miniature painted portrait.

## Outline and Shading Philosophy

Avoid a uniform hard-black cartoon outline around the entire character.

Use the darkest values primarily for:
- contact shadows
- overlapping limbs
- clothing separations
- hair interiors
- boots
- underarms
- deep folds
- gear boundaries

Internal surfaces should rely on colored shadow and value separation rather than black linework wherever possible.

Shading should feel material-aware:
- denim should not shade like leather
- cloth should not shade like metal
- hair should use larger grouped strands rather than isolated single-pixel noise
- coats should use broad folds
- tactical gear should use crisp edge definition where appropriate

## Costume Fidelity

REALMS sprites may contain elaborate clothing and gear.

Do not simplify all characters into generic shirt/pants silhouettes.

Preserve recognizable:
- coats
- lab gear
- belts
- holsters
- gloves
- jewelry
- tactical accessories
- distinctive shoes
- hair ornaments
- character-specific fashion details

However, group small details into larger readable visual masses instead of outlining every object individually.

## Secondary Motion Rules

Do not independently animate every strap, lock of hair, necklace, or coat edge.

For each character, define only 1 to 3 major secondary-motion signatures.

Examples:
- Sirena: long hair movement.
- Astrid: coat tails.
- Erika: hair and ears.
- Liara: lab coat hem.
- Tali: hair and selected belt/gear motion.
- Adrian: very restrained secondary motion, driven mostly by body and clothing shift.

This keeps animation production manageable while still giving each character personality.

## Animation Production Philosophy

The sprite system should prioritize:
1. character readability
2. silhouette consistency
3. smooth locomotion
4. combat readability
5. production efficiency

Do not increase frame count simply for visual luxury.

The project should be designed so the cast can scale without animation workload becoming unmanageable.

## Sprite Bible Deliverable

Create a documented REALMS Sprite Bible that locks the following:

### 1. Canvas and Scale Rules
Define:
- base canvas size
- standard character height range in pixels
- baseline/foot placement
- headroom
- safe horizontal margins
- how taller/shorter characters vary without breaking world scale
- export scale
- nearest-neighbor requirements

### 2. Proportion Rules
Define:
- standard head/body ratio
- acceptable body-type variation
- male/female/androgynous proportion flexibility
- age-based variation
- rules for bulky gear and long coats

### 3. Directional Sprite Requirements
Determine the minimum directional set needed by the current REALMS camera and movement system.

Favor the smallest directional set that looks convincing in actual gameplay.

Do not create unnecessary directions that multiply production work without meaningful visual benefit.

Document:
- required idle directions
- required movement directions
- mirroring rules, if any
- asymmetrical-costume exceptions
- weapon-hand exceptions

### 4. Animation Set
Establish a minimum viable animation library for a normal playable or companion character.

At minimum consider:
- idle
- walk
- run, if gameplay requires it
- interact
- combat ready
- basic attack/power use
- hit reaction
- downed/defeated
- optional character-specific idle

Separate:
- universal required animations
- combat-only animations
- character-specific animations
- optional polish animations

### 5. Frame Count Guidance
For each animation type, recommend practical frame-count ranges rather than arbitrary large sheets.

The priority is readable, smooth animation with reasonable production cost.

### 6. Sprite Sheet Layout
Define a consistent export layout including:
- naming scheme
- row/column conventions
- direction ordering
- animation ordering
- frame timing metadata
- per-character folders
- Godot import expectations

### 7. Palette and Rendering Rules
Define:
- approximate value range philosophy
- darkest-value use
- highlight restraint
- skin rendering rules
- hair rendering rules
- fabric rendering rules
- metal/tech rendering rules
- acceptable anti-aliasing policy for pixel art

### 8. Character Identity Checklist
Before a sprite is approved, verify:
- recognizable silhouette
- correct body type
- correct major costume shapes
- correct hair mass
- recognizable face at intended scale
- no excessive pixel noise
- no accidental chibi proportions
- no loss of key accessories
- feet align correctly to baseline
- sprite remains readable against both light and dark environments

### 9. Animation Identity Pass
For every major character, define:
- resting posture
- center of gravity
- arm carriage
- head movement
- gait personality
- secondary-motion signature
- combat posture
- power-use body language

Do not allow every character to use the same skeleton animation with cosmetic swaps unless that motion genuinely fits them.

## Current Canonical Reference Set

The current visual reference set includes:
- Sirena
- Adrian Serrin
- Liara Cheng
- Erika Celeste
- Tali Viskyn
- Astrid

Treat these approved sprites as the baseline house style.

New sprites should look as though they belong in the same game when placed directly beside them.

## Final Goal

The Sprite Bible should make it possible for a developer, artist, AI image workflow, or animation pipeline to take an existing REALMS character reference and produce a sprite that:

1. matches the established REALMS visual style,
2. preserves that character's identity,
3. fits the game's world scale,
4. animates cleanly,
5. imports predictably into Godot,
6. and does not create unnecessary frame-production overhead.

Keep the document practical and implementation-oriented.

Do not redesign the existing approved sprite style. Codify it.
