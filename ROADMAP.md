# Feuille de route — portage Godot fidèle

Ce plan utilise comme référence le dump extrait dans [`dump/`](dump/) et le guide du dépôt [`README.md`](README.md). L’objectif est une version Godot jouable dont le contenu et les règles reproduisent le snapshot web, puis dont la présentation et les contrôles atteignent la même expérience. Les tâches marquées « parité » doivent suivre le code JavaScript exporté, y compris les comportements qui ne sont pas décrits dans le JSON.

**Avancement global : 48/70 tâches terminées (68,6 %).**

## Principes de portage

1. **Traiter le code exporté comme la référence des comportements.** Comparer les données JSON au code quand une valeur, un ordre ou une formule est ambiguë. Le README navigateur est ancien et certaines de ses valeurs sont dépassées.
2. **Porter avant d’équilibrer.** Ne pas retoucher les nombres pour rendre la run plus facile ou plus courte ; tout changement d’équilibrage doit être explicite et distinct du travail de fidélité.
3. **Centraliser les données.** Héros, armes, ennemis, boss, affixes, améliorations, reliques, synergies, vagues et difficultés doivent vivre dans des Resources/données Godot, sans copies de nombres éparpillées dans les scènes.
4. **Séparer les responsabilités.** Simulation déterministe par `delta`, présentation, interface, stockage et configuration sont des systèmes distincts. Les transitions d’état ne doivent pas dépendre de la visibilité visuelle d’un overlay.
5. **Garder les SVG d’origine.** Importer les 44 assets du dump ; vérifier leurs dimensions et le rendu sur la cible choisie avant de les convertir ou remplacer.
6. **Rendre les scénarios comparables.** Injecter un générateur pseudo-aléatoire seedable ; en jeu normal le seed reste généré, en vérification le seed et les tirages se rejouent.

## État initial

- [x] Extraire `valombre_godot_dump.zip` dans `dump/`.
- [x] Inventorier le contenu et créer le README du projet.
- [x] Établir ce plan de portage.
- [x] Créer un point d’entrée Godot, une scène principale et les scripts de jeu de base.

## Phase 0 — Référence et inventaire des comportements

**But :** transformer le dump en spécification exploitable, sans modifier les règles.

- [ ] Lire intégralement `config.js`, `inventory.js`, `synergies.js`, `bestiary.js`, `input.js`, `ui.js`, `hud.js`, `renderer.js`, `game.js`, `index.html` et `styles.css`.
- [ ] Construire une matrice de parité pour chaque fonction métier : formule d’entrée, mise à jour, sorties, effets secondaires et sauvegarde.
- [ ] Relever précisément les règles insuffisamment résumées : dégâts par espèce, rayons de collision, séquences d’attaque, cadence, projectiles, expérience donnée par ennemi, générateur d’afflux, choix/remplacement d’équipement, niveaux cumulés de relique, synergies et ordre des multiplicateurs.
- [ ] Comparer `CONTENT_DATA.json` au code source et consigner les divergences connues (incluant le tableau de vagues historique du README source).
- [x] Documenter tous les champs du checkpoint et du profil, la validation du schéma et les transitions où ils sont écrits ([`docs/SAVE_SCHEMA.md`](docs/SAVE_SCHEMA.md)).
- [ ] Relever les dimensions exactes des éléments d’interface, les libellés, les couleurs et les règles responsive depuis HTML/CSS.
- [ ] Vérifier les empreintes SVG via le manifeste et associer chacun aux entités/éléments d’interface.

**Livrable :** une fiche de référence complète et versionnée, sans données en double. Les ambiguïtés restantes sont déclarées au lieu d’être remplacées par des suppositions.

## Phase 1 — Squelette de projet et données

**But :** établir une structure Godot propre, charger le jeu et toutes ses données.

- [x] Créer `scenes/Main.tscn` et l’assigner comme scène principale dans `project.godot`.
- [x] Créer les dossiers `scenes/`, `scripts/`, `data/`, `assets/`, `shaders/` et `audio/` si nécessaire.
- [x] Copier les SVG du dump sous `assets/` sans altérer les originaux ; conserver le manifeste et décider du mode d’import SVG adapté à Godot 4.7.
- [x] Créer des Resources typées pour héros, armes, espèces ennemies, boss, affixes, améliorations, reliques, synergies, difficultés et vagues.
- [x] Importer toutes les valeurs de référence. Ajouter une validation de données au démarrage afin de relever les identifiants ou relations manquants.
- [x] Créer la scène racine et les couches monde/interface, une scène d’arène, puis une caméra bornée au rectangle 1500×1100.
- [x] Régler la fenêtre de jeu et le comportement de redimensionnement pour préserver le cadre 16:9 de référence.

**Critères d’acceptation :** le projet s’ouvre et démarre dans Godot sans erreur de ressource ; la fenêtre présente une arène cadrée ; les 44 SVG sont disponibles par chemin Godot et leur provenance est conservée.

## Phase 2 — Arène, joueur et entrées

**But :** obtenir un déplacement immédiatement jouable et spatialement identique.

- [x] Construire la clairière : fond, limites, ruines, arbres/débris décoratifs, teinte générale et vignette.
- [x] Reproduire monde 1500×1100, caméra 960×540 de référence, suivi du joueur et bornes caméra.
- [x] Ajouter les quatre obstacles aux coordonnées/rayons du dump. Les obstacles bloquent aussi les projectiles.
- [x] Porter le mouvement `CharacterBody2D` ou équivalent en conservant la vitesse exacte et la normalisation diagonale.
- [x] Reproduire le glissement le long des obstacles et des limites avec le mouvement physique de Godot.
- [ ] Ajouter les deux héros, leurs animations/poses, états de dégâts et orientation ; porter les statistiques et la compétence de la Sentinelle.
- [x] Déclarer actions InputMap pour directions, attaque, capacité, esquive, pause, inventaire ; gérer relâchement au changement de focus.
- [x] Créer les commandes tactiles adaptées à écran étroit et écran tactile : joystick et boutons d’action, dimensionnés et placés comme dans le CSS de référence.

**Critères d’acceptation :** Pèlerin à 190 unités/s, Sentinelle à 165 ; direction diagonale normalisée ; collision avec les quatre blocs et glissement ; changement de focus ne laisse pas une touche bloquée ; chaque commande fonctionne au clavier et au tactile ciblé.

## Phase 3 — Combat de base et ennemis

**But :** porter le cœur de la simulation, avant toute progression persistante.

- [ ] Implémenter les états de run (`title`, `playing`, `paused`, `levelUp`, `loot`, `victory`, `defeat`) et leurs règles de gel/reprise.
- [x] Ajouter modèles runtime de joueur, ennemi, projectile, dégâts, statut, cible, minuterie et effets temporaires.
- [ ] Porter attaque manuelle et automatique, recherche de cible, portée, orientation, cadence, anim/flash et invulnérabilité.
- [ ] Porter les neuf armes : sabre, marteau, dagues, arc, foudre, bombe, lance, faux et givre. Inclure percement, rebonds, explosion, ralentissement et choix de cibles exacts.
- [x] Ajouter les huit espèces avec leurs comportements, temps de télégraphie, déplacements, projectiles, dégâts et collision.
- [x] Ajouter les trois affixes élites, leurs multiplicateurs, couleurs/signalement et conséquences de récompense.
- [x] Porter la charge de cendre de la Sentinelle, l’esquive (570, 0,18 s, 0,24 s d’invulnérabilité, 2,6 s de recharge) et leurs collisions.
- [x] Respecter l’ordre exact des événements : impacts multiples, mort, XP, synergie, vol de vie, butin, défis et progression bestiaire ([`docs/COMBAT_PARITY.md`](docs/COMBAT_PARITY.md)).

**Critères d’acceptation :** les mêmes entrées et cibles causent les mêmes impacts attendus pour chaque arme ; projectiles et zones respectent obstacles et limites ; télégraphes précèdent leurs attaques ; élites appliquent PV/vitesse/dégâts et attribution d’XP corrects.

## Phase 4 — Vagues, boss et boucle de run

**But :** reproduire la progression chronologique entière.

- [x] Porter les quatre compositions exactes (45 ; 48+24+5 ; 54+30+12+6+6 ; 66+32+4+15+9+3+12+10) et le boss final des vagues.
- [x] Porter apparitions initiales (1 s), intervalle (0,62 s), intermission (3 s), distance de spawn (350–540) et plafond actif (base 10, modulé par difficulté).
- [x] Reproduire les groupes d’afflux : chance 0,38, intervalle 14–26 s, groupe de base 26, +2 par vague jusqu’à 62, espacement 0,12 s et tirage des types pondéré.
- [x] Ajouter Gardien, Matriarche et Colosse avec motifs, télégraphes, projectiles, barres de vie et règles de fin associées.
- [x] Ajouter mode infini : compositions dynamiques, scaling PV/dégâts/vitesse, plafond croissant, boss à chaque cinquième niveau et Éclat par boss.
- [x] Appliquer les trois presets de difficulté aux mêmes paramètres que la source : santé, dégâts, vitesse, cadence, vitesse projectile, capacité et butin.
- [x] Porter progression d’objectif cyclique et récompense de soin ; défis d’élimination/élites/XP et Éclats persistants.
- [x] Produire les résultats victoire/défaite : durée, vague, éliminations, niveau, état boss, reliques et récompense.

**Critères d’acceptation :** chaque vague génère la composition exportée ; la campagne se termine après le Gardien ; l’infini poursuit après les boss ; tous les multiplicateurs de difficulté affectent les systèmes visés.

## Phase 5 — XP, choix, inventaires et synergies

**But :** porter la construction du personnage pendant la run.

- [x] Porter XP, seuil initial 5, incrément de 3, pause sur montée de niveau et choix de trois améliorations sans doublons.
- [x] Implémenter les neuf améliorations (valeurs, maximum 10, textes, rangs, soins et stacking tels que codés).
- [x] Porter la sélection automatique de première carte après 3 s si l’option est activée.
- [x] Porter butins et collecte : catégories, probabilités modulées, rayons, durée, aimantation, potion +32, filtres de butin et collecte automatique configurables.
- [x] Créer les sacs armes/reliques à 5 emplacements, progression niveau 1–5 et arme spéciale, verrouillage, arme unique, inventaire illimité, remplacer ou passer.
- [x] Porter les neuf reliques et les calculs composés de leurs rangs. Afficher les valeurs effectives au bon format.
- [x] Implémenter les neuf synergies et leur seuil : arme spéciale niveau 5 + relique niveau 5.
- [x] Reproduire les effets des combos et leur ordre exact avec les armes, kills, butins, boucliers et statuts.

**Critères d’acceptation :** seuils d’XP, cartes et rangs concordent ; plafond/verrouillage/remplacement de sacs concordent ; chaque synergie s’active uniquement avec ses prérequis et produit son effet spécifique.

## Phase 6 — Interface complète et sauvegarde

**But :** porter les écrans et la continuité entre sessions.

- [x] Recréer écran titre, options de départ, sélecteurs, catégories de butin et options run.
- [x] Créer HUD : PV, bouclier, XP/niveau, vague, difficulté, objectif, capacité, barre de boss et notifications.
- [x] Porter panneau Tab avec équipement, reliques, synergies, bestiaire/découvertes et défis.
- [ ] Recréer overlays pause, montée de niveau, butin, victoire et défaite ; navigation clavier/manette tactile et focus accessible.
- [x] Ajouter réglage de volume/muet, reprise, nouvelle run, remise à zéro, partage de configuration URL si pertinent à l’export Godot.
- [x] Porter profil et checkpoint complet en `user://save.json` (ou ConfigFile), ajouter `schema_version`, validation et migration.
- [x] Sauvegarder aux transitions équivalentes à la source : démarrage/intermission de vague et mutations persistantes importantes.
- [x] Préserver une partie interrompue, sa reprise, l’option de vie infinie et la remise à zéro du profil.

**Critères d’acceptation :** chaque état peut être rejoint et quitté sans avancer la simulation lorsqu’elle doit être suspendue ; après fermeture/réouverture, profil et checkpoint sont restaurés ; ancienne sauvegarde invalide/corrompue ne bloque pas le démarrage.

## Phase 7 — Direction artistique, effets et audio

**But :** retrouver la lisibilité et l’ambiance du navigateur.

- [ ] Importer et assigner les SVG héros, ennemis/boss, icônes d’objets et armes tenues.
- [x] Reproduire le fond forêt/ruines, décor secondaire, éclairage et vignette, sans réduire la lisibilité des attaques.
- [ ] Porter nombres de dégâts, orbes XP, drops, projectiles, arcs électriques, impacts, flashes, zones télégraphiées, givre, explosions, particules et secousses si présentes dans la source.
- [ ] Reprendre palette, cadres, typographie et proportions UI du CSS ; adapter le layout sans couper le HUD en 16:9, fenêtre redimensionnée et écran étroit.
- [ ] Créer les sons synthétiques absents de l’archive avec génération audio Godot ou formes d’onde équivalentes ; déclencher sur événements identiques et respecter volume/muet.
- [ ] Comparer des captures avec le canvas web 960×540 pour composition, contraste, taille des sprites et superposition des UI.

**Critères d’acceptation :** toutes les familles de feedback visuel présentes dans le jeu web ont un équivalent lisible ; les icônes et silhouettes viennent des assets fournis ; HUD et contrôles tactiles restent utilisables sur les dimensions cibles.

## Phase 8 — Parité, robustesse et livraison

**But :** fermer les écarts documentés avant de déclarer le port terminé.

- [ ] Jouer des scénarios contrôlés avec seed : déplacement/collision, chaque arme, chaque ennemi, élite, montée de niveau, chaque type de butin, remplacement, synergie, boss et reprise de sauvegarde.
- [ ] Comparer les valeurs numériques et les événements avec le code de référence : positions, temps, PV/dégâts, compteurs, drops et résultats.
- [ ] Vérifier les transitions d’état à haute cadence et basse cadence, pause/reprise, fenêtre inactive et commandes maintenues.
- [ ] Vérifier sur les plateformes choisies l’import SVG, l’écriture de sauvegarde, la résolution de fenêtre et le rendu Compatibility.
- [ ] Corriger les écarts avant d’optimiser ; profiler les groupes d’afflux, projectiles, particules et nombres de dégâts au plafond de 200 ennemis.
- [ ] Mettre à jour README et roadmap avec la version réellement livrée, les contrôles, l’emplacement de sauvegarde et les écarts résiduels admis.

**Définition de terminé :** boucle entière Vagues et mode infini jouables ; toutes les armes, reliques, améliorations, ennemis, affixes, boss et synergies exportés sont présents ; menu/HUD/catalogue, options et sauvegarde fonctionnent ; aucun écart de règle connu n’est laissé sans description.

## Risques et points à surveiller

- **README source obsolète :** son tableau affirme 693 ennemis et exclut certaines espèces/valeurs plus récentes. Le code `dump/project/src/config.js` et les vagues effectives de `game.js` font foi pour le snapshot.
- **Données descriptives seules :** le JSON ne contient pas les fonctions des améliorations ni toutes les formules. Ne pas déduire le stacking du texte utilisateur ; reprendre le code source.
- **Ordre des effets :** les synergies, attaques multi-cibles, XP, vol de vie et morts peuvent dépendre de l’ordre exact d’exécution.
- **Hasard :** le navigateur utilise `Math.random()` sans seed global ; comparer des runs ordinaires ne garantit pas des séquences identiques. Ajouter une source aléatoire injectable en Godot.
- **Import SVG et renderer :** vérifier le support effectif des SVG dans le pipeline Godot et conserver un rendu source fidèle, particulièrement pour les assets avec tailles/viewBox atypiques.
- **Audio absent :** les fichiers audio ne sont pas dans le dump ; les sons doivent être reconstitués à partir des événements et de `sound()`.
- **Portée du dump :** le jeu web est la référence à cette date, pas un contrat sur des fonctions absentes de l’archive ni une licence d’utilisation indépendante.
