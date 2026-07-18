# Explorer Manifest

Explorer is the spatial presentation layer of the Persistent Narrative
Engine.

It does not create narrative.

It gives narrative a place to exist.

------------------------------------------------------------------------

## Core Principles

Explorer does not tell stories.

Explorer gives stories places to exist.

Explorer does not own people.

Explorer presents them.

Explorer does not own history.

Explorer reflects it.

Explorer does not own memory.

Explorer visualizes its consequences.

Explorer does not own relationships.

Explorer reveals them through presence and interaction.

Explorer does not own worlds.

Explorer inhabits them.

Explorer does not own canon.

It presents canonical state supplied by the Persistent Narrative Engine.

------------------------------------------------------------------------

## Design Contract

When making architectural decisions:

-   If it concerns presentation, spatial representation, movement,
    camera, interaction, or world visualization, it belongs in Explorer.
-   If it concerns memory, cognition, relationships, narrative
    progression, quests, initiative, or canonical world state, it
    belongs in PNE.

Explorer is never the authoritative source of truth.

PNE is always the authoritative source of truth.

------------------------------------------------------------------------

## Guiding Question

Before adding a new system, ask:

**Does this belong in Explorer, or does it belong in PNE?**

If the answer is unclear, prefer keeping logic in PNE and presentation
in Explorer.

------------------------------------------------------------------------

## Closing Statement

Explorer exists so that every Chronicle created within the Persistent
Narrative Engine can become a living place that the player inhabits
rather than merely reads.

The engine should disappear.

The world should remain.
