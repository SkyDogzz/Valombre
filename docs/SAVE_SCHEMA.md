# Profil et checkpoint

La sauvegarde persistante est le JSON `user://save.json`, écrit par `RunController._save_profile()`. La racine porte `schema_version: 2`. Le checkpoint de run porte indépendamment `version: 1`.

## Profil (schéma 2)

| Champ | Contenu |
| --- | --- |
| `schema_version` | Version du profil, actuellement `2`. |
| `wins`, `bestKills`, `shards` | Victoires, meilleur nombre d'éliminations et éclats persistants. |
| `run` | Checkpoint décrit ci-dessous, ou `null` hors run. |
| `hero`, `weapon`, `mode`, `difficulty` | Sélections de départ. |
| `singleWeapon`, `uncappedInventory`, `customDrops` | Options de run. |
| `dropWeapons`, `dropRelics` | Identifiants autorisés par les filtres de butin. |
| `bestiary` | Par identifiant, `{kills, discovered}`. Les boss utilisent `boss:<id>`, les affixes élites `elite:<id>`. |
| `discoveredWeapons`, `discoveredRelics`, `discoveredSynergies` | Dictionnaires d'identifiants découverts à `true`. |
| `muted`, `volume`, `autoPickUpgrade` | Préférences audio et choix automatique d'amélioration. |

## Checkpoint (version 1)

| Champ | Contenu |
| --- | --- |
| `version` | Version du checkpoint, actuellement `1`. |
| `rngSeed` | Seed de la run ; optionnelle dans les anciens checkpoints. |
| `waveRngState` | État du générateur juste avant les tirages de construction de la vague, pour pouvoir la reconstruire à l’identique ; optionnel dans les anciens checkpoints. |
| `mode`, `difficulty` | Mode et difficulté actifs. |
| `singleWeapon`, `uncappedInventory`, `customDrops` | Options utilisées pour cette run. |
| `dropWeapons`, `dropRelics` | Filtres actifs de la run. |
| `wave` | Vague à reprendre. |
| `waveObjective` | `{type, target, progress, complete}` pour l'objectif de vague. |
| `player` | État du joueur (voir ci-dessous). |
| `defeated` | Éliminations de la run. |
| `runChallenges` | Liste `{id, target, progress, complete}` des défis de run. |
| `elapsedSeconds` | Durée écoulée arrondie en secondes. |

`player` contient `hero`, `weapon`, `hp`, `maxHp`, `xp`, `nextXp`, `level`, `damageMultiplier`, `attackSpeedMultiplier`, `rangeBonus`, `movementMultiplier`, `levelDefense`, `bonusMaxHp`, `projectileSize`, `projectileSpeed`, `pickupRangeMultiplier`, `upgradeRanks`, `weaponInventory`, `inventory` (reliques), `shield`, `cheatInfiniteLife`, `scytheSouls`, `position` et `facing`. `levelDefense` conserve la défense acquise par niveau; les anciens checkpoints Godot qui stockent `defense` sont aussi chargés. Chaque objet d'inventaire contient son identifiant et ses propriétés d'état, notamment niveau/verrouillage et, pour une arme, l'état spécial.

Le checkpoint reprend les valeurs persistantes du joueur et de la progression, pas les entités ennemies, projectiles, minuteries de combat ni effets temporaires en cours. La reprise reconstruit la vague à partir du checkpoint et restaure son état RNG de départ lorsqu’il est présent. Les anciens checkpoints sans état RNG restent valides et démarrent avec une seed aléatoire. Pour démarrer une run contrôlée, passer `--seed=<entier>` après `--` dans la ligne de commande Godot. Si l’inventaire n’est pas débridé, la reprise conserve au plus cinq armes et cinq reliques, comme le jeu source.

## Validation et migration

Un profil absent, illisible, non objet JSON, de version non entière, antérieure à 1 ou supérieure à 2 est ignoré et les valeurs par défaut restent actives. La migration v1→v2 copie le profil, complète les préférences et collections manquantes avec les défauts, ajoute `player.cheatInfiniteLife: false` aux anciennes runs et inscrit la version 2. Le profil migré est écrit lors de la prochaine mutation sauvegardée.

Les compteurs persistants doivent être des entiers non négatifs; les booléens et volumes doivent avoir leur type attendu (volume fini puis borné à `[0, 1]`). Héros, armes, modes, difficultés et identifiants sont filtrés contre le catalogue courant. Les découvertes inconnues ou non vraies sont supprimées. Les lignes du bestiaire doivent avoir des éliminations entières non négatives et un booléen de découverte. Le checkpoint n'est accepté que si sa version, vague, mode, difficulté, joueur, position, inventaires, objectif et défis sont valides; sinon la run sauvegardée est abandonnée sans empêcher le chargement du profil. À la reprise, les rangs d'amélioration sont normalisés dans `[0, 10]`; si l'ancien checkpoint ne contient pas ces rangs, ceux des multiplicateurs sauvegardés sont inférés comme dans la source.

## Écritures

- Démarrage d'une run neuve efface l'ancien checkpoint et écrit le profil.
- Démarrage de chaque vague écrit le checkpoint, ce qui couvre l'intermission et les transitions de vague.
- L'option de vie infinie et le verrouillage d'équipement écrivent immédiatement le checkpoint.
- La progression des défis et certains jalons d'élimination mettent à jour le checkpoint pendant la vague.
- Les sélections de départ, options, filtres, préférences, découvertes, bestiaire et remise à zéro écrivent le profil dès leur mutation.
- Victoire ou défaite met à jour les compteurs, efface `run`, puis écrit le profil.
