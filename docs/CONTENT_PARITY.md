# Comparaison des données de contenu

`data/CONTENT_DATA.json` reprend les constantes exportées du dump. La comparaison des structures JavaScript après retrait des fonctions `apply` des améliorations donne une égalité pour `DIFFICULTIES`, `CONFIG`, `BOSSES`, `WEAPONS`, `HEROES`, `WAVES`, `UPGRADES`, `RELICS`, `SYNERGIES`, `ENEMY_BESTIARY` et `ELITE_AFFIXES`. Les fonctions de comportement restent définies dans `dump/project/src/` et ne sont pas des données JSON.

## Divergences avec le README historique du dump

| Sujet | README historique | Snapshot exécutable (`config.js` / `game.js`) |
| --- | --- | --- |
| Vague 1 | 90 goules | 45 goules |
| Vague 2 | 96 goules, 48 brutes | 48 goules, 24 brutes, 5 sangsues |
| Vague 3 | 108 goules, 60 brutes, 22 traqueurs, 12 chargeurs | 54 goules, 30 brutes, 12 traqueurs, 6 chargeurs, 6 sauteurs |
| Vague 4 | 132 goules, 64 brutes, 8 lanceurs, 30 traqueurs, 18 chargeurs | 66 goules, 32 brutes, 4 lanceurs, 15 traqueurs, 9 chargeurs, 3 chamans, 12 sangsues, 10 sauteurs |
| Total ordinaire | 693 | 381 (45 + 77 + 108 + 151), hors boss final |
| Gardien | 520 PV annoncés comme valeur de run | 520 PV de base, ensuite multipliés par la santé de difficulté lors de l’apparition |
| Obstacles | Décrits comme bloquant déplacements et projectiles | Ils sont dessinés par le renderer; `isBlocked` ne teste que les bords du monde. |
| Contenu | Résumé d’un ensemble antérieur d’armes, reliques et améliorations | Le snapshot de gameplay contient 9 armes, 9 reliques et 9 améliorations. |

Les quatre compositions et les valeurs ci-dessus sont celles de `WAVES` dans `config.js` et de `data/CONTENT_DATA.json`. Le générateur de run applique ensuite les règles de difficulté, de plafonnement des apparitions et les affixes; les comptes de composition sont les quantités programmées avant ces règles de cadence.

## Sources

- Données exportées : [`../data/CONTENT_DATA.json`](../data/CONTENT_DATA.json)
- Constantes : `dump/project/src/config.js`
- Apparition, limites et application de difficulté : `dump/project/src/game.js` (`spawn`, `maxSpawnWeight`, `isBlocked`)
- Description historique : `dump/project/README.md`, notamment la table « Vagues » et « Réglages principaux ».
