# États de run et gel de la simulation

Le contrôleur utilise les sept états de `dump/project/src/config.js`: `title`, `playing`, `paused`, `levelUp`, `loot`, `victory` et `defeat`.

| État | Entrée / sortie principale | Simulation |
| --- | --- | --- |
| `title` | Nouvelle partie ou reprise du checkpoint vers `playing` | Gelée |
| `playing` | Pause, montée de niveau, choix de butin ou résultat | Active |
| `paused` | Reprise vers `playing`, abandon vers `title` | Gelée |
| `levelUp` | Choix d’amélioration vers `playing` ou choix suivant | Gelée; choix automatique après 3 s si activé |
| `loot` | Remplacement ou passage vers `playing` | Gelée |
| `victory` / `defeat` | Rejouer ou retour au titre via les contrôles de résultat | Gelée |

`RunController._set_state` pilote la visibilité des overlays et des contrôles, arrête/reprend le joueur et les couches d’effets. La simulation principale retourne immédiatement hors de `playing`; les minuteries du joueur s’arrêtent aussi quand `run_active` est faux. La touche Échap ne fait que passer de `playing` à `paused` ou reprendre de `paused`; elle ne quitte pas directement les écrans de résultat.

Références d’implémentation : `scripts/RunController.gd` (`_process`, `_set_state`, `_unhandled_input`, `_finish_run`) et `scripts/Player.gd` (`_physics_process`).
