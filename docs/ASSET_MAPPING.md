# Correspondance des SVG du dump

Les 44 SVG du projet ont été comparés au manifeste [`dump/ASSET_MANIFEST.csv`](../dump/ASSET_MANIFEST.csv) : taille et SHA-256 concordent pour chaque copie dans `dump/assets/` et `assets/`.

| Fichiers du manifeste | Entités ou éléments représentés | Utilisation dans Godot |
| --- | --- | --- |
| `hero.svg`, `sentinel.svg` | Pèlerin, Sentinelle | Sprite du joueur ; `Main.gd` sélectionne le portrait du héros |
| `ghoul.svg`, `brute.svg`, `stalker.svg`, `charger.svg`, `caster.svg`, `shaman.svg`, `leech.svg`, `leaper.svg`, `mark.svg` | Neuf espèces ennemies | Champ `sprite` des données ennemies, chargé par `Enemy.gd` |
| `boss.svg`, `matriarch.svg`, `colossus.svg` | Gardien, Matriarche, Colosse | Champ `sprite` des boss ; le Gardien utilise `boss.svg` |
| `held-weapons/{sabre,marteau,dagues,arc,foudre,bombe,lance,faux,givre}.svg` | Arme tenue de chacune des neuf armes | Sprite animé de l’arme équipée et sprites secondaires dans `RunController.gd` |
| `weapons/{sabre,marteau,dagues,arc,foudre,bombe,lance,faux,givre}.svg` | Icônes des neuf armes | Cartes de choix, inventaire, synergies et catalogue |
| `weapons/category.svg` | Catégorie « armes » | Icône de catégorie du butin et du catalogue |
| `relics/{talisman,stone,quiver,seal,heart,magnet,vampire,boots,relic}.svg` | Icônes des neuf reliques | Cartes, inventaire, synergies et catalogue |
| `relics/category.svg` | Catégorie « reliques » | Icône de catégorie du butin et du catalogue |
| `xp.svg` | Orbe d’expérience | Collectible XP et charge visuelle de l’arme concernée |
| `mark.svg` | Marque ennemie ; également emblème du site source | Sprite de l’espèce « mark » ; favicon du site web source |

Les 44 fichiers sont ainsi répartis entre héros (2), ennemis et boss (12), armes tenues (9), icônes d’armes et de catégorie (10), icônes de reliques et de catégorie (10), et XP (1). `mark.svg` est compté parmi les ennemis ; aucune copie supplémentaire n’est requise pour le favicon source.

Les assets sont chargés depuis `res://assets/` sans conversion ni modification des SVG. Les empreintes détaillées restent dans le manifeste afin d’éviter une seconde liste de hashes maintenue à la main.
