export const ENEMY_BESTIARY = {
  ghoul: { name: "Goule", description: "Horde lente qui attaque au contact.", attack: "Morsure au contact", sprite: "ghoul" },
  brute: { name: "Brute", description: "Créature lente, résistante et dangereuse au corps à corps.", attack: "Coup puissant au contact", sprite: "brute" },
  stalker: { name: "Traqueur", description: "Prédateur rapide et fragile qui poursuit sans relâche.", attack: "Griffe au contact", sprite: "stalker" },
  charger: { name: "Chargeur", description: "Annonce sa trajectoire avant de foncer.", attack: "Ruée en ligne", sprite: "charger" },
  caster: { name: "Lanceur", description: "Garde ses distances et vise le joueur.", attack: "Projectile unique", sprite: "caster" },
  shaman: { name: "Chaman", description: "Tire une salve de projectiles en éventail.", attack: "Salve de trois projectiles", sprite: "shaman" },
  leech: { name: "Sangsue", description: "Se soigne lorsqu’elle inflige des dégâts.", attack: "Morsure drainante", sprite: "leech" },
  leaper: { name: "Sauteur", description: "Annonce sa zone d’atterrissage avant de bondir.", attack: "Bond de zone", sprite: "leaper" },
  "boss:guardian": { name: "Gardien des cendres", description: "Alterne frappe de zone et charge annoncée.", attack: "Impact au sol et charge", sprite: "boss" },
  "boss:matriarch": { name: "Matriarche des ronces", description: "Maintient la distance et tire une salve en éventail.", attack: "Salve de cinq projectiles", sprite: "matriarch" },
  "boss:colossus": { name: "Colosse des cendres", description: "Lent et massif, frappe une large zone au sol.", attack: "Impact de grande zone", sprite: "colossus" },
};

export const ELITE_AFFIXES = {
  armored: { name: "Cuirassé", health: 1.8, speed: 0.78, damage: 1.1, color: "#e2c47b" },
  swift: { name: "Fulgurant", health: 1.2, speed: 1.5, damage: 1.1, color: "#91d6c4" },
  savage: { name: "Féroce", health: 1.3, speed: 1.1, damage: 1.7, color: "#e68463" },
};
