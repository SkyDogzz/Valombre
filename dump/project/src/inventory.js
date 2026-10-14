import { getWeaponSynergyStats } from "./synergies.js";

/** Return the collected progression for a weapon, or its initial progression. */
export function getWeaponProgress(player, weaponId) {
  return (
    player.weaponInventory.find((weapon) => weapon.id === weaponId) ?? {
      id: weaponId,
      level: 1,
      special: false,
    }
  );
}

/** Upgrade a weapon through five levels, then unlock its special version. */
export function upgradeWeapon(player, weaponId) {
  let weapon = player.weaponInventory.find((item) => item.id === weaponId);

  if (!weapon) {
    weapon = {
      id: weaponId,
      level: 1,
      special: false,
    };

    player.weaponInventory.push(weapon);

    return {
      kind: "collected",
      level: 1,
    };
  }
  if (weapon.level < 5) {
    weapon.level += 1;

    return {
      kind: "level",
      level: weapon.level,
    };
  }

  if (!weapon.special) {
    weapon.special = true;

    return {
      kind: "special",
      level: weapon.level,
    };
  }

  return {
    kind: "maximum",
    level: weapon.level,
  };
}

/** Exclude fully evolved weapons from future drops. */
export function getUpgradeableWeaponIds(player, weaponIds) {
  return weaponIds.filter((weaponId) => {
    const weapon = player.weaponInventory.find((item) => item.id === weaponId);

    return !weapon || !weapon.special;
  });
}

/** Return relics that can still gain levels or be collected. */
export function getUpgradeableRelics(player, relics) {
  return relics.filter((relic) => {
    const carriedRelic = player.inventory.find((item) => item.id === relic.id);

    return !carriedRelic || carriedRelic.level < 5;
  });
}

/** Compute the damage and cadence bonuses granted by a weapon's level. */
export function getWeaponCombatStats(player, weaponId, weapon) {
  const progression = getWeaponProgress(player, weaponId);

  const levelBonus = progression.level - 1;

  const specialBonus = progression.special;
  const synergy = getWeaponSynergyStats(player, weaponId);

  return {
    damageMultiplier:
      (1 + levelBonus * 0.18) *
      (specialBonus ? 1.5 : 1) *
      synergy.damageMultiplier,
    attackSpeedMultiplier:
      (1 + levelBonus * 0.08) *
      (specialBonus ? 1.2 : 1) *
      synergy.attackSpeedMultiplier,
    attackSpeed:
      weapon.speed *
      (1 + levelBonus * 0.08) *
      (specialBonus ? 1.2 : 1) *
      synergy.attackSpeedMultiplier,
    range:
      (weapon.range + player.rangeBonus + player.equipmentRange) *
      synergy.rangeMultiplier,
    chainTargets: progression.level,
    experienceMultiplier: synergy.experienceMultiplier,
    slowDurationMultiplier: synergy.slowDurationMultiplier,
  };
}

/** Restore upgrade ranks for older checkpoints that predate rank tracking. */
export function normalizeUpgradeRanks(player) {
  const keys = [
    "damage",
    "attackSpeed",
    "range",
    "projectileSize",
    "projectileSpeed",
    "movementSpeed",
    "health",
    "defense",
    "pickupRange",
  ];
  player.movementSpeedMultiplier =
    Number.isFinite(player.movementSpeedMultiplier) &&
    player.movementSpeedMultiplier > 0
      ? player.movementSpeedMultiplier
      : 1;
  player.levelDefense = Number.isFinite(player.levelDefense)
    ? player.levelDefense
    : 0;
  player.pickupRangeMultiplier =
    Number.isFinite(player.pickupRangeMultiplier) &&
    player.pickupRangeMultiplier > 0
      ? player.pickupRangeMultiplier
      : 1;
  player.bonusMaxHp = Number.isFinite(player.bonusMaxHp)
    ? player.bonusMaxHp
    : 0;
  const infer = (value, base, additive = false) =>
    Math.min(
      10,
      Math.max(
        0,
        Math.round(
          additive
            ? value / base
            : Math.log(Math.max(1, value)) / Math.log(1 + base),
        ),
      ),
    );

  if (!player.upgradeRanks || typeof player.upgradeRanks !== "object") {
    player.upgradeRanks = {
      damage: infer(player.damageMultiplier || 1, 0.2),
      attackSpeed: infer(player.attackSpeedMultiplier || 1, 0.2),
      range: infer(player.rangeBonus || 0, 18, true),
      projectileSize: infer(player.projectileSize || 1, 0.25),
      projectileSpeed: infer(player.projectileSpeed || 1, 0.2),
      movementSpeed: 0,
      health: 0,
      defense: 0,
      pickupRange: 0,
    };
    return player.upgradeRanks;
  }

  player.upgradeRanks = Object.fromEntries(
    keys.map((key) => [
      key,
      Math.min(
        10,
        Math.max(
          0,
          Number.isSafeInteger(player.upgradeRanks[key])
            ? player.upgradeRanks[key]
            : 0,
        ),
      ),
    ]),
  );
  return player.upgradeRanks;
}
