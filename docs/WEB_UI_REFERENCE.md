# Référence HTML/CSS de l’interface web

Cette fiche relève les dimensions, libellés et règles responsive de `dump/project/index.html` et `dump/project/styles.css`. Les règles finales ajoutées après la ligne 138 du CSS sont prioritaires sur plusieurs règles mobiles précédentes : les valeurs ci-dessous décrivent donc la cascade effective.

## Cadre et HUD

| Élément | Référence effective |
| --- | --- |
| Canvas | Attribut source `960 × 540`; affichage `width:100%`, `height:auto`, ratio `16/9`; renderer Canvas pixelisé. |
| Page | `height:100dvh`, flex colonne, débordement masqué; largeur 100%, marge centrée. Le cadre de jeu est centré sur ordinateur et ne grandit pas au-delà de la hauteur disponible. |
| Cadre desktop (≥761 px) | `width:min(100%, max(0px, calc(177.78dvh - 284px)))`; ratio du canvas fixé à 16:9. |
| En-tête / pied de page | En-tête flex, marge basse 14 px et écart 20 px; côtés paddés `clamp(10px, 2vw, 28px)`. Pied flex, écart 16 px, padding haut 10 px. |
| HUD supérieur | Absolu en haut, `inset:14px 16px auto`, flex entre carte héros et informations de run. |
| Carte héros | 290 × largeur fixe, padding 9 × 12 px, écart 11 px; portrait 39 × 39 px. Barres de vie/XP/bouclier : largeur 130 px, hauteur 5 px chacune, écart 4 px. |
| Infos de vague | Bloc à droite, padding 9 × 12 px, aligné à droite; badge de difficulté séparé par une bordure. |
| Inventaire | Largeur `min(300px, calc(100vw - 24px))`; hauteur max `min(65vh, 520px)`, défilement vertical; padding 6 × 10 px. |
| HUD inférieur | Absolu, marges latérales 15 px et basse 14 px; contient esquive, capacité et rappel clavier. |
| Barre de boss | Centrée à 82 px du haut, largeur `min(380px, 65%)`; jauge de 9 px de haut. |
| Notification | Centrée horizontalement à 27 % du haut, texte 12 px, fondu 250 ms. |

## Menu et choix

| Élément | Référence effective |
| --- | --- |
| Voile | Inset 0, grille centrée, défilement vertical; fond `#0b0c09b8`, flou d’arrière-plan 2 px. |
| Dialogue ordinaire | Largeur `min(390px, calc(100% - 32px))`; padding 28 px 30 px 24 px; bordure 1 px; titre Georgia 26 px, texte système 12 px / 1,7. |
| Options de départ | Grille à 2 colonnes, écart 10 px, largeur max 360 px; sélecteurs texte Georgia 12 px. |
| Carte d’amélioration/loot | Flex, largeur 100 %, padding 9 px 11 px, écart icône/texte 8 px; icône 28 × 28 px; titre Georgia 13 px, détail système 10 px / 1,4. |
| Aperçu d’objet | Icône 42 × 42 px; conteneur colonne, écart 4 px, largeur max 360 px. |
| Dialogue pause | Largeur max 820 px, hauteur max `calc(100% - 24px)`, défilement vertical; catalogue en 2 colonnes avec 16 px d’écart. |
| Carte catalogue | Grille 2 colonnes, écart 5 px; carte flex, padding 5 px 6 px; icône 30 × 30 px; texte 10 px, description 9 px. |

## Typographie, couleurs et textes

La police générale est Georgia / Times New Roman, 14 px, interligne 1,45. Les panneaux HUD et la plupart des contrôles utilisent `system-ui`; les titres de marque et dialogues utilisent Georgia.

| Rôle | Couleur source |
| --- | --- |
| Encre principale / atténuée | `--ink: #eee6d5`; `--muted: #a39d8b` |
| Or et filet | `--gold: #d6ad68`; `--line: #51483a`; panneau `--panel: #1b1b17` |
| Fond de page | Dégradé `#292921` → `#141510` → `#0d0e0b` |
| Panneaux HUD | `#10110edb`; panneau de choix `#22221c` → `#141510` |
| Santé / XP / bouclier | Santé `#772d27` → `#c44c3b`; XP `#74468f` → `#d9a2ff`; bouclier `#176a9b` → `#59c9ff` |
| Focus | Contour `#e0c486`, épaisseur 2 px, décalage 3 px |

Le HTML fournit les libellés statiques suivants : marque « LES CENDRES DE VALOMBRE », sous-titre « Chroniques d’un royaume oublié », chapitre « Chapitre I · Les bois maudits »; HUD « PV », « XP », « NIV. », « ARMES & RELIQUES », « Esquive », « Charge de cendre »; commandes « Attaquer », « Esquiver », « Mettre en pause », « se déplacer », « ESPACE attaquer »; options « Héros », « Arme de départ », « Mode », « Difficulté », « Arme unique », « Arsenal illimité », « Drops personnalisés », « Muet », « Volume » et « Choisir automatiquement la première amélioration après 3 s »; boutons « Copier le lien de cette configuration », « Effacer la progression et les options sauvegardées », « Entrer dans la forêt », « Nouvelle run · choisir les options », « Nouvelle partie » et « Retour au menu ». Les libellés des neuf choix d’arme et des héros sont dans les `<option>` de `index.html`.

Les écrans d’état sont définis dans `game.js` : titre « La nuit se lève » / « Les morts se sont éveillés. Traversez la clairière et survivez aux vagues. »; pause « La chasse attend » / « Prenez votre souffle avant de retourner dans la clairière. »; niveau « Une nouvelle force » / « Choisissez une amélioration pour poursuivre votre chasse. »; loot « Sacoche pleine » / « Choisissez une relique à remplacer ou gardez votre équipement actuel. »; victoire « Valombre est libérée »; défaite « La forêt vous reprend ». Les valeurs HUD, options dynamiques, noms et descriptions de contenu viennent de `hud.js`, `ui.js` et des données de contenu.

## Responsive

- À `max-width:760px` ou avec pointeur tactile : commandes tactiles affichées, HUD inférieur caché. Joystick 88 × 88 px avec stick 30 × 30 px; boutons ronds 48 × 48 px, écart 8 px.
- À `max-width:640px` : note de chapitre masquée; marque 15 px; portrait 27 × 27 px; carte héros 200 px; barres 82 px; classe et nom d’arme cachés; panneau inventaire plafonné à 125 px; boss HUD à 52 px du haut et largeur max 260 px. Le dialogue passe à 22 px de titre, 11 px de texte et padding 12 px 16 px.
- À `max-width:380px` : joystick 72 × 72 px, stick 24 × 24 px; boutons 38 × 38 px et écart 4 px.
- Le CSS contient une ancienne règle mobile donnant au canvas une hauteur `clamp(360px,70svh,560px)`, mais la règle finale la remplace par `height:auto; aspect-ratio:16/9`. La page entière ne défile pas; les panneaux overlay et inventaire ont leur propre défilement.

Le relevé ne prétend pas valider visuellement la parité Godot : la comparaison de captures reste une tâche distincte de la Phase 7.
