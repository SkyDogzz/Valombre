import { RELICS, WEAPONS } from "./config.js";

export const SYNERGY_REQUIREMENTS = {
  weaponLevel: 5,
  relicLevel: 5,
};

const PAIRINGS = [
  {
    weaponId: "sabre",
    relicId: "talisman",
    description: "Toutes les 5 touches, une explosion de braise frappe la cible et ses voisines",
    damageMultiplier: 1.2,
  },
  {
    weaponId: "marteau",
    relicId: "stone",
    description: "L’impact spéciale frappe tout autour de vous, puis repousse les survivants",
    rangeMultiplier: 1.2,
  },
  {
    weaponId: "dagues",
    relicId: "boots",
    description: "Chaque victime lance des dagues spectrales sur 3 ennemis proches",
  },
  {
    weaponId: "arc",
    relicId: "quiver",
    description: "Chaque tir devient une volée de 3 flèches en éventail",
    attackSpeedMultiplier: 1.18,
  },
  {
    weaponId: "foudre",
    relicId: "relic",
    description: "Chaque éclair peut rebondir deux fois plus loin dans la foule",
    experienceMultiplier: 1.25,
  },
  {
    weaponId: "bombe",
    relicId: "magnet",
    description: "Les objets vous rejoignent en continu et explosent à leur arrivée",
    globalPickup: true,
  },
  {
    weaponId: "lance",
    relicId: "seal",
    description: "Chaque ennemi transpercé vous donne du bouclier",
    damageMultiplier: 1.3,
  },
  {
    weaponId: "faux",
    relicId: "heart",
    description: "Les victimes laissent des âmes qui renforcent votre prochain balayage",
    damageMultiplier: 1.2,
  },
  {
    weaponId: "givre",
    relicId: "vampire",
    description: "Une victime gelée déclenche une nova qui ralentit et blesse les voisines",
    damageMultiplier: 1.2,
    slowDurationMultiplier: 2,
  },
];

export const SYNERGIES = PAIRINGS.map((pairing) => {
  const weapon = WEAPONS[pairing.weaponId];
  const relic = RELICS.find((item) => item.id === pairing.relicId);
  return {
    ...pairing,
    id: `${pairing.weaponId}-${pairing.relicId}`,
    name: `${relic.name} ${weapon.name}`,
  };
});

export function getActiveSynergies(player) {
  const specialWeapons = new Set(
    (player.weaponInventory || [])
      .filter((weapon) => weapon.special && weapon.level >= SYNERGY_REQUIREMENTS.weaponLevel)
      .map((weapon) => weapon.id),
  );
  const maxRelics = new Set(
    (player.inventory || [])
      .filter((relic) => relic.level >= SYNERGY_REQUIREMENTS.relicLevel)
      .map((relic) => relic.id),
  );
  return SYNERGIES.filter(
    (synergy) => specialWeapons.has(synergy.weaponId) && maxRelics.has(synergy.relicId),
  );
}

export function getWeaponSynergyStats(player, weaponId) {
  return getActiveSynergies(player)
    .filter((synergy) => synergy.weaponId === weaponId)
    .reduce(
      (stats, synergy) => ({
        damageMultiplier: stats.damageMultiplier * (synergy.damageMultiplier || 1),
        attackSpeedMultiplier:
          stats.attackSpeedMultiplier *
          (synergy.attackSpeedMultiplier ||
            (player.isMoving ? synergy.movingAttackSpeedMultiplier || 1 : 1)),
        rangeMultiplier: stats.rangeMultiplier * (synergy.rangeMultiplier || 1),
        experienceMultiplier:
          stats.experienceMultiplier * (synergy.experienceMultiplier || 1),
        slowDurationMultiplier:
          stats.slowDurationMultiplier * (synergy.slowDurationMultiplier || 1),
      }),
      {
        damageMultiplier: 1,
        attackSpeedMultiplier: 1,
        rangeMultiplier: 1,
        experienceMultiplier: 1,
        slowDurationMultiplier: 1,
      },
    );
}
