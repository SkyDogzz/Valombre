import { BOSSES, CONFIG, DIFFICULTIES, HEROES, RELICS, WEAPONS, WAVES } from "./config.js";
import { getWeaponCombatStats } from "./inventory.js";
import { getActiveSynergies, SYNERGIES, SYNERGY_REQUIREMENTS } from "./synergies.js";
import { ELITE_AFFIXES, ENEMY_BESTIARY } from "./bestiary.js";

const multiplierNumber = new Intl.NumberFormat("fr-FR", {
  maximumFractionDigits: 2,
});
const enemyMultiplierNumber = new Intl.NumberFormat("fr-FR", {
  notation: "compact",
  maximumFractionDigits: 2,
});
const formatMultiplier = (value) => `×${multiplierNumber.format(value)}`;
const formatEnemyMultiplier = (value) => `×${enemyMultiplierNumber.format(value)}`;
let relicListSignature = null;
let weaponListSignature = null;
let synergyListSignature = null;
let pauseCatalogSignature = null;
const specialWeaponDescriptions = {
  sabre: "marque chaque 3e coup ; le suivant inflige +50 %",
  marteau: "chaque impact libère une onde de choc élargie",
  dagues: "chaque 3e coup inflige une blessure qui saigne pendant 1,8 s",
  arc: "flèche perforante, chaque cible touchée renforce la suivante",
  foudre: "un rebond supplémentaire et une zone électrique au dernier impact",
  bombe: "la détonation brûle brièvement la zone autour de l’impact",
  lance: "l’estoc spécial transperce toutes les cibles sur sa trajectoire",
  faux: "le balayage spécial libère une seconde onde circulaire",
  givre: "les projectiles spéciaux gèlent brièvement les ennemis touchés",
};

function createInventoryIcons(folder, itemId, discoveries = {}) {
  const synergy = SYNERGIES.find((item) =>
    folder === "weapons"
      ? item.weaponId === itemId
      : item.relicId === itemId,
  );
  const icons = document.createElement("span");
  icons.className = "inventory-icons";

  const icon = document.createElement("img");
  icon.className = "inventory-icon";
  icon.src = `assets/${folder}/${itemId}.svg`;
  icon.alt = "";
  icon.setAttribute("aria-hidden", "true");
  icons.append(icon);

  if (!synergy || !discoveries.synergies?.[synergy.id]) return icons;

  const partnerFolder = folder === "weapons" ? "relics" : "weapons";
  const partnerId = folder === "weapons" ? synergy.relicId : synergy.weaponId;
  const partner = folder === "weapons"
    ? RELICS.find((item) => item.id === partnerId)
    : WEAPONS[partnerId];
  const partnerIcon = document.createElement("img");
  partnerIcon.className = "inventory-linked-icon";
  partnerIcon.src = `assets/${partnerFolder}/${partnerId}.svg`;
  partnerIcon.alt = "";
  partnerIcon.setAttribute("aria-hidden", "true");
  icons.append(partnerIcon);

  const own = folder === "weapons" ? WEAPONS[itemId] : RELICS.find((item) => item.id === itemId);
  icons.title = `Combo ${own.name} + ${partner.name} : ${synergy.description}`;
  icons.setAttribute("role", "img");
  icons.setAttribute("aria-label", icons.title);
  return icons;
}

export function renderHud(ui, state) {
  const {
    player,
    bossActive,
    wave,
    runMode,
    enemies,
    intermission,
    pendingSpawns,
    specialCooldown,
    difficulty,
    infiniteElapsedMinutes,
    uncappedInventory,
    discoveries,
  } = state;
  const boss = enemies.find((enemy) => enemy.kind === "boss");
  ui["pause-catalog"].hidden = state.screen !== "paused";
  if (state.screen === "paused")
    renderPauseCatalog(ui["pause-catalog"], player, state.bestiary, discoveries);
  ui["health-fill"].style.width = `${(100 * player.hp) / player.maxHp}%`;
  ui["shield-fill"].style.width = `${Math.min(100, (100 * player.shield) / player.maxHp)}%`;
  ui["xp-fill"].style.width = `${(100 * player.xp) / player.nextXp}%`;
  ui["health-text"].textContent = `${Math.ceil(player.hp)} / ${player.maxHp}${player.shield > 0 ? ` · Bouclier ${Math.ceil(player.shield)}` : ""}`;
  ui["xp-text"].textContent = `${Math.floor(player.xp)} / ${player.nextXp}`;
  ui["health-fill"].parentElement.setAttribute(
    "aria-valuenow",
    String(Math.round(player.hp)),
  );
  ui["health-fill"].parentElement.setAttribute(
    "aria-valuemax",
    String(player.maxHp),
  );
  ui["shield-fill"].parentElement.setAttribute(
    "aria-valuenow",
    String(Math.round(player.shield)),
  );
  ui["shield-fill"].parentElement.setAttribute(
    "aria-valuemax",
    String(player.maxHp),
  );
  ui["xp-fill"].parentElement.setAttribute(
    "aria-valuenow",
    String(Math.floor(player.xp)),
  );
  ui["xp-fill"].parentElement.setAttribute(
    "aria-valuemax",
    String(player.nextXp),
  );
  ui["level-text"].textContent = player.level;
  ui["wave-text"].textContent = bossActive
    ? boss?.bossName || "Un boss approche"
    : wave
      ? runMode === "infinite"
        ? `Survie infinie · Vague ${wave}`
        : `Vague ${wave} / ${WAVES.length}`
      : "La forêt sommeille";
  ui["enemy-text"].textContent = bossActive
    ? `Affrontez ${boss?.bossName?.toLowerCase() || "le boss"}`
    : wave
      ? intermission > 0
        ? `Prochaine vague dans ${Math.ceil(intermission)} s`
        : `${enemies.length + pendingSpawns.length} créature${enemies.length + pendingSpawns.length === 1 ? "" : "s"} restante${enemies.length + pendingSpawns.length === 1 ? "" : "s"}`
      : "Prêt à partir";
  ui["difficulty-text"].textContent =
    `DIFFICULTÉ · ${{ insane: "INSANE", nightmare: "CAUCHEMAR", cataclysm: "CATACLYSME" }[difficulty] || "INSANE"}`;
  const objective = state.waveObjective;
  const objectiveLabel = objective
    ? `${objective.complete ? "✓ Objectif" : "Objectif"} · ${{ kills: "Vaincre", xp: "Ramasser des orbes d’XP", elite: "Vaincre des élites" }[objective.type]} ${objective.progress}/${objective.target} · récompense : +18 % PV`
    : "";
  const challenges = (state.runChallenges || []).map((challenge) =>
    `${challenge.complete ? "✓" : "Défi"} · ${challenge.label} ${challenge.progress}/${challenge.target} · ${challenge.reward}`,
  );
  ui["run-objectives"].textContent = [objectiveLabel, ...challenges].filter(Boolean).join(" · ");
  ui["special-skill"].hidden = !HEROES[player.hero].special;
  ui["special-action"].hidden = !HEROES[player.hero].special;
  ui["skill-text"].textContent =
    specialCooldown > 0 ? `Recharge ${specialCooldown.toFixed(1)} s` : "Prête";
  ui["dodge-text"].textContent =
    player.dodgeCooldown > 0
      ? `Recharge ${player.dodgeCooldown.toFixed(1)} s`
      : "Prête";
  const active = player.weaponInventory.find((w) => w.id === player.weapon);
  ui["weapon-name"].textContent =
    `Départ · ${WEAPONS[player.weapon].name} · niv. ${active?.level || 1}${active?.special ? " · spéciale" : ""}`;
  const hero = HEROES[player.hero];
  ui["hero-name"].textContent = hero.name.toUpperCase();
  ui["hero-class"].textContent = hero.className;
  ui["special-name"].textContent = hero.specialName || "";
  if (hero.specialName) ui["special-action"].setAttribute("aria-label", hero.specialName);
  ui["inventory-count"].textContent = `${player.inventory.length} / ${uncappedInventory ? "∞" : CONFIG.drops.maxRelics}`;
  ui["weapon-count"].textContent =
    `${player.weaponInventory.length} / ${uncappedInventory ? "∞" : CONFIG.drops.maxWeapons}`;
  const synergyDiscoverySignature = JSON.stringify(discoveries.synergies || {});
  const nextRelicListSignature = player.inventory
    .map((item) => `${item.id}:${item.level}:${item.name}:${item.description}:${item.locked ? 1 : 0}`)
    .join("|") + synergyDiscoverySignature;
  if (nextRelicListSignature !== relicListSignature) {
    const focusedRelicId = document.activeElement.matches("[data-relic-lock]")
      ? document.activeElement.dataset.relicLock
      : null;
    relicListSignature = nextRelicListSignature;
    ui["relic-list"].replaceChildren(
      ...player.inventory.map((item) => {
        const li = document.createElement("li");
        li.className = "relic-slot inventory-item";
        const icons = createInventoryIcons("relics", item.id, discoveries);
        const copy = document.createElement("span");
        copy.className = "inventory-copy";
        const name = document.createElement("span");
        name.textContent = `${item.name} · niv. ${item.level || 1}${item.level >= 5 ? " ★" : ""}`;
        const desc = document.createElement("small");
        desc.textContent = item.description;
        copy.append(name, desc);
        const lockLabel = document.createElement("label");
        lockLabel.className = "relic-lock";
        lockLabel.title = `Verrouiller ${item.name} contre le remplacement`;
        const lock = document.createElement("input");
        lock.type = "checkbox";
        lock.checked = Boolean(item.locked);
        lock.dataset.relicLock = item.id;
        lock.setAttribute("aria-label", `Verrouiller ${item.name}`);
        lockLabel.append(lock);
        li.append(icons, copy, lockLabel);
        return li;
      }),
    );
    if (focusedRelicId)
      ui["relic-list"]
        .querySelector(`[data-relic-lock="${focusedRelicId}"]`)
        ?.focus();
  }
  const nextWeaponListSignature = player.weaponInventory
    .map(
      (item) =>
        `${item.id}:${item.level}:${item.special ? 1 : 0}:${item.id === player.weapon ? 1 : 0}:${item.locked ? 1 : 0}`,
    )
    .join("|") + synergyDiscoverySignature;
  if (nextWeaponListSignature !== weaponListSignature) {
    const focusedWeaponId = document.activeElement.matches("[data-weapon-lock]")
      ? document.activeElement.dataset.weaponLock
      : null;
    weaponListSignature = nextWeaponListSignature;
    ui["weapon-list"].replaceChildren(
      ...player.weaponInventory.map((item) => {
        const li = document.createElement("li");
        li.className = `relic-slot weapon-slot inventory-item${item.id === player.weapon ? " starting" : ""}`;
        const icons = createInventoryIcons("weapons", item.id, discoveries);
        const copy = document.createElement("span");
        copy.className = "inventory-copy";
        const name = document.createElement("span");
        name.textContent = `${item.id === player.weapon ? "DÉPART · " : ""}${WEAPONS[item.id].name} · niv. ${item.level}${item.special ? " · spéciale" : ""}`;
        const desc = document.createElement("small");
        desc.textContent =
          WEAPONS[item.id].description +
          (item.special
            ? ` · dégâts et cadence renforcés · ${specialWeaponDescriptions[item.id]}`
            : "");
        copy.append(name, desc);
        const lockLabel = document.createElement("label");
        lockLabel.className = "relic-lock";
        lockLabel.title = `Verrouiller ${WEAPONS[item.id].name} contre le remplacement`;
        const lock = document.createElement("input");
        lock.type = "checkbox";
        lock.checked = Boolean(item.locked);
        lock.dataset.weaponLock = item.id;
        lock.setAttribute("aria-label", `Verrouiller ${WEAPONS[item.id].name}`);
        lockLabel.append(lock);
        li.append(icons, copy, lockLabel);
        return li;
      }),
    );
    if (focusedWeaponId)
      ui["weapon-list"]
        .querySelector(`[data-weapon-lock="${focusedWeaponId}"]`)
        ?.focus();
  }
  const weapon = WEAPONS[player.weapon];
  const weaponStats = getWeaponCombatStats(player, player.weapon, weapon);
  const levelDamageBonus =
    1 + (player.level - 1) * CONFIG.player.levelDamageBonus;
  const levelHealthBonus =
    1 + (player.level - 1) * CONFIG.player.levelHealthBonus;
  const weaponSummary = [
    `Dégâts ${formatMultiplier(player.damageMultiplier * levelDamageBonus * player.equipmentDamage * weaponStats.damageMultiplier)}`,
    `Bonus niveau ${formatMultiplier(levelDamageBonus)} dégâts · ${formatMultiplier(levelHealthBonus)} PV`,
    `Cadence ${formatMultiplier(player.attackSpeedMultiplier * weaponStats.attackSpeedMultiplier)}`,
    `Portée ${Math.round(weaponStats.range)}`,
    `Déplacement ${formatMultiplier(player.movementSpeedMultiplier * player.equipmentSpeed)}`,
    `Défense −${Math.round((player.equipmentDefense + player.levelDefense) * 100)} %`,
    `Ramassage ${Math.round(player.pickupRange)}`,
  ];
  if (weapon.ranged) {
    weaponSummary.push(
      `Projectiles ${formatMultiplier(player.projectileSize)}`,
      `Vitesse ${formatMultiplier(player.projectileSpeed)}`,
    );
  }
  ui["weapon-stats"].textContent = weaponSummary.join(" · ");
  ui["relic-stats"].textContent = [
    `Dégâts ${formatMultiplier(player.equipmentDamage)}`,
    `Déplacement ${formatMultiplier(player.equipmentSpeed)}`,
    `Portée +${Math.round(player.equipmentRange)}`,
    `Défense −${Math.round(player.equipmentDefense * 100)} %`,
    `XP ${formatMultiplier(player.equipmentXp)}`,
    `Vol de vie ${Math.round(player.equipmentLifesteal * 100)} %`,
    `PV max +${Math.round(player.equipmentHealth || 0)}`,
    `Ramassage ${Math.round(player.pickupRange)}`,
  ].join(" · ");
  const activeSynergies = getActiveSynergies(player);
  ui["synergy-count"].textContent = `${activeSynergies.length} / ${SYNERGIES.length}`;
  const nextSynergySignature = activeSynergies.map((item) => item.id).join("|");
  if (nextSynergySignature !== synergyListSignature) {
    synergyListSignature = nextSynergySignature;
    ui["synergy-list"].replaceChildren(
      ...(activeSynergies.length
        ? activeSynergies.map((synergy) => {
            const item = document.createElement("li");
            const name = document.createElement("strong");
            name.textContent = synergy.name;
            const description = document.createElement("small");
            description.textContent = synergy.description;
            item.className = "synergy-item";
            item.title = `${synergy.name} · ${synergy.description}`;
            item.append(name, description);
            return item;
          })
        : [Object.assign(document.createElement("li"), {
            className: "inventory-hint",
            textContent: "Aucune active",
          })]),
    );
  }
  const difficultyStats = DIFFICULTIES[difficulty] || DIFFICULTIES.insane;
  const infiniteProgress = runMode === "infinite" ? Math.max(0, wave - 1) : 0;
  const infiniteScale = runMode === "infinite";
  const baseSpawnCapacity = Math.max(1, CONFIG.enemies.maxAlive ?? 10);
  const currentSpawnCapacity = infiniteScale
    ? Math.min(
        CONFIG.enemies.infiniteMaxCapacity,
        baseSpawnCapacity +
          Math.floor(
            infiniteElapsedMinutes *
              CONFIG.enemies.infiniteCapacityGrowthPerMinute,
          ),
      )
    : baseSpawnCapacity;
  const enemyMultipliers = {
    health: difficultyStats.health * (infiniteScale ? Math.pow(1.28, infiniteProgress) : 1),
    damage: difficultyStats.damage * (infiniteScale ? Math.pow(1.22, infiniteProgress) : 1),
    speed:
      difficultyStats.speed *
      (infiniteScale
        ? 1 + Math.min(1.2, infiniteProgress * 0.035)
        : 1),
    attackSpeed: difficultyStats.attackSpeed,
    projectileSpeed: difficultyStats.projectileSpeed,
    itemDrop: difficultyStats.itemDrop,
    spawnCapacity:
      difficultyStats.spawnCapacity * (currentSpawnCapacity / baseSpawnCapacity),
  };
  ui["enemy-stats"].textContent = [
    `PV ${formatEnemyMultiplier(enemyMultipliers.health)}`,
    `Dégâts ${formatEnemyMultiplier(enemyMultipliers.damage)}`,
    `Vitesse ${formatEnemyMultiplier(enemyMultipliers.speed)}`,
    `Cadence ${formatEnemyMultiplier(enemyMultipliers.attackSpeed)}`,
    `Projectiles ${formatEnemyMultiplier(enemyMultipliers.projectileSpeed)}`,
    `Limite ${formatEnemyMultiplier(enemyMultipliers.spawnCapacity)}`,
    `Butin ${formatEnemyMultiplier(enemyMultipliers.itemDrop)}`,
  ].join(" · ");
  ui["boss-name"].textContent = boss?.bossName?.toUpperCase() || "BOSS";
  ui["boss-hud"].hidden = !boss;
  ui["boss-fill"].style.width = boss
    ? `${(100 * boss.hp) / boss.maxHp}%`
    : "0%";
}

function renderPauseCatalog(container, player, bestiary = {}, discoveries = {}) {
  const signature = `${player.weaponInventory.map((item) => `${item.id}:${item.level}:${item.special}`).join("|")}/${player.inventory.map((item) => `${item.id}:${item.level}`).join("|")}/${JSON.stringify(bestiary)}/${JSON.stringify(discoveries)}`;
  if (signature === pauseCatalogSignature) return;
  pauseCatalogSignature = signature;

  const makeSection = (title, definitions, owned, discovered, folder, statusFor) => {
    const section = document.createElement("section");
    section.className = "catalog-section";
    const heading = document.createElement("h3");
    const categoryIcon = document.createElement("img");
    categoryIcon.src = `assets/${folder}/category.svg`;
    categoryIcon.alt = "";
    categoryIcon.setAttribute("aria-hidden", "true");
    const headingText = document.createElement("span");
    headingText.textContent = title;
    heading.append(categoryIcon, headingText);
    const list = document.createElement("ul");
    list.className = "catalog-list";
    for (const [id, definition] of Object.entries(definitions)) {
      const item = owned.get(id);
      const seen = Boolean(discovered[id] || item);
      const card = document.createElement("li");
      card.className = `catalog-card${item ? " owned" : seen ? " discovered" : " undiscovered"}`;
      card.tabIndex = 0;
      const icon = document.createElement("img");
      icon.src = `assets/${folder}/${id}.svg`;
      icon.alt = "";
      icon.setAttribute("aria-hidden", "true");
      const copy = document.createElement("span");
      copy.className = "catalog-copy";
      const name = document.createElement("strong");
      name.textContent = definition.name;
      const description = document.createElement("small");
      description.textContent = definition.description;
      const status = document.createElement("small");
      status.className = "catalog-status";
      status.textContent = statusFor(item, seen);
      card.title = `${definition.name} · ${definition.description} · ${status.textContent}`;
      card.setAttribute("aria-label", card.title);
      copy.append(name, description, status);
      card.append(icon, copy);
      list.append(card);
    }
    section.append(heading, list);
    return section;
  };

  const weapons = new Map(player.weaponInventory.map((item) => [item.id, item]));
  const relics = new Map(player.inventory.map((item) => [item.id, item]));
  const activeSynergies = new Map(
    getActiveSynergies(player).map((item) => [item.id, item]),
  );
  const synergySection = document.createElement("section");
  synergySection.className = "catalog-section synergy-catalog-section";
  const synergyHeading = document.createElement("h3");
  synergyHeading.textContent = `Synergies · ${activeSynergies.size} / ${SYNERGIES.length}`;
  const synergyList = document.createElement("ul");
  synergyList.className = "catalog-list synergy-catalog-list";
  for (const synergy of SYNERGIES) {
    const active = activeSynergies.has(synergy.id);
    const seen = Boolean(discoveries.synergies?.[synergy.id]);
    const card = document.createElement("li");
    card.className = `catalog-card${!seen ? " undiscovered" : active ? " owned" : " discovered"}`;
    const icons = document.createElement("span");
    icons.className = "synergy-icons";
    for (const folder of ["weapons", "relics"]) {
      const icon = document.createElement("img");
      icon.src = `assets/${folder}/${folder === "weapons" ? synergy.weaponId : synergy.relicId}.svg`;
      icon.alt = "";
      icon.setAttribute("aria-hidden", "true");
      icons.append(icon);
    }
    const copy = document.createElement("span");
    copy.className = "catalog-copy";
    const name = document.createElement("strong");
    name.textContent = seen ? synergy.name : "Combo inconnu";
    const description = document.createElement("small");
    description.textContent = seen
      ? synergy.description
      : "Déclenchez ce combo en jeu pour le découvrir.";
    const status = document.createElement("small");
    status.className = "catalog-status";
    const recipe = `${WEAPONS[synergy.weaponId].name} spéciale niv. ${SYNERGY_REQUIREMENTS.weaponLevel} + ${RELICS.find((item) => item.id === synergy.relicId).name} niv. ${SYNERGY_REQUIREMENTS.relicLevel}`;
    status.textContent = seen
      ? `${active ? "Activée · " : "À refaire · "}${recipe}`
      : "Non découvert";
    copy.append(name, description, status);
    card.append(icons, copy);
    synergyList.append(card);
  }
  synergySection.append(synergyHeading, synergyList);
  const bestiarySection = document.createElement("section");
  bestiarySection.className = "catalog-section";
  const bestiaryHeading = document.createElement("h3");
  bestiaryHeading.textContent = "Bestiaire";
  const bestiaryList = document.createElement("ul");
  bestiaryList.className = "catalog-list";
  const entries = [
    ...Object.entries(ENEMY_BESTIARY),
    ...Object.entries(ELITE_AFFIXES).map(([id, elite]) => [`elite:${id}`, { name: `Élite · ${elite.name}`, description: "Variante renforcée d’un ennemi ordinaire.", attack: "Capacités de son espèce" }]),
  ];
  for (const [id, definition] of entries) {
    const record = bestiary[id];
    const seen = Boolean(record?.discovered || record?.kills);
    const card = document.createElement("li");
    card.className = `catalog-card${seen ? " owned" : " undiscovered"}`;
    const copy = document.createElement("span");
    copy.className = "catalog-copy";
    const name = document.createElement("strong");
    name.textContent = seen ? definition.name : "Inconnu";
    const description = document.createElement("small");
    const stats = id.startsWith("boss:")
      ? BOSSES[id.slice(5)]
      : id.startsWith("elite:")
        ? ELITE_AFFIXES[id.slice(6)]
        : CONFIG.enemies[id];
    const statsLabel = id.startsWith("elite:")
      ? `Multiplicateurs · PV ×${stats.health} · vitesse ×${stats.speed} · dégâts ×${stats.damage}`
      : stats
        ? `PV ${stats.health} · vitesse ${Math.round(stats.speed)} · dégâts ${stats.damage || stats.slamDamage || 0}`
        : "";
    description.textContent = seen
      ? `${definition.description} Attaque : ${definition.attack}. ${statsLabel}`
      : "Créature non rencontrée.";
    const count = document.createElement("small");
    count.className = "catalog-status";
    count.textContent = seen ? `Vaincus : ${record?.kills || 0}` : "Non découvert";
    copy.append(name, description, count);
    card.append(copy);
    bestiaryList.append(card);
  }
  bestiarySection.append(bestiaryHeading, bestiaryList);
  container.replaceChildren(
    makeSection(
      "Armes",
      WEAPONS,
      weapons,
      discoveries.weapons || {},
      "weapons",
      (item, seen) =>
        item
          ? `Possédée · niveau ${item.level}${item.special ? " · spéciale" : ""}`
          : seen
            ? "Découverte · non équipée"
            : "À découvrir",
    ),
    makeSection(
      "Reliques",
      Object.fromEntries(RELICS.map((item) => [item.id, item])),
      relics,
      discoveries.relics || {},
      "relics",
      (item, seen) =>
        item
          ? `Possédée · niveau ${item.level || 1}`
          : seen
            ? "Découverte · non équipée"
            : "À découvrir",
    ),
    synergySection,
    bestiarySection,
  );
}
