# Assets SVG

These 44 SVG files are byte-for-byte copies of `dump/assets/`. Their paths and SHA-256 fingerprints are listed in [`../dump/ASSET_MANIFEST.csv`](../dump/ASSET_MANIFEST.csv).

Godot loads the SVG sources directly with `load("res://assets/…svg")`; Godot 4.7 imports them as `Texture2D` resources. Keep the original SVG files as the source of truth. Use each sprite's authored viewBox and scale it at the node that displays it instead of rewriting or rasterizing the artwork.

Enemy and boss textures come from the content data's `sprite` field. Hero portraits, held weapons, weapon/relic icons, XP and potion pickups use the corresponding paths under this directory.
