# Game data

`CONTENT_DATA.json` remains the source of truth for the values copied from the browser dump. `ContentCatalog` validates the document on startup and creates typed `Resource` instances from each record; those resources retain a deep copy of the original fields in `source_data` and expose frequently used values as typed properties.

The corresponding types live in [`../scripts/definitions/`](../scripts/definitions/): heroes, weapons, enemies, bosses, elite affixes, upgrades, relics, synergies, difficulties and waves. Add source data there first, then extend catalog validation when a new record kind or reference is introduced.
