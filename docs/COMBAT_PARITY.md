# Ordre des événements de combat

Cette fiche consigne le chemin d’impact et de mort comparé entre `dump/project/src/game.js` et `scripts/RunController.gd`. Le code exporté reste la référence si l’implémentation diverge.

## Impact

1. Consommer la marque du sabre avant le calcul des dégâts (multiplicateur ×1,5).
2. Arrondir les dégâts et calculer la part réellement infligée aux PV restants.
3. Retirer les PV de l’ennemi, puis appliquer le vol de vie sur la part réellement infligée.
4. Déclencher le flash et le nombre de dégâts, puis traiter sa mort si ses PV sont à zéro ou moins.

Les armes calculent leur échelle avant l’impact : dégâts globaux, bonus de niveau du joueur et de l’arme, reliques, arme spéciale et synergie. Les tirs secondaires peuvent donc rappeler le traitement d’impact pendant l’effet d’un premier kill.

## Mort d’un ennemi ordinaire ou élite

1. Émettre le son de mort, retirer l’ennemi de la liste active et incrémenter les éliminations.
2. Incrémenter le bestiaire de l’espèce et, pour une élite, celui de l’affixe. Sauvegarder à la première découverte ou toutes les dix éliminations.
3. Progresser l’objectif « éliminations », puis l’objectif « élite » et le défi persistant des élites si applicable.
4. Résoudre les effets de synergie déclenchés par le kill (projectiles spectraux, nova de givre, âmes de faux). Les impacts produits ici suivent à leur tour le chemin d’impact normal.
5. Tirer au plus un butin d’équipement/soin selon les probabilités et filtres actifs, jouer l’explosion de mort, puis créer l’orbe d’XP. L’XP est augmentée de 50 % pour une élite et modulée par la synergie de l’arme du kill.

Le code source appelle les progrès d’élite avec les types `elite` et `elites` : le premier correspond à l’objectif cyclique, le second au défi. Godot effectue ces deux mises à jour dans `_progress_objective("elite")`, via l’alias `elite` → `elites` pour le défi.

## Mort d’un boss

Après les étapes communes jusqu’aux effets de kill, le boss désactive l’état de boss actif, attribue la récompense et crée l’orbe d’XP. En mode infini, il octroie un Éclat et lance l’intermission ; en campagne, il termine la run en victoire. Le chemin boss ne tire pas le butin aléatoire ordinaire.

## Dégâts des armes et projectiles

- Un coup d’arme applique les multiplicateurs globaux du joueur, des reliques, du niveau du joueur, du niveau/spécial de l’arme et de sa synergie. La vitesse de relique affecte le déplacement et l’aimantation, pas la cadence d’attaque.
- Une cible automatique doit être strictement à portée (`distance < portée`). Une attaque manuelle à distance accepte la cible à la limite (`distance <= portée`); une attaque manuelle de mêlée peut amorcer un coup sans cible.
- Les projectiles touchent si `distance < rayon ennemi + rayon projectile`. Les obstacles les arrêtent; les bombes explosent à l’impact ou à l’arrêt.
- Les dagues spectrales et les dégâts de nova de givre appliquent les bonus globaux du joueur, de relique, de niveau joueur et de synergie. Ils ne prennent pas les bonus de niveau/spécial de l’arme, comme le montrent les formules fournies à `damageEnemy` par le dump.
- L’explosion de collecte de la synergie aimant utilise un rayon de 92, les dégâts de l’arme bombe avec la mise à l’échelle du joueur et le signal spécial d’explosion. Elle n’ajoute pas la brûlure secondaire (`pickupCombo`).

## Points de contrôle dans le code

- Source : `damageEnemy` et `kill` dans `dump/project/src/game.js`.
- Port : `_damage_enemy`, `_progress_objective`, `_on_enemy_killed`, `_roll_enemy_item_drop` et `_enemy_drop_xp` dans `scripts/RunController.gd`.
- Cette comparaison est statique ; les scénarios contrôlés et la batterie complète restent à exécuter après les travaux du roadmap.
