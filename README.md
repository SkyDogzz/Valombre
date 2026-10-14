# Les Cendres de Valombre

Portage Godot du jeu navigateur **Les Cendres de Valombre — Chroniques d’un royaume oublié**. Le dépôt Godot est au tout début : il contient actuellement la configuration du projet et son icône, mais aucune scène ou logique de jeu. L’objectif est de retrouver au plus près le jeu décrit par le dump, en conservant ses règles, son contenu, ses commandes, ses états et sa présentation.

## Référence du portage

L’archive `valombre_godot_dump.zip` a été extraite dans [`dump/`](dump/). Elle contient :

- [`GODOT_PORT_SPEC.md`](dump/GODOT_PORT_SPEC.md), synthèse du portage et des points sensibles ;
- [`CONTENT_DATA.json`](dump/CONTENT_DATA.json), données numériques et descriptives exportées ;
- [`ASSET_MANIFEST.csv`](dump/ASSET_MANIFEST.csv), manifeste des assets et leurs empreintes SHA-256 ;
- [`project/`](dump/project/), copie de référence du jeu web : HTML, CSS et modules JavaScript ;
- [`assets/`](dump/assets/), les 44 SVG utilisés par le jeu.

**Ordre d’autorité pour implémenter la fidélité :** comportement observé dans `dump/project/src/game.js` et les autres modules source ; données du code et `CONTENT_DATA.json` ; spécification `dump/GODOT_PORT_SPEC.md` ; ancien README navigateur `dump/project/README.md`. Ce dernier conserve des valeurs précédentes (notamment 693 ennemis annoncés au lieu des 381 des vagues présentes dans le code). En cas de divergence, consigner le choix et s’aligner sur le code exporté, pas sur le texte périmé.

Le dump est une photographie : il ne fournit ni scènes Godot ni GDScript, et aucune licence logicielle n’est renseignée. Garder les sources SVG et leur provenance avec le projet.

## Vision du jeu

Action-RPG solo 2D vu du dessus, dans une clairière de ruines forestières. Le joueur choisit un héros, une arme initiale, le mode et la difficulté, puis se déplace tandis que ses armes équipées attaquent automatiquement. Les ennemis donnent de l’expérience et du butin ; les niveaux, armes, reliques et synergies permettent de tenir jusqu’aux boss. Une run se termine par une victoire ou une défaite, avec son bilan et une récompense persistante.

- Univers affiché : chapitre I, « Les bois maudits », an 713 de la Cendre.
- Référence de rendu : canvas 960×540, monde 1500×1100, caméra centrée sur le joueur et limitée au monde.
- Obstacles circulaires bloquant déplacement et projectiles : (605,530,r=27), (898,605,r=31), (770,415,r=23), (735,705,r=24). Le mouvement doit glisser le long des obstacles.
- Direction artistique : palette sombre terreuse, décor forestier en ruines, vignette/éclairage, SVG du dump et effets dessinés en temps réel. L’interface web utilise surtout HTML/CSS ; la référence visuelle est `dump/project/styles.css` et `index.html`.
- Aucun fichier audio n’est fourni. Le jeu navigateur synthétise quelques sons via Web Audio.

## Contenu et règles de référence

### Héros et commandes

| Héros | PV | Vitesse | Capacité |
| --- | ---: | ---: | --- |
| Le Pèlerin, Errant des cendres | 100 | 190 | Attaque de base circulaire ; pas de capacité spéciale |
| La Sentinelle, Gardienne des remparts | 125 | 165 | Charge de cendre : recharge 5 s, portée 190, largeur 34, dégâts 58, invulnérabilité 0,32 s |

Déplacement WASD/flèches, direction diagonale normalisée. Espace/J/clic/bouton tactile déclenche une attaque manuelle ; E active la capacité. Maj esquive (vitesse 570 pendant 0,18 s, invulnérabilité 0,24 s, recharge 2,6 s). Échap met en pause. Tab ouvre le panneau d’inventaire/catalogue. Perte de focus : relâcher les entrées maintenues. Sur tactile : joystick, attaque maintenue, capacité, esquive et pause.

### Armes

Les neuf armes s’améliorent indépendamment et attaquent toutes automatiquement lorsqu’elles sont équipées. Les armes collectées rejoignent l’arsenal et participent elles aussi au combat.

| ID | Nom | Portée | Cadence de base | Dégâts goule / brute | Particularité |
| --- | --- | ---: | ---: | ---: | --- |
| sabre | Sabre | 108 | 1,00 | 32 / 25 | Mêlée équilibrée |
| marteau | Marteau | 128 | 0,62 | 48 / 36 | Lent, puissant et large |
| dagues | Dagues | 78 | 1,55 | 21 / 17 | Rapides, portée courte |
| arc | Arc runique | 340 | 0,82 | 28 / 24 | Projectile |
| foudre | Bâton des orages | 300 | 0,90 | 24 / 20 | Éclair rebondissant |
| bombe | Bombarde ardente | 300 | 0,72 | 24 / 20 | Projectile explosif |
| lance | Lance transperçante | 182 | 0,78 | 37 / 30 | Estoc perforant |
| faux | Faux circulaire | 112 | 0,76 | 30 / 24 | Balayage circulaire |
| givre | Sceptre de givre | 330 | 0,80 | 21 / 18 | Projectile ralentissant |

La table donne les valeurs de `CONTENT_DATA.json`; les autres ennemis peuvent avoir leurs propres multiplicateurs et règles de collision. Pour les animations, cibles, effets de projectile et calculs complets, porter les fonctions `attackWeapon`, `launchArcVolley`, `chainLightning`, `detonateBomb` et `processWeaponEffects` de `dump/project/src/game.js`.

Progression d’arme : niveau 1 à l’obtention, niveaux 2–5 par collecte répétée, puis version spéciale. Avant la version spéciale, chaque rang donne +18 % dégâts et +8 % cadence par rapport au rang précédent, conformément au code source. La chaîne touche jusqu’au niveau d’arme. Une synergie demande arme spéciale et arme niveau 5 ainsi que relique niveau 5 (voir données et code de synergie). Arsenal : 5 armes et 5 reliques ; options de run pour inventaire sans limite, arme unique, objets verrouillés, butins personnalisés et sélection des objets pouvant tomber. Si plein, le choix proposé dépend du verrouillage ; vérifier les détails dans `inventory.js` et `game.js`.

### Ennemis, élites et boss

Huit ennemis ordinaires :

| Espèce | Comportement à retrouver |
| --- | --- |
| Goule | Poursuit et mord au contact |
| Brute | Lente, robuste, frappe fort au contact |
| Traqueur | Rapide, fragile, poursuit et griffe |
| Chargeur | Télégraphie une ruée puis fonce en ligne |
| Lanceur | Garde ses distances et annonce un projectile ciblé |
| Chaman | Annonce et tire trois projectiles en éventail |
| Sangsue | Mêlée ; récupère 12 PV en infligeant un coup |
| Sauteur | Annonce une zone puis bondit et frappe à l’atterrissage |

Trois affixes élites : Cuirassé (PV ×1,8, vitesse ×0,78, dégâts ×1,1), Fulgurant (PV ×1,2, vitesse ×1,5, dégâts ×1,1), Féroce (PV ×1,3, vitesse ×1,1, dégâts ×1,7). Élite identifiable à l’écran, rapporte 1,5× XP et progresse les objectifs et bestiaire. Une apparition élite est prévue pour un ennemi sur 24 en mode Vagues, un sur 18 en infini.

| Boss | PV | Attaque centrale |
| --- | ---: | --- |
| Gardien des cendres | 520 | Impact de rayon 138 pour 26 dégâts, puis charge de distance 250 / largeur 38 pour 22 dégâts ; télégraphie 0,82 s |
| Matriarche des ronces | 590 | Maintient ses distances et lance des salves de cinq projectiles |
| Colosse des cendres | 760 | Lent et massif ; impact de rayon 190 pour 34 dégâts |

Le mode Vagues se termine par le Gardien. Le mode infini lance un boss chaque cinquième niveau en alternant Gardien, Matriarche et Colosse ; un boss vaincu rapporte un Éclat et la run continue.

### Vagues et difficulté

Compositions exactes actuelles (381 ennemis ordinaires prévus, avant les effets de difficulté, afflux et plafond d’ennemis vivants) :

| Vague | Goule | Brute | Lanceur | Traqueur | Chargeur | Chaman | Sangsue | Sauteur | Total |
|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| 1 | 45 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 45 |
| 2 | 48 | 24 | 0 | 0 | 0 | 0 | 5 | 0 | 77 |
| 3 | 54 | 30 | 0 | 12 | 6 | 0 | 0 | 6 | 108 |
| 4 | 66 | 32 | 4 | 15 | 9 | 3 | 12 | 10 | 151 |

La capacité de base des ennemis actifs est 10. Arrivée initiale après 1 s, délai normal entre apparitions 0,62 s, intermission 3 s ; apparition à 350–540 unités du joueur. Des afflux aléatoires peuvent ajouter des groupes : chance 0,38, intervalle aléatoire 14–26 s, groupe de base 26 (+2/vague, plafond 62), espacement 0,12 s. Les valeurs et règles exactes résident dans `CONFIG` et `game.js`.

| Difficulté | PV ennemis | Dégâts | Vitesse | Cadence ennemie | Vitesse projectiles | Capacité | Butin |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| Insane (défaut) | ×2,00 | ×1,75 | ×1,30 | ×1,30 | ×1,30 | ×2,00 | ×1,00 |
| Nightmare | ×2,60 | ×2,20 | ×1,45 | ×1,50 | ×1,50 | ×2,50 | ×0,75 |
| Cataclysm | ×3,25 | ×2,70 | ×1,60 | ×1,70 | ×1,70 | ×3,00 | ×0,50 |

Après les quatre vagues, le mode infini calcule de nouvelles compositions. Les ennemis gagnent ×1,28 PV et ×1,22 dégâts à chaque niveau de progression infini ; la vitesse croît jusqu’à ×2,2. Le plafond augmente de 24 par minute jusqu’à 200. Les formules et leur progression exacte sont dans `game.js`, y compris les interactions avec la difficulté.

### XP, améliorations, butin et méta-progression

Seuil d’XP initial : 5, puis +3 par niveau. Chaque niveau suspend la simulation et propose trois améliorations sans doublon parmi neuf rangs max 10 : dégâts (+10 %), cadence (+10 %), portée (+9), taille projectile (+12,5 %), vitesse projectile (+10 %), vitesse déplacement (+8 %), PV (+8 et soin équivalent selon `CONTENT_DATA.json`), défense (+3 %), portée de collecte (+10 %). L’option d’auto-choix sélectionne la première carte après 3 s.

Butins : potion (+32 PV), arme, relique ou XP ; portée de collecte 90, rayon de contact 22, durée de vie 18 s. Chance potion 8 %, chance équipement de base 22 %, modulées par la difficulté. Les neuf reliques : Talisman de braise (+15 % dégâts), Bottes du cerf (+10 % vitesse), Pierre d’allonge (+16 portée), Sceau de cendre (−15 % dégâts reçus), Relique de mémoire (+25 % XP), Carquois spectral (+20 % cadence), Cœur de braise (+25 PV max), Aimant ancien (+35 % collecte), Sceau vampirique (soin de 3 % des dégâts infligés). Les niveaux et effets cumulatifs sont définis dans le code, et doivent être portés depuis celui-ci.

Neuf synergies relient une arme spéciale de niveau 5 à une relique de niveau 5 : sabre+talisman (explosion de braise toutes les 5 touches), marteau+pierre (impact radial et recul), dagues+bottes (dagues spectrales sur 3 cibles après un kill), arc+carquois (volée de 3 flèches), foudre+relique (rebonds plus longs), bombe+aimant (attire les objets qui explosent à l’arrivée), lance+sceau (bouclier par ennemi transpercé), faux+cœur (âmes renforçant le prochain balayage), givre+vampire (nova au gel). Les paramètres exportés et la logique d’activation sont dans `CONTENT_DATA.json` et `src/synergies.js`/`game.js`.

Objectif cyclique de vague : éliminer 12 ennemis, ramasser 8 orbes XP ou éliminer 1 élite ; récompense +18 % PV max en soin. Défis de run : 50 éliminations, 5 élites, 20 orbes XP, chacun rapporte un Éclat persistant. Une victoire en mode Vagues rapporte aussi un Éclat.

### Interface, sauvegarde et options

États : `title`, `playing`, `paused`, `levelUp`, `loot`, `victory`, `defeat`. Les sélections d’amélioration et butin suspendent le monde. HUD : PV, bouclier, XP/niveau, vague/difficulté, objectif, barre de boss ; Tab ouvre armes, reliques, synergies, bestiaire et objectifs. Le menu contient héros/arme, mode, difficulté, options de butin/inventaire, verrouillage, arme unique, son/volume, auto-choix, reprise/nouvelle partie, partage URL et remise à zéro. Un bouton de vie infinie est un outil de triche/debug persistant dans le checkpoint de run.

La sauvegarde web utilise `valombre.save.v1` dans localStorage : progression, meilleures statistiques, Éclats, découvertes bestiaire/objets/synergies, réglages audio et réglages de run. Un checkpoint complet de run est également écrit aux débuts de vague/intermission et lors des changements persistants. Cible Godot conseillée : `user://save.json` ou `ConfigFile`, avec version de schéma et migration. Préserver reprise et remise à zéro. Le bilan de run montre durée, vague, ennemis vaincus, niveau, état du boss, reliques et récompense.

## Architecture Godot proposée

Organiser le port en scènes et ressources modulaires, en gardant `Game` comme orchestrateur de run plutôt que comme grand script monolithique :

```text
res://
  scenes/       Main, World, Player, Enemy, Projectile, Pickup, HUD, menus/dialogues
  scripts/      gestion de run, combat, vagues, sauvegarde, entrées, effets
  data/         Resources héros, armes, ennemis, boss, reliques, améliorations, synergies
  assets/       SVG issus de dump/assets, conservés comme sources
  shaders/      vignette, flash, givre et traitements nécessaires
```

| Module web de référence | Responsabilité | Cible Godot indicative |
| --- | --- | --- |
| `src/config.js` | Données et réglages | Resources `.tres` ou Resources personnalisées dans `data/` |
| `src/game.js` | États, simulation, combat, vagues, sauvegarde | orchestrateur de run et systèmes dédiés |
| `src/renderer.js` | Monde Canvas, caméra, FX et sprites | `Node2D`, `Camera2D`, sprites, `GPUParticles2D`, shaders |
| `src/input.js` | clavier/souris/tactile | `InputMap`, contrôleurs et commandes tactiles |
| `src/ui.js`, `src/hud.js` | dialogues, cartes, HUD, inventaire/catalogue | scènes `Control` sous `CanvasLayer` |
| `src/inventory.js` | rangs et statistiques calculées | modèle de run/inventaires/Resources |
| `src/synergies.js` | règles de combo | ressources de synergie et système d’effets |
| `src/bestiary.js` | bestiaire et affixes | données d’ennemis et d’affixes |

Le JSON est un index pratique, pas un substitut aux formules et ordres d’application JavaScript. Le comportement de déplacement, cibles, collisions, télégraphes, ordre des effets, loot et sauvegarde doit être lu dans les fonctions source listées par `dump/GODOT_PORT_SPEC.md`.

## Démarrer dans Godot

Ouvrir ce dossier dans Godot 4.7 (projet configuré avec renderer Compatibility/GL). La fenêtre initiale et le point d’entrée seront créés pendant la première étape de [`ROADMAP.md`](ROADMAP.md). À ce jour, le projet n’a pas encore de scène principale.

## Critères de fidélité

Une étape de port est considérée fidèle quand elle couvre les règles correspondantes du dump, et que ses cas de référence peuvent être rejoués : mouvement normalisé et collisions/glissement ; cadence et portée par arme ; mêmes dégâts et séquences ; variations de difficulté et élites ; vagues/afflux/boss ; choix d’amélioration et remplacement d’équipement ; synergies ; pause et transitions ; reprise après fermeture ; contrôles clavier, souris et tactile. Le hasard du navigateur n’est pas seedé : pour comparer des scénarios, le port doit exposer une seed de test ou pouvoir enregistrer/rejouer les tirages. Cela sert à comparer les résultats sans changer la run normale.

## Sources

- Code et données de référence : [`dump/project/`](dump/project/)
- Spécification détaillée incluse dans l’archive : [`dump/GODOT_PORT_SPEC.md`](dump/GODOT_PORT_SPEC.md)
- Manifeste des assets : [`dump/ASSET_MANIFEST.csv`](dump/ASSET_MANIFEST.csv)
- Plan d’exécution : [`ROADMAP.md`](ROADMAP.md)
