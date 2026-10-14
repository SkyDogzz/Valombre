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
- `attackWeapon` consomme le swing et lance son animation dès qu’une attaque de mêlée est admissible, même si aucune cible ne se trouve dans sa forme; seul le passage dans la forme applique dégâts et effets. Une arme à distance sans cible dans sa portée ne consomme pas de swing. Les finishers cycliques dépendent donc des attaques démarrées, et non des coups ayant touché.
- La cible candidate est l’ennemi vivant le plus proche, sans filtrage préalable par portée. La boucle automatique n’appelle l’arme que si cette cible est strictement à portée. L’entrée manuelle est traitée après la boucle automatique dans `game.js`, et ne peut donc pas détourner un coup automatique déjà déclenché par la souris. Si une attaque manuelle de mêlée part sans cible automatique à portée, la souris peut fixer l’orientation; les armes à distance gardent l’orientation de leur cible et échouent sans cible dans la portée.
- Godot regroupe les deux chemins dans `_update_auto_attack`. Il conserve donc l’orientation de cible automatique lorsqu’une cible proche est disponible, n’emploie la visée souris que pour une attaque manuelle de mêlée sans cible automatique proche, et permet à une arme de mêlée manuelle d’amorcer un coup sans cible.
- Les projectiles touchent si `distance < rayon ennemi + rayon projectile`. Ils traversent les obstacles circulaires et disparaissent aux bords définis par `CONFIG.enemies.edge`, car `isBlocked` ne teste que ces limites. Les bombes explosent à l’impact ou à la sortie du monde.
- Chaque rebond électrique choisit l’ennemi restant le plus proche dans la portée, en conservant le premier ennemi de la liste en cas d’égalité (tri stable du source). Godot garde le même départage au lieu de remplacer la cible à chaque distance égale.
- La vague spéciale de faux touche si `distance <= rayon de vague + rayon ennemi`; son balayage direct garde la portée propre de l’arme.
- La vague de faux est ajoutée inactive pendant l’attaque, puis `processWeaponEffects` l’active après la mise à jour des ennemis de la frame et applique ses dégâts une seule fois. Le port la conserve dans la file des effets d’arme pour respecter ce point d’application et jouer le son à l’activation.
- Les dagues spectrales et la nova de givre multiplient leurs dégâts de base par `getWeaponCombatStats().damageMultiplier` (niveau/spécial de l’arme et synergie), puis `damageEnemy` applique les multiplicateurs de dégâts, d’équipement et de niveau du joueur. Ils ne passent pas d’identifiant d’arme à `damageEnemy`, ce qui évite de déclencher une deuxième synergie de kill.
- L’explosion de collecte de la synergie aimant utilise un rayon de 92, les dégâts de l’arme bombe avec la mise à l’échelle du joueur et le signal spécial d’explosion. Elle n’ajoute pas la brûlure secondaire (`pickupCombo`).
- La collecte parcourt les drops en ordre inverse. Si un ramassage ouvre l’écran de niveau ou de butin, le source arrête les autres collectes de la frame, puis résout quand même l’explosion agrégée de synergie aimant; il découvre alors `bombe-magnet`. Godot interrompt aussi la boucle, mais doit laisser cette explosion et cette découverte s’exécuter avant de terminer la frame.
- Les synergies sont découvertes lors de leur premier effet réel, pas quand leurs prérequis deviennent actifs. Le port marque ainsi `arc-quiver` au tir de la volée, `sabre-talisman` au burst, `lance-seal` au bouclier, `faux-heart` à la libération d’âmes, `foudre-relic` au rebond, `marteau-stone` à l’onde circulaire, `dagues-boots` quand des cibles spectrales existent, `givre-vampire` à la nova de mort ralentie et `bombe-magnet` à l’explosion de collecte.
- Un projectile ennemi qui tue le joueur est retiré, puis `update` retourne immédiatement dès que l’état n’est plus `playing`. La boucle Godot doit donc aussi s’arrêter à cet impact pour qu’aucun projectile restant ne touche un ennemi après la défaite.
- Une explosion de bombe et les ticks de brûlure/foudre n’interrompent pas leurs boucles quand un kill change l’état de la run : leurs cibles restantes sont quand même traitées. Le retour après projectile fatal est propre au projectile ennemi qui touche le joueur; les explosions et zones ne doivent pas hériter de cet arrêt.

## Points de contrôle dans le code

- Source : `damageEnemy` et `kill` dans `dump/project/src/game.js`.
- Port : `_damage_enemy`, `_progress_objective`, `_on_enemy_killed`, `_roll_enemy_item_drop` et `_enemy_drop_xp` dans `scripts/RunController.gd`.
- Cette comparaison est statique ; les scénarios contrôlés et la batterie complète restent à exécuter après les travaux du roadmap.
