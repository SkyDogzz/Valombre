# Dump de portage Godot — Les Cendres de Valombre

Ce dossier est une photographie du projet web présent au moment de l’export. Il sert de référence de contenu et de comportement pour recréer le jeu dans Godot. Il ne contient pas encore un projet Godot natif : aucune scène `.tscn`, ressource `.tres`, script GDScript ni import `.godot/imported` n’existe dans le dépôt source.

## Contenu du dump

- `CONTENT_DATA.json` : valeurs exportées depuis `src/config.js`, `src/synergies.js` et `src/bestiary.js`. Les fonctions JavaScript des améliorations sont exclues ; leurs données descriptives et leurs valeurs sont présentes.
- `ASSET_MANIFEST.csv` : chaque asset avec taille, SHA-256 et viewBox SVG. Les fichiers sont fournis dans `assets/`.
- `project/` : copie du code source web, de la page, des styles et du README tels qu’ils étaient lors de l’export.
- `assets/` : copie autonome des 44 SVG utilisés par le jeu.
- `valombre_godot_dump.zip` : archive de ce dossier complet.

Le code de référence reste la source d’autorité pour les détails qui ne sont pas configurables (séquences d’attaque, collisions, ordre des effets, formules composées, transitions). Les repères sont listés dans la section Architecture.

## Identité et expérience

- Titre : **Les Cendres de Valombre** ; sous-titre : « Chroniques d’un royaume oublié ».
- Action-RPG solo 2D vue du dessus ; cadre narratif affiché : chapitre I, Les bois maudits, an 713 de la Cendre.
- Boucle : sélectionner héros/arme/mode/difficulté → survivre à des vagues → gagner XP et équipement → vaincre les boss → consulter le résultat et recommencer.
- Monde : clairière de ruines forestières, palette terreuse sombre, éclairage/vignette, sprites SVG et effets dessinés en temps réel.
- Fenêtre de référence : canvas 960×540, monde 1500×1100, caméra suivant le joueur et bornée aux limites.
- Obstacles circulaires bloquants : (605,530,r=27), (898,605,r=31), (770,415,r=23), (735,705,r=24). Ils bloquent mouvement et projectiles ; entités glissent le long des limites.

## États de jeu

`title`, `playing`, `paused`, `levelUp`, `loot`, `victory`, `defeat`. Une fonction centrale pilote l’overlay, le focus clavier, les commandes tactiles, l’inventaire et la boucle. Les choix de niveau et de butin suspendent la simulation. La partie est automatiquement sauvegardée aux débuts de vague/intermission et lors des modifications persistantes de l’état de run.

## Commandes et interface

- Déplacement : WASD/flèches ; déplacement diagonal normalisé.
- Attaque : armes automatiques sur des cibles accessibles/proches ; Espace, J, clic ou bouton tactile déclenche une attaque immédiate. L’attaque automatique et les attaques manuelles sont gérées par arme.
- Capacité : E. Le Pèlerin n’a pas de capacité spéciale ; la Sentinelle a « Charge de cendre ».
- Esquive : Maj, vitesse 570 pendant 0,18 s, invulnérabilité 0,24 s, recharge 2,6 s.
- Pause : Échap / bouton tactile. Perte de focus ou onglet masqué vide les touches actives.
- Tactile : joystick virtuel, attaque maintenue, capacité, esquive, pause ; affiché sur écran étroit ou tactile.
- Tab ouvre le panneau de run : armes, reliques, synergies, bestiaire/ennemis et objectifs. Le HUD montre PV, bouclier, XP/niveau, vague/difficulté et barre de boss.
- Menu : sélection héros et arme de départ, mode, difficulté, option arme unique, inventaire sans limite, gouttes personnalisées, sélection d’armes/reliques pouvant tomber, ramassage automatique d’amélioration, volume/muet, reprise ou nouvelle run, partage de configuration via URL, remise à zéro de sauvegarde.
- Un bouton « vie infinie » est exposé pendant la partie (outil de triche/debug, persisté dans le checkpoint de run).

## Héros

Données numériques complètes dans `CONTENT_DATA.json`.

- Le Pèlerin / Errant des cendres : 100 PV, 190 vitesse. Attaque de base de mêlée circulaire.
- La Sentinelle / Gardienne des remparts : 125 PV, 165 vitesse ; capacité charge, recharge 5 s, distance 190, largeur 34, dégâts 58, invulnérabilité 0,32 s.

## Arsenal

Neuf armes, toutes attaquent automatiquement et progressent indépendamment. Le joueur commence avec l’arme choisie ; les armes collectées rejoignent l’inventaire et attaquent aussi automatiquement. Armes de mêlée : sabre, marteau, dagues, lance perçante, faux. Armes de projectile : arc, foudre en chaîne, bombarde, givre ralentissant. Leurs nombres exacts (portée, cadence, dégâts goule/brute, arc et propriétés) sont dans `CONTENT_DATA.json`.

- Progression d’arme : collecte niv. 1 ; niveaux 2–5 par ramassage répété ; au-delà, déverrouille la version spéciale. Bonus par niveau avant spéciale : dégâts +18 % et cadence +8 % par rang au-dessus du premier ; spéciale : dégâts ×1,5 et cadence ×1,2. Nombre de cibles en chaîne = niveau. Niveau 5 + spéciale permet une synergie correspondante.
- Limite : 5 armes ; arme verrouillée non remplaçable. Inventaire sans limite désactive le plafond. Si plein, choix de remplacer une arme non verrouillée ou passer. Option arme unique filtre les butins aux armes de départ.
- Détails des projectiles, rebonds, explosifs, ralentissements et animations dans `attackWeapon`, `launchArcVolley`, `chainLightning`, `detonateBomb`, `processWeaponEffects` de `src/game.js`.

## Ennemis et boss

Les huit ennemis ordinaires sont définis dans `CONFIG.enemies`, avec descriptions de bestiaire dans `src/bestiary.js` :

- Goule : poursuite et morsure au contact.
- Brute : lente, résistante, coup de contact puissant.
- Traqueur : rapide et fragile, griffe au contact.
- Chargeur : télégraphie puis ruée en ligne.
- Lanceur : maintient sa distance et lance un projectile annoncé.
- Chaman : salve annoncée de trois projectiles.
- Sangsue : mêlée, se soigne de 12 PV lorsqu’elle inflige un coup.
- Sauteur : annonce puis bondit dans une zone, dégâts au point d’atterrissage.

Trois affixes élites appliqués aux ennemis ordinaires : Cuirassé (PV ×1,8, vitesse ×0,78, dégâts ×1,1), Fulgurant (PV ×1,2, vitesse ×1,5, dégâts ×1,1), Féroce (PV ×1,3, vitesse ×1,1, dégâts ×1,7). Élite signalée visuellement, donne 1,5× XP, compte pour objectifs et bestiaire. En vagues, un ennemi sur 24 dans chaque groupe est élite ; en infini, un sur 18.

Boss :

- Gardien des cendres : 520 PV, alterne impact de zone (rayon 138, 26 dégâts) et charge (distance 250, largeur 38, 22 dégâts). Télégraphie 0,82 s.
- Matriarche des ronces : 590 PV, attaque à salves de cinq projectiles, maintien à distance.
- Colosse des cendres : 760 PV, impact de grande zone (rayon 190, 34 dégâts), lent et massif.

Le mode Vagues finit par le Gardien ; le mode infini fait apparaître un boss tous les cinq niveaux, en alternant Gardien/Matriarche/Colosse. Les coefficients boss/ennemis selon vague et difficulté sont calculés dans `spawn`.

## Vagues, survie, objectifs

Les compositions exactes figurent dans `CONTENT_DATA.json` et sont reproduites ici (quantités issues du code, pas de l’ancien README) :

| Vague | Goule | Brute | Lanceur | Traqueur | Chargeur | Chaman | Sangsue | Sauteur | Total |
|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| 1 | 45 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 45 |
| 2 | 48 | 24 | 0 | 0 | 0 | 0 | 5 | 0 | 77 |
| 3 | 54 | 30 | 0 | 12 | 6 | 0 | 0 | 6 | 108 |
| 4 | 66 | 32 | 4 | 15 | 9 | 3 | 12 | 10 | 151 |

Total actuel : **381 ennemis ordinaires prévus**, avec plafond de 10 vivants avant facteurs de difficulté et afflux. C’est différent des quantités périmées dans le README racine.

- Mode infini : après les quatre compositions initiales, les groupes sont recalculés par vague ; les comptes augmentent avec le numéro de vague, avec caps par type. Santé, vitesse, dégâts, cadence, projectiles et capacité évoluent avec progression/difficulté. Capacité max 200 et croissance par minute configurées.
- Afflux : chance 0,38, intervalle aléatoire 14–26 s, taille de base 26, +2 par vague jusqu’à 62, espacement 0,12 s. Types pondérés à partir des groupes.
- Intermission de 3 s ; apparition initiale après 1 s, délai normal 0,62 s ; apparaissent à 350–540 unités du joueur, en tentant plusieurs positions hors obstacles.
- Objectif de vague cyclique : éliminer 12, ramasser 8 XP, éliminer 1 élite ; récompense +18 % PV max en soin.
- Défis de run : 50 kills, 5 élites, 20 orbes XP ; chacun rapporte un Éclat persistant.
- Vague infinie chaque cinquième niveau : boss. En infini, boss vaincu = +1 Éclat, run continue.

## Progression, équipement et butin

- XP déclenche un choix de trois améliorations sans doublons ; seuil initial 5 XP puis 3 XP par niveau. Les améliorations sont décrites intégralement dans `CONTENT_DATA.json` : dégâts, cadence, portée, taille/vitesse projectile, vitesse déplacement, PV max/soin, défense, portée de ramassage (9 améliorations, rang max 10).
- Amélioration automatique sélectionne la première carte après 3 s si activée.
- Butins automatiques : potion +32 PV, arme, relique ou XP ; portée de collecte 90, rayon de contact 22, durée 18 s. Potions 8 % ; équipement 22 %, modulé selon difficulté.
- Sac : 5 armes et 5 reliques par défaut, éléments verrouillables. Une relique monte au niveau 5 ; une arme au niveau 5 puis spéciale. Remplacement ou passage lorsque sacoche/arsenal plein.
- Les neuf reliques et leurs niveaux/effets sont dans `CONTENT_DATA.json`: dégâts, déplacement, portée, défense, XP, cadence, PV, collecte, vol de vie.
- Les neuf synergies sont intégralement exportées en JSON. Condition générale : arme spéciale au niveau 5 et relique au niveau 5. Chaque couple a son effet spécifique (marquage/explosion, onde et recul, dagues spectrales, volée de flèches, rebonds, aimant/explosion à l’arrivée, bouclier par transpercement, âmes, nova de givre). Les effets exacts sont dans `src/synergies.js` et les systèmes concernés dans `src/game.js`.
- Le niveau augmente aussi certains multiplicateurs de dégâts/santé selon les formules `levelDamageMultiplier` et `levelHealthMultiplier`.

## Difficultés

Trois presets : `insane`, `nightmare`, `cataclysm`. Chaque multiplicateur santé/dégâts/vitesse/cadence/vitesse projectile/capacité ennemie et fréquence de butin est exporté dans `CONTENT_DATA.json`. La difficulté de base actuellement sélectionnée est `insane`.

## Sauvegarde et résultats

Stockage local web `valombre.save.v1`. Le JSON persiste : héros/arme choisis, victoires, meilleur nombre d’ennemis, éclats, bestiaire et découvertes d’armes/reliques/synergies, volume/muet, option d’auto-choix et réglages de butins/inventaire. Le checkpoint de run inclut mode, difficulté, config de run, vague, joueur/inventaires/rangs/états, objectifs/défis, kills et durée. À importer vers Godot : préférer `user://save.json` ou `ConfigFile`, avec version de schéma et migration. Les résultats : durée, vague, ennemis vaincus, niveau, boss vaincu/non vaincu, reliques, récompense. La victoire en mode vagues donne un Éclat ; victoire/défaite sauvegarde le meilleur score.

## Audio et rendu

Pas de fichiers audio. `sound()` génère des tonalités via Web Audio à la première interaction (fréquence, durée, forme d’onde, volume global). Pour Godot, sons synthétiques/AudioStreamGenerator possibles ; le rendu d’origine utilise Canvas et SVG.

Le renderer dessine le décor statique puis butins, projectiles, arcs électriques, effets d’armes, joueur, ennemis, particules et nombres de dégâts. Sprites SVG chargés avec repli procédural ; shaders/effets Canvas incluent flashes, télégraphes, impacts, givre, explosion, foudre, vignette. Conserver les SVG comme sources ; importer sous Godot en textures/vector textures selon cible.

## Inventaire des assets

`ASSET_MANIFEST.csv` est l’inventaire exhaustif avec empreintes. Les 44 assets sont des SVG locaux :

- Personnages/créatures : héros, sentinelle, goule, brute, lanceur, traqueur, chargeur, chaman, sangsue, sauteur, trois boss, marque de titre.
- Objets UI : icône XP ; neuf icônes d’armes et catégorie ; neuf icônes de reliques et catégorie.
- Armes tenues : neuf SVG, un par arme.

Aucun audio, bitmap, police ou asset distant n’est employé. L’interface est majoritairement HTML/CSS dans la version source ; ses dimensions, couleurs, texte et éléments sont dans `project/index.html` et `project/styles.css`.

## Architecture source et correspondance Godot

| Source web | Rôle actuel | Cible indicative Godot |
| --- | --- | --- |
| `src/config.js` | Données de jeu | `data/*.tres` ou dictionnaires Resource |
| `src/game.js` | États, simulation, combat, spawns, run, drops, checkpoint | `Game.gd` + managers séparés |
| `src/renderer.js` | Monde Canvas, caméra, effets et sprites | scène 2D, `Camera2D`, `Node2D`, particules, shaders |
| `src/input.js` | clavier/souris/tactile | `InputMap`, actions, UI joystick |
| `src/ui.js` | construction d’éléments de dialogue/cartes | scènes `Control` réutilisables |
| `src/hud.js` | HUD, inventaire, bestiaire/catalogue pause | `CanvasLayer` |
| `src/inventory.js` | progression arme, statistiques dérivées | ressources/inventaire run |
| `src/synergies.js` | conditions et effets de combos | `Synergy` Resource + système d’effets |
| `src/bestiary.js` | données bestiaire, affixes élites | `EnemyData` et `EliteAffix` Resources |

Boucle principale `update(dt)` dans `src/game.js`; les ennemis, projectiles, drops, particules, nombres de dégâts et effets sont des objets du monde simulés. Fonctions structurantes : `reset`, `setState`, `start`, `saveRunCheckpoint`, `startWave`, `spawn`, `movePlayer`, `moveEnemy`, `updateWaves`, `damageEnemy`, `gainXp`, `progressObjective`, `kill`, `damagePlayer`, `dodge`, `attackWeapon`, `special`, `processWeaponEffects`, `finishRun`, `draw`, `loop`.

## Limites et points de vérification du port

1. Il s’agit d’un dump du jeu web existant et d’une spécification de portage, pas encore d’une copie jouable dans Godot.
2. Le README racine contient des tableaux numériques plus anciens ; utiliser le JSON et le code copié comme vérité.
3. Pour une parité stricte, porter les séquences et formules depuis le code, puis comparer les mêmes scénarios : attaques de chaque arme, collisions d’obstacles, spawns/élites, choix/remplacement, synergies, boss, sauvegarde/reprise, clavier/tactile.
4. L’aléatoire n’est pas seedé dans la version web ; la comparaison de runs doit contrôler ou enregistrer le générateur pseudo-aléatoire côté Godot.
5. Pas de licence logicielle choisie dans le dépôt. Les assets sont déclarés créés pour le projet dans le README ; conserver cette provenance dans tout export.
