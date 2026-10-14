# Les Cendres de Valombre

Un petit jeu d’action-RPG en vue du dessus, inspiré des jeux de hack and slash : choisissez un héros, une arme et un mode, puis survivez aux hordes avec des attaques automatiques, des reliques et des améliorations.

Le jeu fonctionne dans un navigateur récent, sans installation, compilation, bibliothèque externe, serveur de jeu ni compte. La cible de conception est une run solo de 10 à 20 minutes. Les premières simulations de jeu étaient beaucoup plus courtes ; les vagues ont été étoffées et l’équilibrage reste à valider avec des runs jouées normalement.

## Lancer le jeu

Ouvrez `index.html` dans un navigateur. Pour utiliser la sauvegarde locale de façon plus fiable, lancez le serveur statique fourni par Python depuis la racine du projet :

```sh
python3 -m http.server 8000
```

Puis ouvrez <http://localhost:8000>.

## Commandes

| Action | Clavier | Tactile |
| --- | --- | --- |
| Se déplacer | `W`, `A`, `S`, `D` ou flèches | Joystick à gauche |
| Attaque de base | Automatique sur la cible proche ; `Espace`, `J` ou clic pour déclencher une attaque | Bouton épée à droite |
| Capacité du héros | `E` | Bouton `E` |
| Esquive | `Maj` | Bouton flèche |
| Pause et reprise | `Échap`, puis reprendre | Bouton pause, puis reprendre |

Les armes attaquent automatiquement les ennemis à portée. Le clic dans l’arène ou la touche espace déclenche aussi une attaque immédiate. Sur téléphone ou tablette, utilisez le joystick et les trois boutons d’action. Les commandes tactiles apparaissent automatiquement sur les petits écrans et appareils avec écran tactile.

## Déroulement

- **Héros :** le Pèlerin a 100 PV, se déplace rapidement et frappe autour de lui. La Sentinelle a 125 PV, avance plus lentement et charge en ligne droite.
- **Armes :** le sabre est équilibré, le marteau frappe fort et largement, les dagues attaquent vite avec une portée courte et l’arc runique tire des projectiles à longue portée.
- **Combat :** les armes attaquent automatiquement les ennemis proches. Les goules, brutes, traqueurs et chargeurs poursuivent le joueur ; le traqueur est rapide et fragile, le chargeur annonce une ruée. Le lanceur annonce un projectile et le chaman une salve de trois tirs. Chaque arme et projectile utilise des effets visuels distincts. L’esquive accorde une courte période d’invulnérabilité.
- **Progression :** l’expérience fait monter de niveau. À chaque niveau, choisissez une amélioration parmi trois cartes : dégâts, cadence, portée, mobilité, santé, projectile de braise automatique ou onde de givre périodique. Les créatures peuvent laisser une potion ou une relique ; jusqu’à cinq reliques peuvent être équipées ; elles améliorent les dégâts, la cadence, la portée, la défense, les PV, l’expérience ou la collecte.
- **Run :** le mode Vagues propose quatre étapes et un boss final. Le mode Survie infinie génère des vagues sans fin, augmente progressivement la santé, la vitesse et les dégâts des ennemis, mélange six familles de créatures et fait apparaître un boss tous les cinq niveaux. La victoire et la défaite affichent la durée, la vague atteinte, les créatures vaincues, le niveau et les reliques.
- **Sauvegarde :** héros et arme choisis, volume, mode muet, victoires et meilleur nombre de créatures survivent au rechargement dans le stockage local du navigateur. La partie en cours n’est pas sauvegardée.
- **Audio :** quelques sons synthétiques accompagnent attaques, coups, montée de niveau et butin. Le navigateur ne crée le moteur audio qu’après une action du joueur. Volume et mode muet sont réglables dans le menu.

### Vagues

| Vague | Composition |
| --- | --- |
| 1 | 90 goules |
| 2 | 96 goules, 48 brutes |
| 3 | 108 goules, 60 brutes, 22 traqueurs, 12 chargeurs |
| 4 | 132 goules, 64 brutes, 8 lanceurs, 30 traqueurs, 18 chargeurs, 5 chamans |
| Fin | Gardien des cendres, 520 PV |

Les vagues représentent 693 ennemis ordinaires au total, avec au maximum 10 créatures actives.

La zone est une clairière délimitée par un mur de pierre. Quatre blocs de ruines bloquent les déplacements et les projectiles. Les arbres et débris sont décoratifs.

## Réglages principaux

Les réglages de jeu sont regroupés dans `CONFIG` dans `src/config.js`. Les valeurs ci-dessous sont le point de départ actuel, pas un équilibre final validé sur plusieurs runs.

| Élément | Valeur de départ |
| --- | --- |
| Pèlerin | 100 PV, 190 unités/s |
| Sentinelle | 125 PV, 165 unités/s ; charge de 190 unités, 58 dégâts |
| Goule | 34 PV, 74 unités/s, 9 dégâts au contact |
| Brute | 65 PV, 49 unités/s, 15 dégâts au contact |
| Traqueur | 25 PV, 112 unités/s, 7 dégâts au contact |
| Chargeur | 58 PV, ruée télégraphiée, 13 dégâts |
| Lanceur | 42 PV, projectile annoncé, 8 dégâts |
| Chaman | 55 PV, salve annoncée de trois projectiles, 10 dégâts par projectile |
| Gardien | 520 PV ; frappe au sol de 26 dégâts ou charge de 22 dégâts |
| Sabre | portée 108 ; 32 dégâts aux goules, 25 aux brutes |
| Marteau | portée 128 ; 48/36 dégâts, attaque lente et large |
| Dagues | portée 78 ; 21/17 dégâts, attaque rapide et précise |
| Arc runique | portée 340 ; projectile automatique à 520 unités/s |
| Braise orbitale | attaque déblocable, projectile automatique amélioré par niveau |
| Onde de givre | attaque déblocable, explosion périodique améliorée par niveau |
| Esquive | 570 unités/s pendant 0,18 s ; recharge 2,6 s |
| Sacoche | 5 reliques maximum ; 8 effets disponibles |
| Apparitions | 0,85 s entre les ennemis, 10 ennemis ordinaires maximum ; traqueurs rapides dans le mode infini |

## Fichiers

```text
.
├── index.html                 # Structure HTML et interface
├── styles.css                 # Présentation, HUD et styles tactiles
├── src/config.js              # Réglages, armes, héros et contenu
├── src/game.js                # État de run, orchestration et simulation
├── src/hud.js                 # Mise à jour du HUD et de l’inventaire affiché
├── src/input.js               # Clavier, pointeur et commandes tactiles
├── src/inventory.js           # Progression et statistiques des armes/reliques
├── src/renderer.js            # Dessin Canvas du monde et des effets
├── src/ui.js                  # Éléments HTML et cartes de choix
├── assets/                    # Illustrations vectorielles locales en SVG
├── .github/workflows/pages.yml # Publication automatique avec GitHub Pages
├── README.md                  # Guide de lancement et de jeu
└── tasks/
    ├── plan.md                # Roadmap détaillée
    └── todo.md                # Suivi des tâches
```

Les sprites sont des SVG dessinés pour ce projet et chargés depuis `assets/`. Le rendu Canvas garde les silhouettes procédurales comme solution de repli si un fichier est indisponible. Aucune ressource de jeu n’est chargée depuis un service distant.

## Publier sur GitHub Pages

Le dépôt contient un workflow prêt à publier le site statique à chaque mise à jour de la branche `main` et depuis l’onglet Actions. Pour l’activer :

1. Importez ce dossier dans un dépôt GitHub et poussez la branche `main`.
2. Dans **Settings → Pages**, choisissez **GitHub Actions** comme source de publication.
3. Attendez la fin du workflow **Publier le jeu sur GitHub Pages**. GitHub affiche ensuite l’URL dans les paramètres Pages et dans l’environnement du déploiement.
4. Après une mise à jour, le workflow republie le dossier racine. Pour revenir en arrière, restaurez une révision précédente de `main` et poussez-la.

Aucune URL publique n’est associée à ce dossier tant qu’il n’a pas été poussé dans un dépôt GitHub et que Pages n’a pas été activé. GitHub décrit le réglage de source et le workflow dans sa [documentation de publication Pages](https://docs.github.com/en/pages/getting-started-with-github-pages/configuring-a-publishing-source-for-your-github-pages-site).

## Limites connues

- L’équilibrage du mode infini et la difficulté aux vagues élevées restent à ajuster avec des runs jouées.
- La sauvegarde dépend du stockage local du navigateur et ne synchronise rien entre appareils.
- Aucun système de partie sauvegardée, multijoueur, campagne, serveur ou progression permanente étendue n’est inclus.
- L’URL publiée doit encore être créée depuis un dépôt GitHub.

## Roadmap et licence

La feuille de route détaillée est dans [`tasks/plan.md`](tasks/plan.md) et son suivi dans [`tasks/todo.md`](tasks/todo.md). Les illustrations vectorielles sont créées pour le projet. Aucune licence logicielle n’a encore été choisie ; ajoutez-en une avant de redistribuer le code.
# better_than_tim
