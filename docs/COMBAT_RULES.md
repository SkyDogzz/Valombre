# Règles chiffrées du snapshot

Source faisant foi : `dump/project/src/config.js` et `game.js`. Le JSON de valeurs correspondant est `data/CONTENT_DATA.json`; les différences avec le README historique sont listées dans [`CONTENT_PARITY.md`](CONTENT_PARITY.md). Les formules ci-dessous décrivent le snapshot et ne sont pas des propositions d’équilibrage.

## Ennemis ordinaires

Les dégâts de contact et la masse de spawn sont indiqués séparément. Pour les ennemis à distance, `portée / projectile / délai` désigne la portée d’approche, la vitesse du projectile et le cooldown d’attaque; le télégraphe est en secondes.

| Espèce | PV | Vitesse | Rayon | Contact | Masse | Règle spéciale |
| --- | ---: | ---: | ---: | ---: | ---: | --- |
| Goule | 34 | 74 | 14 | 9 | 1 | Poursuite au contact |
| Traqueur | 25 | 112 | 12 | 7 | 2 | Poursuite rapide |
| Chargeur | 58 | 42 | 15 | 13 | 3 | Portée 310; charge 360; télégraphe 0,72 s; cooldown 2,8 s |
| Brute | 65 | 49 | 19 | 15 | 4 | Poursuite lente et résistante |
| Lanceur | 42 | 38 | 15 | 8 | 5 | Portée 290; projectile 230; télégraphe 0,62 s; cooldown 3,1 s |
| Chaman | 55 | 34 | 16 | 10 par projectile | 6 | Portée 270; projectile 190; salve; télégraphe 0,9 s; cooldown 4,2 s |
| Sangsue | 38 | 82 | 13 | 8 | 2 | Rend 12 PV quand son contact blesse le joueur |
| Sauteur | 48 | 52 | 16 | 17 à l’atterrissage | 4 | Bond jusqu’à 250; rayon d’atterrissage 54; télégraphe 0,85 s; cooldown 2,7 s |

Les masses alimentent le plafond de spawn pondéré; elles ne sont pas des nombres d’ennemis. Les trois boss et leurs paramètres se trouvent dans `CONFIG.boss` / `BOSSES` et restent exportés tels quels dans `CONTENT_DATA.json`.

## Apparition et difficulté

- Première apparition après 1 s; cadence normale 0,62 s; intermission 3 s; distance de spawn 350–540.
- Le plafond de base vaut 10 unités de masse. Les presets le multiplient par `spawnCapacity` : 2 / 2,5 / 3. En infini, la base augmente de 24 par minute jusqu’à 200, puis est multipliée par le preset.
- Une élite ajoute 1 à sa masse, y compris lors du contrôle d’admissibilité de la file d’apparitions. Ses facteurs PV/vitesse/dégâts sont appliqués après le scaling de difficulté.
- En vague infinie de progression `p = max(0, vague − 1)`, santé × `1,28^p`, dégâts × `1,22^p`; vitesse × `1 + min(1,2, 0,035p)`. Les facteurs de difficulté et d’affixe se multiplient ensuite; PV et dégâts sont arrondis à l’apparition.
- En infini, cadence initiale de chaque vague et cadence régulière : `max(0,12 s, 0,62 s × 0,7^minutesÉcoulées)`. Seule la première apparition de la toute première vague utilise 1 s. Les minutes écoulées sont mesurées depuis le début du run et incluent les pauses et choix tant que l’application reste ouverte; une reprise de checkpoint repart de la durée sauvegardée, sans compter le temps application fermée.
- Afflux : chance 0,38; minuterie tirée dans `[14, 26]`; taille `min(62, 26 + min(vague, 18) × 2)`; cadence d’apparition 0,12 s. Les espèces reçoivent un poids proportionnel à `min(nombre programmé, 12)` dans la composition applicable.
- Les vagues fixes contiennent 45, 77, 108 et 151 ennemis ordinaires, puis le Gardien. La vague infinie compose les groupes à partir du numéro de vague; la table historique de README ne s’applique pas.

## Attaque, dégâts et collisions

- Cooldown de swing : `0,26 / cadence`. Cadence : `arme.speed × cadenceJoueur × (1 + 0,08 × (niveauArme − 1)) × bonusSynergie × (1,2 si spéciale)`.
- Portée d’arme : `(portéeBase + bonusPortéeJoueur + portéeÉquipement) × bonusPortéeSynergie`. Cible automatique : ennemi vivant le plus proche, attaque seulement si distance strictement inférieure à la portée. Tir manuel à distance accepte la limite exacte; mêlée manuelle peut amorcer un swing sans cible.
- Dégâts d’arme avant le calcul général : base espèce (Brute utilise `bruteDamage`, toute autre cible `ghoulDamage`) × `(1 + 0,18 × (niveauArme − 1))` × `1,5` si spéciale × synergie. Le traitement d’impact multiplie ensuite par dégâts joueur, dégâts équipement et `(1 + 0,005 × (niveauJoueur − 1))`, puis arrondit.
- Les projectiles joueurs voyagent à `520 × projectileSpeed`, ont un rayon `5 × projectileSize`. Collision projectile ennemi : distance strictement inférieure à `rayonProjectile + rayonEnnemi`; premier ennemi dans l’ordre de liste touché. Projectile perçant ajoute la cible à `hitTargets` et multiplie ses dégâts par 1,18 après chaque impact.
- Le contact d’un projectile ennemi est testé avec `distance < rayonProjectile + 10`; les limites projectile et ennemis emploient le bord `CONFIG.enemies.edge` avec leur rayon. Le joueur est borné et testé avec un rayon de 11. Les quatre ruines sont décoratives et ne bloquent pas le mouvement ni les projectiles.
- Explosion de bombe : `distance <= rayonExplosion + rayonEnnemi`; brûlure spéciale de rayon `0,78 × rayonExplosion`, dégâts par tick `0,18 × dégâtsProjectile`, premier tick après 0,16 s puis intervalle 0,2 s, durée 0,82 s. Vague de faux : distance `<= rayonVague + rayonEnnemi`.
- Défense totale plafonnée à 80 % pour les dégâts reçus. Un bouclier absorbe avant les PV. Vol de vie se calcule sur les dégâts réellement retirés aux PV ennemis, pas sur le surplus.

Les formes de mêlée, l’ordre des effets de mort, les rebonds électriques et les délais d’effets sont détaillés dans [`COMBAT_PARITY.md`](COMBAT_PARITY.md).

## Expérience, équipement et reliques

- Chaque ennemi ordinaire et boss donne une orbe de base valant 1; élite ×1,5; relique d’expérience et multiplicateur d’expérience de la synergie de l’arme du kill se multiplient à la collecte. Pas de valeur XP intrinsèque différente par espèce.
- Premier seuil XP : 5; seuil suivant augmente de 3 par niveau. Une collecte peut franchir plusieurs seuils dans la même boucle. Le niveau ajoute 1 % aux PV max et 0,5 % aux dégâts; le passage de niveau soigne la hausse de PV max. Le défi d’XP progresse par orbe collectée, indépendamment de sa valeur.
- Arme : obtention niveau 1, puis niveaux 2–5; au rang 5, la prochaine amélioration débloque spéciale. Rang d’arme : dégâts +18 % et cadence +8 % par niveau après le premier; spéciale : dégâts ×1,5 et cadence ×1,2. Cinq slots par défaut. Les doublons améliorent l’entrée possédée; l’arme déjà spéciale est exclue des tirages améliorables.
- Relique : cinq rangs maximum, cinq slots par défaut. Une relique possédée gagne un rang plutôt que d’occuper un autre slot. Au plafond, seules les entrées non verrouillées sont proposées pour remplacement; si tout est verrouillé, le butin est refusé.
- Règles de cumul d’une relique de valeur `v` au rang `r` : dégâts `equipmentDamage += v×r`; vitesse `equipmentSpeed *= 1+(v−1)×r`; portée `+=v×r`; défense `min(0,65, défense + v×r)`; XP `*=1+(v−1)×r`; vol de vie `+=v×r`; santé `+=v×r`; collecte `pickupRange *= 1+(v−1)×r`. Les reliques se composent entre elles selon ces opérations, dans l’ordre d’inventaire.
- Synergie activée seulement si arme niveau 5 spéciale et relique associée niveau 5. Ses effets et multiplicateurs détaillés sont dans le JSON et [`COMBAT_PARITY.md`](COMBAT_PARITY.md); sa découverte persistante se fait au déclenchement effectif.

Les neuf armes et les valeurs d’attaque individuelles sont dans `WEAPONS` du JSON; la présente fiche résume les formules communes sans recopier le catalogue complet.
