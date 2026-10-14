import {
  STATES,
  CONFIG,
  BOSSES,
  DIFFICULTIES,
  WEAPONS,
  HEROES,
  WAVES,
  UPGRADES,
  RELICS,
} from "./config.js";

import {
  getUpgradeableRelics,
  getUpgradeableWeaponIds,
  getWeaponCombatStats,
  getWeaponProgress,
  normalizeUpgradeRanks,
  upgradeWeapon,
} from "./inventory.js";

import { createChoiceCard, createUiElements } from "./ui.js";
import { createRenderer } from "./renderer.js";
import { createInputControls } from "./input.js";
import { renderHud } from "./hud.js";
import {
  getActiveSynergies,
  SYNERGIES,
  SYNERGY_REQUIREMENTS,
} from "./synergies.js";
import { ELITE_AFFIXES } from "./bestiary.js";

(() => {
  const canvas = document.querySelector("#game");
  const VIEW_WIDTH = canvas.width;
  const VIEW_HEIGHT = canvas.height;
  const world = { width: 1500, height: 1100 };

  const obstacles = [
    {
      x: world.width / 2 - 145,
      y: world.height / 2 - 20,
      r: 27,
    },
    {
      x: world.width / 2 + 148,
      y: world.height / 2 + 55,
      r: 31,
    },
    {
      x: world.width / 2 + 20,
      y: world.height / 2 - 135,
      r: 23,
    },
    {
      x: world.width / 2 - 15,
      y: world.height / 2 + 155,
      r: 24,
    },
  ];
  const renderGame = createRenderer(canvas, world, obstacles);

  const ui = createUiElements();
  const singleWeaponToggle = document.getElementById("single-weapon");
  const uncappedInventoryToggle = document.getElementById("uncapped-inventory");
  const autoPickUpgradeToggle = document.getElementById("auto-pick-upgrade");

  let player,
    enemies,
    drops,
    particles,
    projectiles,
    damageNumbers,
    lightningArcs = [],
    weaponEffects = [],
    pendingSpawns = [],
    intermission = 0,
    bossActive = false,
    selectedHero = "pilgrim",
    selectedWeapon = "sabre",
    state = STATES.title,
    last = 0,
    animationFrameId = null,
    runStarted = 0,
    runSeconds = 0,
    spawnClock = 0,
    swarmTimer = -1,
    wave = 0,
    defeated = 0,
    specialCooldown = 0,
    noticeTimer = 0,
    camera = {
      x: 0,
      y: 0,
    };

  let relicHudSignature = null,
    runMode = "waves",
    difficulty = "insane",
    singleWeapon = false,
    uncappedInventory = false,
    selectedDropWeapons = Object.keys(WEAPONS),
    selectedDropRelics = RELICS.map((relic) => relic.id),
    lastInfiniteHudMinute = -1,
    waveObjective = null,
    runChallenges = null;
  const SAVE_KEY = "valombre.save.v1";
  let saveData = {
    wins: 0,
    bestKills: 0,
    shards: 0,
    hero: selectedHero,
    weapon: selectedWeapon,
    bestiary: {},
    discoveredWeapons: {},
    discoveredRelics: {},
    discoveredSynergies: {},
    muted: false,
    volume: 0.25,
    autoPickUpgrade: true,
  };
  try {
    saveData = {
      ...saveData,
      ...JSON.parse(localStorage.getItem(SAVE_KEY) || "{}"),
    };
  } catch {}
  if (HEROES[saveData.hero]) selectedHero = saveData.hero;
  else saveData.hero = "pilgrim";
  if (WEAPONS[saveData.weapon]) selectedWeapon = saveData.weapon;
  else saveData.weapon = "sabre";
  const savedRun = saveData.run;
  if (
    !savedRun ||
    savedRun.version !== 1 ||
    !["waves", "infinite"].includes(savedRun.mode) ||
    !Number.isSafeInteger(savedRun.wave) ||
    savedRun.wave < 1 ||
    (savedRun.mode === "waves" && savedRun.wave > WAVES.length) ||
    !savedRun.player ||
    !HEROES[savedRun.player.hero] ||
    !WEAPONS[savedRun.player.weapon] ||
    !Array.isArray(savedRun.player.inventory) ||
    !Array.isArray(savedRun.player.weaponInventory)
  )
    saveData.run = null;
  if (saveData.run && !DIFFICULTIES[saveData.run.difficulty])
    saveData.run.difficulty = "insane";
  for (const key of ["wins", "bestKills", "shards"])
    saveData[key] =
      Number.isSafeInteger(saveData[key]) && saveData[key] >= 0
        ? saveData[key]
        : 0;
  saveData.muted = typeof saveData.muted === "boolean" ? saveData.muted : false;
  saveData.autoPickUpgrade =
    typeof saveData.autoPickUpgrade === "boolean"
      ? saveData.autoPickUpgrade
      : true;
  saveData.bestiary = saveData.bestiary && typeof saveData.bestiary === "object" ? saveData.bestiary : {};
  for (const key of [
    "discoveredWeapons",
    "discoveredRelics",
    "discoveredSynergies",
  ])
    saveData[key] = saveData[key] && typeof saveData[key] === "object" ? saveData[key] : {};
  saveData.singleWeapon =
    typeof saveData.singleWeapon === "boolean" ? saveData.singleWeapon : false;
  singleWeapon = saveData.singleWeapon;
  saveData.uncappedInventory =
    typeof saveData.uncappedInventory === "boolean"
      ? saveData.uncappedInventory
      : false;
  uncappedInventory = saveData.uncappedInventory;
  const validDropIds = (selection, allIds) =>
    Array.isArray(selection)
      ? [...new Set(selection.filter((id) => allIds.includes(id)))]
      : allIds;
  const weaponIds = Object.keys(WEAPONS);
  const relicIds = RELICS.map((relic) => relic.id);
  const runOptionsFromUrl = new URLSearchParams(window.location.search);
  const hasUrlOption = (key) => runOptionsFromUrl.has(key);
  const urlMode = runOptionsFromUrl.get("mode");
  const urlDifficulty = runOptionsFromUrl.get("diff") ?? runOptionsFromUrl.get("difficulty");
  const parseBooleanOption = (key) => {
    const value = runOptionsFromUrl.get(key);
    return value === "1" || value === "true" ? true : value === "0" || value === "false" ? false : null;
  };
  const parseDropOption = (key, allIds) => {
    if (!hasUrlOption(key)) return null;
    const value = runOptionsFromUrl.get(key);
    return value === "" ? [] : validDropIds(value.split(","), allIds);
  };
  selectedDropWeapons = validDropIds(
    saveData.dropWeapons,
    Object.keys(WEAPONS),
  );
  selectedDropRelics = validDropIds(
    saveData.dropRelics,
    RELICS.map((relic) => relic.id),
  );
  const urlDropWeapons = parseDropOption("weapons", weaponIds);
  const urlDropRelics = parseDropOption("relics", relicIds);
  const urlUncapped = parseBooleanOption("uncapped");
  const urlSingleWeapon = parseBooleanOption("singleWeapon");
  const urlCustomDrops = parseBooleanOption("customDrops");
  if (!saveData.run) {
    if (["waves", "infinite"].includes(urlMode))
      document.getElementById("mode-select").value = urlMode;
    if (DIFFICULTIES[urlDifficulty])
      document.getElementById("difficulty-select").value = urlDifficulty;
    if (urlDropWeapons !== null) selectedDropWeapons = urlDropWeapons;
    if (urlDropRelics !== null) selectedDropRelics = urlDropRelics;
    if (urlDropWeapons !== null || urlDropRelics !== null)
      saveData.customDrops = true;
    if (urlCustomDrops !== null) saveData.customDrops = urlCustomDrops;
    if (urlUncapped !== null) uncappedInventory = urlUncapped;
    if (urlSingleWeapon !== null) singleWeapon = urlSingleWeapon;
  }
  const dropWeaponInputs = new Map(),
    dropRelicInputs = new Map();
  for (const [id, weapon] of Object.entries(WEAPONS)) {
    const label = document.createElement("label"),
      input = document.createElement("input");
    input.type = "checkbox";
    input.value = id;
    input.checked = selectedDropWeapons.includes(id);
    label.append(input, document.createTextNode(weapon.name));
    ui.dropWeapons.append(label);
    dropWeaponInputs.set(id, input);
  }
  for (const relic of RELICS) {
    const label = document.createElement("label"),
      input = document.createElement("input");
    input.type = "checkbox";
    input.value = relic.id;
    input.checked = selectedDropRelics.includes(relic.id);
    label.append(input, document.createTextNode(relic.name));
    ui.dropRelics.append(label);
    dropRelicInputs.set(relic.id, input);
  }
  saveData.volume =
    Number.isFinite(saveData.volume) &&
    saveData.volume >= 0 &&
    saveData.volume <= 1
      ? saveData.volume
      : 0.25;
  let audioContext = null;

  // Persistence and audio
  function saveProgress() {
    try {
      localStorage.setItem(SAVE_KEY, JSON.stringify(saveData));
    } catch {
      ui.saveText.textContent =
        "Sauvegarde locale indisponible dans ce navigateur.";
    }
  }

  function markDiscovered(collection, id) {
    if (!id || saveData[collection][id]) return;
    saveData[collection][id] = true;
    saveProgress();
  }

  function discoverSynergy(id) {
    markDiscovered("discoveredSynergies", id);
  }

  function showProgress() {
    ui.saveText.textContent = `Victoires : ${saveData.wins || 0} · Éclats : ${saveData.shards || 0} · Meilleur score : ${saveData.bestKills || 0} créatures`;
  }

  function sound(frequency = 220, duration = 0.07, type = "sine") {
    if (saveData.muted || saveData.volume <= 0) return;
    try {
      audioContext ||= new (window.AudioContext || window.webkitAudioContext)();
      if (audioContext.state === "suspended") audioContext.resume();
      const oscillator = audioContext.createOscillator(),
        gain = audioContext.createGain();
      oscillator.type = type;
      oscillator.frequency.value = frequency;
      gain.gain.setValueAtTime(
        0.08 * saveData.volume,
        audioContext.currentTime,
      );
      gain.gain.exponentialRampToValueAtTime(
        0.001,
        audioContext.currentTime + duration,
      );
      oscillator.connect(gain);
      gain.connect(audioContext.destination);
      oscillator.start();
      oscillator.stop(audioContext.currentTime + duration);
    } catch {}
  }

  const rand = (a, b) => a + Math.random() * (b - a),
    clamp = (v, a, b) => Math.max(a, Math.min(b, v));

  const screens = {
    title: [
      "La nuit se lève",
      "Les morts se sont éveillés. Traversez la clairière et survivez aux vagues.",
      "Entrer dans la forêt",
    ],
    paused: [
      "La chasse attend",
      "Prenez votre souffle avant de retourner dans la clairière.",
      "Reprendre la chasse",
    ],
    levelUp: [
      "Une nouvelle force",
      "Choisissez une amélioration pour poursuivre votre chasse.",
      "",
    ],
    loot: [
      "Sacoche pleine",
      "Choisissez une relique à remplacer ou gardez votre équipement actuel.",
      "",
    ],
    victory: ["Valombre est libérée", "", "Rejouer"],
    defeat: ["La forêt vous reprend", "", "Rejouer"],
  };

  let pendingLoot = null;
  let autoPickUpgradeTimer = null;

  function scheduleAutoPickUpgrade() {
    clearTimeout(autoPickUpgradeTimer);
    if (state !== STATES.levelUp || !saveData.autoPickUpgrade) return;
    autoPickUpgradeTimer = setTimeout(() => {
      if (state === STATES.levelUp && saveData.autoPickUpgrade)
        ui.upgradeOptions.querySelector("button")?.click();
    }, 3000);
  }

  // Run lifecycle and screen state
  function reset() {
    relicHudSignature = null;
    lastInfiniteHudMinute = -1;
    waveObjective = null;
    runChallenges = null;
    const hero = HEROES[selectedHero];
    player = {
      x: world.width / 2,
      y: world.height / 2,
      hp: hero.health,
      maxHp: hero.health,
      shield: 0,
      scytheSouls: 0,
      cheatInfiniteLife: false,
      speed: hero.speed,
      hero: selectedHero,
      weapon: selectedWeapon,
      weaponInventory: [
        {
          id: selectedWeapon,
          level: 1,
          special: false,
        },
      ],
      weaponCooldowns: {},
      weaponAttackTimers: {},
      weaponSwingCount: {},
      projectileSize: 1,
      projectileSpeed: 1,
      upgradeRanks: {
        damage: 0,
        attackSpeed: 0,
        range: 0,
        projectileSize: 0,
        projectileSpeed: 0,
        movementSpeed: 0,
        health: 0,
        defense: 0,
        pickupRange: 0,
      },
      damageMultiplier: 1,
      attackSpeedMultiplier: 1,
      rangeBonus: 0,
      inventory: [],
      equipmentDamage: 1,
      equipmentSpeed: 1,
      movementSpeedMultiplier: 1,
      equipmentRange: 0,
      equipmentDefense: 0,
      levelDefense: 0,
      equipmentXp: 1,
      equipmentLifesteal: 0,
      bonusMaxHp: 0,
      pickupRange: CONFIG.drops.pickupRange,
      pickupRangeMultiplier: 1,
      level: 1,
      xp: 0,
      nextXp: CONFIG.player.firstUpgradeXp,
      pendingUpgrades: 0,
      faceX: 0,
      faceY: 1,
      attack: 0,
      invuln: 0,
      dodgeTime: 0,
      dodgeCooldown: 0,
      dodgeX: 0,
      dodgeY: 1,
      globalPickup: false,
    };
    enemies = [];
    drops = [];
    particles = [];
    projectiles = [];
    damageNumbers = [];
    lightningArcs = [];
    weaponEffects = [];
    pendingLoot = null;
    pendingSpawns = [];
    intermission = 0;
    bossActive = false;
    input.reset();
    camera = {
      x: 0,
      y: 0,
    };
    spawnClock = CONFIG.enemies.firstSpawn;
    swarmTimer = -1;
    wave = 0;
    defeated = 0;
    specialCooldown = 0;
    last = 0;
    noticeTimer = 0;
    ui.notice.classList.remove("visible");
    showNotice("La forêt retient son souffle");
    updateHud();
  }

  function setState(next, copy = screens[next]?.[1] ?? "") {
    clearTimeout(autoPickUpgradeTimer);
    state = next;
    if (next === STATES.levelUp) scheduleAutoPickUpgrade();
    const screen = screens[next];
    if (screen) {
      ui.dialogTitle.textContent = screen[0];
      ui.dialogCopy.textContent =
        next === STATES.levelUp && saveData.autoPickUpgrade
          ? `${copy} (choix automatique après 3 s sans action)`
          : copy;
      ui.start.textContent =
        next === STATES.title && saveData.run
          ? `Reprendre · vague ${saveData.run.wave}`
          : screen[2];
    }
    const choosing = next === STATES.levelUp || next === STATES.loot,
      result = next === STATES.victory || next === STATES.defeat;
    ui.start.hidden = choosing;
    ui.restartRun.hidden = next !== STATES.paused;
    ui.returnMenu.hidden = !result;
    ui.upgradeOptions.hidden = !choosing;
    ui.pauseCatalog.hidden = next !== STATES.paused;
    ui.lootPreview.hidden =
      next !== STATES.loot || pendingLoot?.type !== "weapon";
    if (next !== STATES.loot || pendingLoot?.type !== "weapon")
      ui.lootPreview.replaceChildren();
    ui.cheatToggle.hidden = next !== STATES.playing;
    ui.cheatToggle.setAttribute("aria-pressed", String(Boolean(player.cheatInfiniteLife)));
    ui.cheatToggle.textContent = `VIE INFINIE · ${player.cheatInfiniteLife ? "ON" : "OFF"}`;
    ui.heroPicker.hidden = next !== STATES.title || Boolean(saveData.run);
    ui.weaponPicker.hidden = next !== STATES.title || Boolean(saveData.run);
    ui.modePicker.hidden = next !== STATES.title || Boolean(saveData.run);
    ui.difficultyPicker.hidden = next !== STATES.title || Boolean(saveData.run);
    ui.dropSettings.hidden = next !== STATES.title || Boolean(saveData.run);
    ui.shareRun.hidden = next !== STATES.title || Boolean(saveData.run);
    ui.dropOptions.hidden = !ui.customDrops.checked;
    ui.choiceHint.hidden = next !== STATES.title || Boolean(saveData.run);
    ui.newRun.hidden = next !== STATES.title || !saveData.run;
    ui.overlay.classList.toggle("hidden", next === STATES.playing);
    document
      .querySelector(".game-frame")
      .classList.toggle("playing", next === STATES.playing);
    document.querySelector(".touch-controls").hidden = next !== STATES.playing;
    document
      .querySelector(".dialog")
      .classList.toggle("choosing-upgrade", choosing);
    document.querySelector(".dialog").classList.toggle("paused", next === STATES.paused);
    if (next === STATES.paused || next === STATES.title || result)
      ui.start.focus();
    if (next === STATES.playing) canvas.focus();
    updateHud();
  }

  function showNotice(text) {
    ui.notice.textContent = text;
    ui.notice.classList.add("visible");
    noticeTimer = 1.8;
  }

  function toggleInventory() {
    ui.inventoryPanel.hidden = !ui.inventoryPanel.hidden;
    ui.inventoryToggle.setAttribute(
      "aria-expanded",
      String(!ui.inventoryPanel.hidden),
    );
  }

  function updateHud() {
    renderHud(ui, {
      player,
      bossActive,
      wave,
      runMode,
      enemies,
      intermission,
      pendingSpawns,
      specialCooldown,
      difficulty,
      infiniteElapsedMinutes:
        runMode === "infinite" && wave ? infiniteElapsedMinutes() : 0,
      screen: state,
      waveObjective,
      runChallenges,
      uncappedInventory,
      bestiary: saveData.bestiary,
      discoveries: {
        weapons: saveData.discoveredWeapons,
        relics: saveData.discoveredRelics,
        synergies: saveData.discoveredSynergies,
      },
    });
  }

  // Menu actions and run start
  function start() {
    if (state === STATES.paused) {
      setState(STATES.playing);
      last = performance.now();
      scheduleLoop();
      return;
    }
    if (saveData.run) {
      const checkpoint = saveData.run;
      runMode = checkpoint.mode;
      difficulty = checkpoint.difficulty;
      singleWeapon = Boolean(checkpoint.singleWeapon);
      uncappedInventory = Boolean(checkpoint.uncappedInventory);
      selectedDropWeapons = validDropIds(
        checkpoint.dropWeapons,
        Object.keys(WEAPONS),
      );
      selectedDropRelics = validDropIds(
        checkpoint.dropRelics,
        RELICS.map((relic) => relic.id),
      );
      reset();
      player = checkpoint.player;
      for (const item of player.weaponInventory)
        markDiscovered("discoveredWeapons", item.id);
      for (const item of player.inventory)
        markDiscovered("discoveredRelics", item.id);
      if (!uncappedInventory) {
        player.inventory = player.inventory.slice(0, CONFIG.drops.maxRelics);
        player.weaponInventory = player.weaponInventory.slice(0, CONFIG.drops.maxWeapons);
      }
      normalizeUpgradeRanks(player);
      refreshRelicStats();
      selectedHero = player.hero;
      selectedWeapon = player.weapon;
      ui.heroSelect.value = selectedHero;
      ui.weaponSelect.value = selectedWeapon;
      ui.modeSelect.value = runMode;
      ui.difficultySelect.value = difficulty;
      if (singleWeaponToggle) singleWeaponToggle.checked = singleWeapon;
      if (uncappedInventoryToggle)
        uncappedInventoryToggle.checked = uncappedInventory;
      ui.customDrops.checked = Boolean(checkpoint.customDrops);
      for (const [id, input] of dropWeaponInputs)
        input.checked = selectedDropWeapons.includes(id);
      for (const [id, input] of dropRelicInputs)
        input.checked = selectedDropRelics.includes(id);
      defeated = checkpoint.defeated || 0;
      runChallenges = Array.isArray(checkpoint.runChallenges)
        ? checkpoint.runChallenges
        : null;
      runStarted = performance.now() - (checkpoint.elapsedSeconds || 0) * 1000;
      startWave(checkpoint.wave);
      setState(STATES.playing);
      last = performance.now();
      scheduleLoop();
      return;
    }
    runMode = ui.modeSelect.value;
    difficulty = ui.difficultySelect.value;
    singleWeapon = singleWeaponToggle?.checked ?? false;
    uncappedInventory = uncappedInventoryToggle?.checked ?? false;
    selectedDropWeapons = [...dropWeaponInputs]
      .filter(([, input]) => input.checked)
      .map(([id]) => id);
    selectedDropRelics = [...dropRelicInputs]
      .filter(([, input]) => input.checked)
      .map(([id]) => id);
    saveData.customDrops = ui.customDrops.checked;
    saveData.dropWeapons = selectedDropWeapons;
    saveData.dropRelics = selectedDropRelics;
    saveData.singleWeapon = singleWeapon;
    saveData.uncappedInventory = uncappedInventory;
    markDiscovered("discoveredWeapons", selectedWeapon);
    saveProgress();
    reset();
    runStarted = performance.now();
    startWave(1);
    setState(STATES.playing);
    last = runStarted;
    scheduleLoop();
  }

  ui.start.addEventListener("click", start);
  ui.shareRun.addEventListener("click", async () => {
    const url = new URL(window.location.href);
    for (const key of ["mode", "diff", "difficulty", "weapons", "relics", "uncapped", "singleWeapon", "customDrops"])
      url.searchParams.delete(key);
    url.searchParams.set("mode", ui.modeSelect.value);
    url.searchParams.set("diff", ui.difficultySelect.value);
    url.searchParams.set(
      "weapons",
      [...dropWeaponInputs].filter(([, input]) => input.checked).map(([id]) => id).join(","),
    );
    url.searchParams.set(
      "relics",
      [...dropRelicInputs].filter(([, input]) => input.checked).map(([id]) => id).join(","),
    );
    url.searchParams.set("uncapped", String(uncappedInventoryToggle?.checked ?? false));
    url.searchParams.set("singleWeapon", String(singleWeaponToggle?.checked ?? false));
    url.searchParams.set("customDrops", String(ui.customDrops.checked));
    ui.shareLink.value = url.href;
    ui.shareLink.closest("label").hidden = false;
    try {
      await navigator.clipboard.writeText(url.href);
      ui.saveText.textContent = "Lien copié dans le presse-papiers.";
    } catch {
      ui.shareLink.focus();
      ui.shareLink.select();
      ui.saveText.textContent = "Copie automatique indisponible : le lien est sélectionné, copiez-le.";
    }
  });
  ui.restartRun.addEventListener("click", () => {
    selectedHero = player.hero;
    selectedWeapon = player.weapon;
    saveData.hero = selectedHero;
    saveData.weapon = selectedWeapon;
    saveData.run = null;
    ui.heroSelect.value = selectedHero;
    ui.weaponSelect.value = selectedWeapon;
    ui.modeSelect.value = runMode;
    ui.difficultySelect.value = difficulty;
    if (uncappedInventoryToggle)
      uncappedInventoryToggle.checked = uncappedInventory;
    ui.customDrops.checked = Boolean(saveData.customDrops);
    for (const [id, input] of dropWeaponInputs)
      input.checked = selectedDropWeapons.includes(id);
    for (const [id, input] of dropRelicInputs)
      input.checked = selectedDropRelics.includes(id);
    saveProgress();
    reset();
    setState(STATES.title);
    draw();
  });
  ui.inventoryToggle.addEventListener("click", toggleInventory);
  ui.cheatToggle.addEventListener("click", () => {
    player.cheatInfiniteLife = !player.cheatInfiniteLife;
    ui.cheatToggle.setAttribute("aria-pressed", String(player.cheatInfiniteLife));
    ui.cheatToggle.textContent = `VIE INFINIE · ${player.cheatInfiniteLife ? "ON" : "OFF"}`;
    saveRunCheckpoint();
  });
  ui.relicList.addEventListener("change", (event) => {
    const relicId = event.target.dataset.relicLock;
    if (!relicId) return;
    event.target.focus();
    const relic = player.inventory.find((item) => item.id === relicId);
    if (!relic) return;
    relic.locked = event.target.checked;
    if (saveData.run) {
      const savedRelic = saveData.run.player.inventory.find(
        (item) => item.id === relicId,
      );
      if (savedRelic) savedRelic.locked = relic.locked;
      saveProgress();
    }
  });
  ui.weaponList.addEventListener("change", (event) => {
    const weaponId = event.target.dataset.weaponLock;
    if (!weaponId) return;
    event.target.focus();
    const weapon = player.weaponInventory.find((item) => item.id === weaponId);
    if (!weapon) return;
    weapon.locked = event.target.checked;
    if (saveData.run) {
      const savedWeapon = saveData.run.player.weaponInventory.find(
        (item) => item.id === weaponId,
      );
      if (savedWeapon) savedWeapon.locked = weapon.locked;
      saveProgress();
    }
  });
  ui.newRun.addEventListener("click", () => {
    const checkpoint = saveData.run;
    ui.modeSelect.value = saveData.run.mode;
    ui.difficultySelect.value = saveData.run.difficulty;
    if (uncappedInventoryToggle)
      uncappedInventoryToggle.checked = Boolean(saveData.run.uncappedInventory);
    uncappedInventory = Boolean(saveData.run.uncappedInventory);
    ui.customDrops.checked = Boolean(checkpoint.customDrops);
    selectedDropWeapons = validDropIds(
      checkpoint.dropWeapons,
      Object.keys(WEAPONS),
    );
    selectedDropRelics = validDropIds(
      checkpoint.dropRelics,
      RELICS.map((relic) => relic.id),
    );
    for (const [id, input] of dropWeaponInputs)
      input.checked = selectedDropWeapons.includes(id);
    for (const [id, input] of dropRelicInputs)
      input.checked = selectedDropRelics.includes(id);
    saveData.customDrops = ui.customDrops.checked;
    saveData.dropWeapons = selectedDropWeapons;
    saveData.dropRelics = selectedDropRelics;
    saveData.run = null;
    saveProgress();
    setState(STATES.title);
  });

  ui.returnMenu.addEventListener("click", () => {
    reset();
    setState(STATES.title);
    draw();
  });

  ui.resetSave.addEventListener("click", () => {
    if (
      !window.confirm(
        "Effacer la run en cours, les choix et options sauvegardés, les victoires et les éclats ?",
      )
    )
      return;
    try {
      localStorage.removeItem(SAVE_KEY);
    } catch {
      ui.saveText.textContent =
        "Le navigateur ne permet pas d’effacer les données locales.";
      return;
    }
    saveData = {
      wins: 0,
      bestKills: 0,
      shards: 0,
      hero: "pilgrim",
      weapon: "sabre",
      bestiary: {},
      discoveredWeapons: {},
      discoveredRelics: {},
      discoveredSynergies: {},
      muted: false,
      volume: 0.25,
      autoPickUpgrade: true,
      uncappedInventory: false,
    };
    selectedHero = "pilgrim";
    selectedWeapon = "sabre";
    ui.heroSelect.value = selectedHero;
    ui.weaponSelect.value = selectedWeapon;
    ui.modeSelect.value = "waves";
    ui.difficultySelect.value = "insane";
    if (singleWeaponToggle) singleWeaponToggle.checked = false;
    singleWeapon = false;
    if (uncappedInventoryToggle) uncappedInventoryToggle.checked = false;
    uncappedInventory = false;
    ui.customDrops.checked = false;
    ui.dropOptions.hidden = true;
    selectedDropWeapons = Object.keys(WEAPONS);
    selectedDropRelics = RELICS.map((relic) => relic.id);
    saveData.autoPickUpgrade = true;
    if (autoPickUpgradeToggle) autoPickUpgradeToggle.checked = true;
    for (const input of dropWeaponInputs.values()) input.checked = true;
    for (const input of dropRelicInputs.values()) input.checked = true;
    ui.mute.checked = false;
    ui.volume.value = ".25";
    showProgress();
    if (state === STATES.title) setState(STATES.title);
  });

  document.addEventListener("click", (event) => {
    if (event.target.closest("button")) sound(510, 0.035);
  });

  ui.heroSelect.value = selectedHero;
  ui.weaponSelect.value = selectedWeapon;
  if (singleWeaponToggle) singleWeaponToggle.checked = singleWeapon;
  if (uncappedInventoryToggle)
    uncappedInventoryToggle.checked = uncappedInventory;
  ui.customDrops.checked = Boolean(saveData.customDrops);
  ui.dropOptions.hidden = !ui.customDrops.checked;
  ui.weaponHelp.textContent = WEAPONS[selectedWeapon].description;
  ui.heroSelect.addEventListener("change", () => {
    selectedHero = ui.heroSelect.value;
    saveData.hero = selectedHero;
    saveProgress();
    const hero = HEROES[selectedHero];
    ui.heroName.textContent = hero.name.toUpperCase();
    ui.heroClass.textContent = hero.className;
    ui.specialName.textContent = hero.specialName;
  });

  ui.weaponSelect.addEventListener("change", () => {
    selectedWeapon = ui.weaponSelect.value;
    saveData.weapon = selectedWeapon;
    saveProgress();
    ui.weaponName.textContent = `Départ · ${WEAPONS[selectedWeapon].name}`;
    ui.weaponHelp.textContent = WEAPONS[selectedWeapon].description;
  });

  singleWeaponToggle?.addEventListener("change", () => {
    singleWeapon = singleWeaponToggle.checked;
    saveData.singleWeapon = singleWeapon;
    saveProgress();
  });
  uncappedInventoryToggle?.addEventListener("change", () => {
    uncappedInventory = uncappedInventoryToggle.checked;
    saveData.uncappedInventory = uncappedInventory;
    saveProgress();
  });

  ui.customDrops.addEventListener("change", () => {
    ui.dropOptions.hidden = !ui.customDrops.checked;
    saveData.customDrops = ui.customDrops.checked;
    saveProgress();
  });
  for (const input of [...dropWeaponInputs.values(), ...dropRelicInputs.values()])
    input.addEventListener("change", () => {
      saveData.dropWeapons = [...dropWeaponInputs]
        .filter(([, checkbox]) => checkbox.checked)
        .map(([id]) => id);
      saveData.dropRelics = [...dropRelicInputs]
        .filter(([, checkbox]) => checkbox.checked)
        .map(([id]) => id);
      saveProgress();
    });

  ui.mute.checked = !!saveData.muted;
  ui.volume.value = String(saveData.volume);
  if (autoPickUpgradeToggle)
    autoPickUpgradeToggle.checked = saveData.autoPickUpgrade;
  autoPickUpgradeToggle?.addEventListener("change", () => {
    saveData.autoPickUpgrade = autoPickUpgradeToggle.checked;
    saveProgress();
    scheduleAutoPickUpgrade();
  });
  ui.upgradeOptions.addEventListener("keydown", scheduleAutoPickUpgrade);
  ui.upgradeOptions.addEventListener("pointermove", scheduleAutoPickUpgrade);
  ui.mute.addEventListener("change", () => {
    saveData.muted = ui.mute.checked;
    saveProgress();
  });
  ui.volume.addEventListener("input", () => {
    saveData.volume = Number(ui.volume.value);
    saveProgress();
  });

  // Keyboard, pointer, and touch behavior lives in input.js.
  const input = createInputControls({
    canvas,
    ui,
    getState: () => state,
    setState,
    resumeRun,
    toggleInventory,
    attack,
    special,
    dodge,
    resetFrameClock: () => {
      last = performance.now();
    },
  });

  // Waves, enemy spawning, and world movement
  function saveRunCheckpoint(number = wave) {
    saveData.run = {
      version: 1,
      mode: runMode,
      difficulty,
      uncappedInventory,
      singleWeapon,
      customDrops: ui.customDrops.checked,
      dropWeapons: selectedDropWeapons,
      dropRelics: selectedDropRelics,
      wave: number,
      player: JSON.parse(JSON.stringify(player)),
      defeated,
      waveObjective: JSON.parse(JSON.stringify(waveObjective)),
      runChallenges: JSON.parse(JSON.stringify(runChallenges)),
      elapsedSeconds: Math.floor((performance.now() - runStarted) / 1000),
    };
    saveProgress();
  }

  function startWave(number) {
    wave = number;
    waveObjective = {
      type: ["kills", "xp", "elite"][(number - 1) % 3],
      target: [12, 8, 1][(number - 1) % 3],
      progress: 0,
      complete: false,
    };
    runChallenges ||= [
      { id: "kills", label: "Vaincre 50 créatures", target: 50, progress: 0, reward: "+1 éclat" },
      { id: "elites", label: "Vaincre 5 élites", target: 5, progress: 0, reward: "+1 éclat" },
      { id: "xp", label: "Ramasser 20 orbes d’XP", target: 20, progress: 0, reward: "+1 éclat" },
    ];
    const groups = groupsForWave(number);
    const eliteStride = runMode === "infinite" ? 18 : 24;
    pendingSpawns = groups.flatMap((group) =>
      Array.from({ length: group.count }, (_, index) => ({
        kind: group.kind,
        elite: group.kind !== "boss" && index % eliteStride === eliteStride - 1,
      })),
    );
    spawnClock = number === 1 ? CONFIG.enemies.firstSpawn : spawnDelay();
    swarmTimer = Math.random() < CONFIG.enemies.swarmChance
      ? rand(CONFIG.enemies.swarmMinDelay, CONFIG.enemies.swarmMaxDelay)
      : -1;
    intermission = 0;
    showNotice(
      `Vague ${number}${runMode === "infinite" && number % 5 === 0 ? " · Boss imminent" : ""}`,
    );
    saveRunCheckpoint(number);
    updateHud();
  }

  function beginIntermission() {
    intermission = CONFIG.enemies.intermission;
    saveRunCheckpoint(wave + 1);
  }

  function infiniteElapsedMinutes() {
    return Math.max(0, (performance.now() - runStarted) / 60000);
  }

  function spawnDelay() {
    return runMode === "infinite"
      ? Math.max(
          0.12,
          CONFIG.enemies.spawnDelay * Math.pow(0.7, infiniteElapsedMinutes()),
        )
      : CONFIG.enemies.spawnDelay;
  }

  function enemyWeight(entry) {
    const kind = typeof entry === "string" ? entry : entry.kind;
    const weight =
      kind === "boss" ? CONFIG.boss.weight : CONFIG.enemies[kind]?.weight;
    return (Number.isFinite(weight) && weight > 0 ? weight : 1) +
      (typeof entry === "object" && entry.elite ? 1 : 0);
  }

  function currentEnemyWeight() {
    return enemies.reduce(
      (total, enemy) =>
        total +
        (enemy.kind === "boss"
          ? BOSSES[enemy.bossId]?.weight || CONFIG.boss.weight
          : enemyWeight(enemy.kind)) + (enemy.eliteId ? 1 : 0),
      0,
    );
  }

  function maxSpawnWeight() {
    const initialWeight = CONFIG.enemies.maxAlive ?? 10;
    const capacity =
      runMode === "infinite"
        ? Math.min(
            CONFIG.enemies.infiniteMaxCapacity,
            initialWeight +
              Math.floor(
                infiniteElapsedMinutes() *
                  CONFIG.enemies.infiniteCapacityGrowthPerMinute,
              ),
          )
        : initialWeight;
    return capacity * DIFFICULTIES[difficulty].spawnCapacity;
  }

  function spawn(kind, bossId = "guardian", eliteId = null) {
    const boss = kind === "boss" ? BOSSES[bossId] || BOSSES.guardian : null;
    const elite = ELITE_AFFIXES[eliteId];
    const base = boss || CONFIG.enemies[kind],
      progress = Math.max(0, wave - 1),
      difficultyStats = DIFFICULTIES[difficulty],
      healthScale = runMode === "infinite" ? Math.pow(1.28, progress) : 1,
      damageScale = runMode === "infinite" ? Math.pow(1.22, progress) : 1,
      spec = {
        ...base,
        health: Math.round(base.health * healthScale * difficultyStats.health * (elite?.health || 1)),
        speed:
          base.speed *
          (runMode === "infinite" ? 1 + Math.min(1.2, progress * 0.035) : 1) *
          difficultyStats.speed * (elite?.speed || 1),
        damage: Math.round(
          (base.damage || 0) * damageScale * difficultyStats.damage * (elite?.damage || 1),
        ),
      };
    let x = player.x,
      y = player.y;
    for (let attempt = 0; attempt < 32; attempt++) {
      const angle = rand(0, Math.PI * 2),
        dx = Math.cos(angle),
        dy = Math.sin(angle);
      const edgeX =
        Math.abs(dx) < 0.001
          ? Infinity
          : (dx > 0 ? camera.x + VIEW_WIDTH - player.x : player.x - camera.x) /
            Math.abs(dx);
      const edgeY =
        Math.abs(dy) < 0.001
          ? Infinity
          : (dy > 0 ? camera.y + VIEW_HEIGHT - player.y : player.y - camera.y) /
            Math.abs(dy);
      const distance = Math.max(0, Math.min(edgeX, edgeY)) + rand(50, 120);
      x = clamp(
        player.x + dx * distance,
        CONFIG.enemies.edge,
        world.width - CONFIG.enemies.edge,
      );
      y = clamp(
        player.y + dy * distance,
        CONFIG.enemies.edge,
        world.height - CONFIG.enemies.edge,
      );
      const onScreen =
        x >= camera.x - 20 &&
        x <= camera.x + VIEW_WIDTH + 20 &&
        y >= camera.y - 20 &&
        y <= camera.y + VIEW_HEIGHT + 20;
      if (!onScreen && !isBlocked(x, y, spec.radius)) break;
    }
    if (
      (x >= camera.x - 20 &&
        x <= camera.x + VIEW_WIDTH + 20 &&
        y >= camera.y - 20 &&
        y <= camera.y + VIEW_HEIGHT + 20) ||
      isBlocked(x, y, spec.radius)
    ) {
      const candidates = [
        { x: camera.x - 80, y: rand(camera.y, camera.y + VIEW_HEIGHT) },
        {
          x: camera.x + VIEW_WIDTH + 80,
          y: rand(camera.y, camera.y + VIEW_HEIGHT),
        },
        { x: rand(camera.x, camera.x + VIEW_WIDTH), y: camera.y - 80 },
        {
          x: rand(camera.x, camera.x + VIEW_WIDTH),
          y: camera.y + VIEW_HEIGHT + 80,
        },
      ].map((point) => ({
        x: clamp(
          point.x,
          CONFIG.enemies.edge,
          world.width - CONFIG.enemies.edge,
        ),
        y: clamp(
          point.y,
          CONFIG.enemies.edge,
          world.height - CONFIG.enemies.edge,
        ),
      }));
      const outside = candidates.find(
        (point) =>
          !(
            point.x >= camera.x - 20 &&
            point.x <= camera.x + VIEW_WIDTH + 20 &&
            point.y >= camera.y - 20 &&
            point.y <= camera.y + VIEW_HEIGHT + 20
          ) && !isBlocked(point.x, point.y, spec.radius),
      );
      if (outside) {
        x = outside.x;
        y = outside.y;
      }
    }
    if (!Number.isFinite(x) || !Number.isFinite(y)) {
      console.error("[apparition ennemi invalide]", { kind, x, y, player, camera });
      return;
    }
    enemies.push({
      x,
      y,
      hp: spec.health,
      maxHp: spec.health,
      speed: spec.speed,
      r: spec.radius,
      damage: spec.damage || 0,
      slamDamage:
        kind === "boss"
          ? Math.round(
              base.slamDamage * damageScale * difficultyStats.damage,
            )
          : 0,
      chargeDamage:
        kind === "boss"
          ? Math.round(
              base.chargeDamage * damageScale * difficultyStats.damage,
            )
          : 0,
      projectileDamage:
        kind === "boss"
          ? Math.round(
              (base.projectileDamage || 0) * damageScale * difficultyStats.damage,
            )
          : 0,
      healOnHit: spec.healOnHit || 0,
      bossId: kind === "boss" ? bossId : null,
      bossName: kind === "boss" ? base.name : null,
      bossBehavior: kind === "boss" ? base.behavior : null,
      kind,
      eliteId: elite ? eliteId : null,
      eliteName: elite?.name || null,
      eliteColor: elite?.color || null,
      hit: 0,
      attack:
        kind === "caster"
          ? rand(1, 1.8)
          : kind === "boss"
            ? 1.4
            : rand(
                CONFIG.enemies.firstAttackMin,
                CONFIG.enemies.firstAttackMax,
              ),
      attackMode: kind === "boss" && boss?.behavior === "volley" ? "volley" : "slam",
      telegraph: 0,
      dashTelegraph: kind === "boss" ? 0 : undefined,
      dashCooldown: kind === "boss" ? rand(0.8, 2) : undefined,
      dash: null,
      aimX: 0,
      aimY: 0,
      phase: rand(0, 6),
    });
  }

  function isBlocked(x, y, radius) {
    return (
      x < CONFIG.enemies.edge + radius ||
      x > world.width - CONFIG.enemies.edge - radius ||
      y < CONFIG.enemies.edge + radius ||
      y > world.height - CONFIG.enemies.edge - radius
    );
  }

  function movePlayer(dx, dy) {
    const x = clamp(
        player.x + dx,
        CONFIG.arena.edge,
        world.width - CONFIG.arena.edge,
      ),
      y = clamp(
        player.y + dy,
        CONFIG.arena.edge,
        world.height - CONFIG.arena.edge,
      );
    if (!isBlocked(x, player.y, 11)) player.x = x;
    if (!isBlocked(player.x, y, 11)) player.y = y;
  }

  function moveEnemy(enemy, dx, dy) {
    if (!Number.isFinite(dx) || !Number.isFinite(dy)) return false;
    const angle = Math.atan2(dy, dx),
      distance = Math.hypot(dx, dy),
      side =
        enemy.avoidSide || (enemy.avoidSide = Math.random() < 0.5 ? -1 : 1),
      tryStep = (offset) => {
        const a = angle + offset,
          x = clamp(
            enemy.x + Math.cos(a) * distance,
            CONFIG.enemies.edge,
            world.width - CONFIG.enemies.edge,
          ),
          y = clamp(
            enemy.y + Math.sin(a) * distance,
            CONFIG.enemies.edge,
            world.height - CONFIG.enemies.edge,
          );
        if (!Number.isFinite(x) || !Number.isFinite(y)) {
          console.error("[mouvement ennemi invalide]", {
            kind: enemy.kind,
            position: { x: enemy.x, y: enemy.y },
            movement: { dx, dy },
            speed: enemy.speed,
          });
          return false;
        }
        if (isBlocked(x, y, enemy.r)) return false;
        enemy.x = x;
        enemy.y = y;
        return true;
      };
    if (tryStep(0)) return;
    for (const offset of [
      0.38 * side,
      -0.38 * side,
      0.78 * side,
      -0.78 * side,
      1.2 * side,
      -1.2 * side,
      1.62 * side,
      -1.62 * side,
      2.2 * side,
      -2.2 * side,
      Math.PI,
    ])
      if (tryStep(offset)) return;
  }

  function separateEnemyCrowds(dt) {
    if (enemies.length < 2) return;

    const cellSize = 96,
      columns = Math.ceil(world.width / cellSize) + 1,
      rows = Math.ceil(world.height / cellSize) + 1,
      buckets = new Map(),
      pushX = new Float32Array(enemies.length),
      pushY = new Float32Array(enemies.length);
    for (let i = 0; i < enemies.length; i++) {
      const enemy = enemies[i],
        cellX = Math.floor(enemy.x / cellSize),
        cellY = Math.floor(enemy.y / cellSize),
        key = cellY * columns + cellX;
      let bucket = buckets.get(key);
      if (!bucket) buckets.set(key, (bucket = []));
      bucket.push(i);
    }

    const correctionFactor = dt * 3;
    for (let i = 0; i < enemies.length; i++) {
      const enemy = enemies[i],
        cellX = Math.floor(enemy.x / cellSize),
        cellY = Math.floor(enemy.y / cellSize);
      for (let offsetY = -1; offsetY <= 1; offsetY++) {
        for (let offsetX = -1; offsetX <= 1; offsetX++) {
          const neighborX = cellX + offsetX,
            neighborY = cellY + offsetY;
          if (
            neighborX < 0 ||
            neighborX >= columns ||
            neighborY < 0 ||
            neighborY >= rows
          )
            continue;
          const bucket = buckets.get(neighborY * columns + neighborX);
          if (!bucket) continue;
          const samples = Math.min(bucket.length, 8),
            start =
              ((i * 17 + neighborX * 13 + neighborY * 7) % bucket.length +
                bucket.length) %
              bucket.length;
          for (let sample = 0; sample < samples; sample++) {
            const otherIndex =
              bucket[
                (start + Math.floor((sample * bucket.length) / samples)) %
                  bucket.length
              ];
            if (otherIndex <= i) continue;
            const other = enemies[otherIndex],
              dx = enemy.x - other.x,
              dy = enemy.y - other.y,
              minimumDistance = enemy.r + other.r,
              distanceSquared = dx * dx + dy * dy;
            if (distanceSquared >= minimumDistance * minimumDistance) continue;

            const distance = Math.sqrt(distanceSquared);
            let normalX, normalY;
            if (distance > 0) {
              normalX = dx / distance;
              normalY = dy / distance;
            } else {
              const direction = (i * 31 + otherIndex * 17) % 4;
              normalX = direction < 2 ? (direction ? -1 : 1) : 0;
              normalY = direction < 2 ? 0 : direction === 2 ? 1 : -1;
            }
            const amount =
                ((minimumDistance - distance) * correctionFactor) / 2,
              x = normalX * amount,
              y = normalY * amount;
            pushX[i] += x;
            pushY[i] += y;
            pushX[otherIndex] -= x;
            pushY[otherIndex] -= y;
          }
        }
      }
    }

    const maxCorrection = dt * 28;
    for (let i = 0; i < enemies.length; i++) {
      const enemy = enemies[i],
        length = Math.hypot(pushX[i], pushY[i]);
      if (!length) continue;
      const scale = Math.min(1, maxCorrection / length);
      enemy.x = clamp(
        enemy.x + pushX[i] * scale,
        CONFIG.enemies.edge + enemy.r,
        world.width - CONFIG.enemies.edge - enemy.r,
      );
      enemy.y = clamp(
        enemy.y + pushY[i] * scale,
        CONFIG.enemies.edge + enemy.r,
        world.height - CONFIG.enemies.edge - enemy.r,
      );
    }
  }

  function updateWaves(dt) {
    if (intermission > 0) {
      intermission -= dt;
      if (intermission <= 0 && (runMode === "infinite" || wave < WAVES.length))
        startWave(wave + 1);
      updateHud();
      return;
    }
    if (swarmTimer > 0) {
      swarmTimer -= dt;
      if (swarmTimer <= 0) {
        const kinds = groupsForWave(wave),
          count = Math.min(
            CONFIG.enemies.swarmMaxCount,
            CONFIG.enemies.swarmBaseCount +
              Math.min(wave, 18) * CONFIG.enemies.swarmCountPerWave,
          ),
          swarm = Array.from({ length: count }, () => ({
            kind: chooseSwarmKind(kinds),
            elite: false,
            swarm: true,
          }));
        pendingSpawns.unshift(...swarm);
        spawnClock = 0;
        swarmTimer = -1;
        showNotice(`ESSAIM · ${count} créatures arrivent`);
      }
    }
    if (pendingSpawns.length) {
      spawnClock -= dt;
      const occupiedWeight = currentEnemyWeight(),
        capacity = maxSpawnWeight();
      const spawnIndex = pendingSpawns.findIndex(
        (entry) => occupiedWeight + enemyWeight(entry) <= capacity,
      );
      if (spawnClock <= 0 && spawnIndex >= 0) {
        const entry = pendingSpawns.splice(spawnIndex, 1)[0];
        const eliteIds = Object.keys(ELITE_AFFIXES);
        spawn(entry.kind, "guardian", entry.elite ? eliteIds[Math.floor(Math.random() * eliteIds.length)] : null);
        spawnClock = entry.swarm
          ? CONFIG.enemies.swarmSpawnDelay
          : spawnDelay();
      }
      return;
    }
    if (enemies.length === 0) {
      if (runMode === "infinite" && wave % 5 === 0 && !bossActive) {
        const bossIds = Object.keys(BOSSES);
        const bossIndex = (Math.floor(wave / 5) - 1) % bossIds.length;
        spawnBoss(bossIds[bossIndex]);
      } else if (wave < WAVES.length || runMode === "infinite")
        beginIntermission();
      else if (!bossActive) spawnBoss();
      updateHud();
    }
  }

  function groupsForWave(number) {
    if (runMode === "infinite" && number > WAVES.length)
      return [
        { kind: "ghoul", count: 35 + number * 6 },
        { kind: "brute", count: 12 + number * 3 },
        { kind: "caster", count: Math.min(2 + Math.floor(number / 2), 9) },
        { kind: "stalker", count: Math.min(4 + number, 15) },
        { kind: "charger", count: Math.min(2 + number, 12) },
        { kind: "shaman", count: Math.min(1 + Math.floor(number / 2), 7) },
        { kind: "leech", count: Math.min(4 + number * 2, 32) },
        { kind: "leaper", count: Math.min(3 + number, 18) },
      ];
    return WAVES[number - 1] || WAVES[WAVES.length - 1];
  }

  function chooseSwarmKind(groups) {
    const total = groups.reduce((sum, group) => sum + Math.min(group.count, 12), 0);
    let pick = Math.random() * total;
    for (const group of groups) {
      pick -= Math.min(group.count, 12);
      if (pick < 0) return group.kind;
    }
    return "ghoul";
  }

  function spawnBoss(
    bossId = Object.keys(BOSSES)[
      Math.floor(Math.random() * Object.keys(BOSSES).length)
    ],
  ) {
    bossActive = true;
    spawn("boss", bossId);
    showNotice(`${BOSSES[bossId]?.name || BOSSES.guardian.name} approche`);
    updateHud();
  }

  // Leveling, upgrades, and equipment
  function damageEnemy(enemy, amount, weaponId = null) {
    if (enemy.sabreMark) {
      amount *= 1.5;
      enemy.sabreMark = false;
    }
    amount = Math.round(
      amount * player.damageMultiplier * levelDamageMultiplier() * player.equipmentDamage,
    );
    const dealt = Math.min(amount, Math.max(0, enemy.hp));
    enemy.hp -= amount;
    if (player.equipmentLifesteal > 0 && dealt > 0)
      player.hp = Math.min(
        player.maxHp,
        player.hp + dealt * player.equipmentLifesteal,
      );
    enemy.hit = CONFIG.combat.enemyHitFlash;
    damageNumbers.push({
      x: enemy.x,
      y: enemy.y - 22,
      text: String(amount),
      life: 0.65,
      maxLife: 0.65,
    });
    if (enemy.hp <= 0) kill(enemy, weaponId);
  }

  function hasActiveSynergy(id) {
    return getActiveSynergies(player).some((synergy) => synergy.id === id);
  }

  function gainXp(amount) {
    player.xp += amount;
    const previousMaxHp = player.maxHp;
    let leveledUp = false;
    while (player.xp >= player.nextXp) {
      player.xp -= player.nextXp;
      player.level++;
      player.nextXp += CONFIG.player.xpPerLevel;
      player.pendingUpgrades++;
      leveledUp = true;
    }
    if (leveledUp) {
      refreshRelicStats();
      player.hp = Math.min(player.maxHp, player.hp + player.maxHp - previousMaxHp);
    }
    updateHud();
    if (player.pendingUpgrades && state === STATES.playing) showLevelUp();
  }

  function progressObjective(type) {
    let completedChallenge = false;
    if (waveObjective?.type === type && !waveObjective.complete) {
      waveObjective.progress = Math.min(waveObjective.target, waveObjective.progress + 1);
      if (waveObjective.progress >= waveObjective.target) {
        waveObjective.complete = true;
        player.hp = Math.min(player.maxHp, player.hp + Math.ceil(player.maxHp * 0.18));
        sound(720, 0.16, "sine");
        showNotice("Objectif accompli · +18 % PV");
      }
    }
    for (const challenge of runChallenges || []) {
      if (challenge.id !== type || challenge.complete) continue;
      challenge.progress = Math.min(challenge.target, challenge.progress + 1);
      if (challenge.progress >= challenge.target) {
        challenge.complete = true;
        completedChallenge = true;
        saveData.shards = (saveData.shards || 0) + 1;
        showNotice(`Défi accompli · ${challenge.reward}`);
      }
    }
    if (saveData.run) {
      saveData.run.runChallenges = JSON.parse(JSON.stringify(runChallenges));
      saveData.run.waveObjective = JSON.parse(JSON.stringify(waveObjective));
    }
    if (completedChallenge || (type === "kills" && defeated % 10 === 0))
      saveProgress();
    updateHud();
  }

  function recordBestiary(enemy) {
    const key = enemy.kind === "boss" ? `boss:${enemy.bossId}` : enemy.kind;
    const entry = (saveData.bestiary[key] ||= { kills: 0, discovered: true });
    let wasNew = entry.kills === 0;
    entry.kills = (entry.kills || 0) + 1;
    if (enemy.eliteId) {
      const eliteEntry = (saveData.bestiary[`elite:${enemy.eliteId}`] ||= { kills: 0, discovered: true });
      if (eliteEntry.kills === 0) wasNew = true;
      eliteEntry.kills++;
    }
    return wasNew;
  }

  function discoverEnemy(enemy) {
    const key = enemy.kind === "boss" ? `boss:${enemy.bossId}` : enemy.kind;
    if (
      saveData.bestiary[key]?.discovered &&
      (!enemy.eliteId || saveData.bestiary[`elite:${enemy.eliteId}`]?.discovered)
    )
      return;
    let changed = false;
    for (const id of [key, ...(enemy.eliteId ? [`elite:${enemy.eliteId}`] : [])]) {
      const entry = saveData.bestiary[id] || { kills: 0 };
      if (!entry.discovered) {
        entry.discovered = true;
        saveData.bestiary[id] = entry;
        changed = true;
      }
    }
    if (changed) saveProgress();
  }

  function dropXp(x, y, amountMultiplier = 1) {
    spawnDrop(x, y, {
      type: "xp",
      amount: player.equipmentXp * amountMultiplier,
      life: CONFIG.drops.lifetime,
    });
  }

  function spawnDrop(x, y, drop) {
    const angle = rand(0, Math.PI * 2),
      distance = rand(12, 30);
    drops.push({
      ...drop,
      x: clamp(x + Math.cos(angle) * distance, 12, world.width - 12),
      y: clamp(y + Math.sin(angle) * distance, 12, world.height - 12),
    });
  }

  function showLevelUp() {
    sound(460, 0.12, "sine");
    setState(STATES.levelUp);
    const options = UPGRADES.filter(
      (upgrade) => player.upgradeRanks[upgrade.id] < upgrade.maxRanks,
    );
    if (!options.length) {
      player.pendingUpgrades = 0;
      resumeRun();
      return;
    }
    for (let i = options.length - 1; i > 0; i--) {
      const j = Math.floor(Math.random() * (i + 1));
      [options[i], options[j]] = [options[j], options[i]];
    }
    ui.upgradeOptions.replaceChildren(
      ...options
        .slice(0, 3)
        .map((upgrade) =>
          createChoiceCard(
            upgrade.name,
            `${upgrade.description} · prochain rang : +${formatUpgradeBonus(upgrade, player.upgradeRanks[upgrade.id])} (${player.upgradeRanks[upgrade.id]}/${upgrade.maxRanks})`,
            () => chooseUpgrade(upgrade),
          ),
        ),
    );
    ui.upgradeOptions.querySelector("button")?.focus();
  }

  function formatUpgradeBonus(upgrade, rank) {
    const value = upgrade.bonus / (rank + 1);
    if (upgrade.kind === "range") return `${Number(value.toFixed(1))} portée`;
    if (upgrade.kind === "health") return `${Math.round(value)} PV max`;
    if (upgrade.kind === "defense")
      return `${Number((value * 100).toFixed(1))} % défense`;
    if (upgrade.kind === "pickup")
      return `${Math.round(value * 100)} % ramassage`;
    return `${Math.round(value * 100)} %`;
  }

  function chooseUpgrade(upgrade) {
    const rank = player.upgradeRanks[upgrade.id];
    upgrade.apply(player, upgrade.bonus / (rank + 1));
    player.upgradeRanks[upgrade.id]++;
    player.pendingUpgrades--;
    updateHud();
    if (player.pendingUpgrades) {
      showLevelUp();
      return;
    }
    resumeRun();
  }

  function resumeRun() {
    pendingLoot = null;
    setState(STATES.playing);
    last = performance.now();
    scheduleLoop();
  }

  function refreshRelicStats() {
    player.equipmentDamage = 1;
    player.equipmentSpeed = 1;
    player.equipmentRange = 0;
    player.equipmentDefense = 0;
    player.equipmentXp = 1;
    player.equipmentLifesteal = 0;
    player.equipmentHealth = 0;
    player.pickupRange =
      CONFIG.drops.pickupRange * player.pickupRangeMultiplier;
    for (const item of player.inventory) {
      const level = item.level || 1,
        value = item.value * level;
      if (item.effect === "damage") player.equipmentDamage += value;
      if (item.effect === "speed")
        player.equipmentSpeed *= 1 + (item.value - 1) * level;
      if (item.effect === "range") player.equipmentRange += value;
      if (item.effect === "defense")
        player.equipmentDefense = Math.min(
          0.65,
          player.equipmentDefense + value,
        );
      if (item.effect === "experience")
        player.equipmentXp *= 1 + (item.value - 1) * level;
      if (item.effect === "lifesteal")
        player.equipmentLifesteal += item.value * level;
      if (item.effect === "health") player.equipmentHealth += value;
      if (item.effect === "pickup")
        player.pickupRange *= 1 + (item.value - 1) * level;
    }
    player.maxHp =
      HEROES[player.hero].health * levelHealthMultiplier() +
      player.equipmentHealth +
      (player.bonusMaxHp || 0);
    player.hp = Math.min(player.hp, player.maxHp);
  }

  function levelHealthMultiplier() {
    return 1 + (player.level - 1) * CONFIG.player.levelHealthBonus;
  }

  function levelDamageMultiplier() {
    return 1 + (player.level - 1) * CONFIG.player.levelDamageBonus;
  }

  function equipRelic(relic, index = -1) {
    if (index < 0) player.inventory.push(relic);
    else player.inventory[index] = relic;
    markDiscovered("discoveredRelics", relic.id);
    refreshRelicStats();
    updateHud();
  }

  function relicComboDescription(relicId) {
    const synergy = SYNERGIES.find((item) => item.relicId === relicId);
    return synergy
      ? `Combo avec ${WEAPONS[synergy.weaponId].name} : ${synergy.description}`
      : "Aucun combo d’arme associé";
  }

  function weaponComboDescription(weaponId) {
    const synergy = SYNERGIES.find((item) => item.weaponId === weaponId);
    return synergy
      ? `Combo avec ${RELICS.find((item) => item.id === synergy.relicId).name} : ${synergy.description}`
      : "Aucun combo de relique associé";
  }

  function pickRelic(id) {
    const relic = RELICS.find((item) => item.id === id);
    if (!relic) return;
    const activeSynergiesBefore = new Set(
      getActiveSynergies(player).map((synergy) => synergy.id),
    );
    const found = player.inventory.find((item) => item.id === id);
    if (found) {
      if (found.level >= 5) {
        showNotice(`${relic.name} niveau maximum`);
        return;
      }
      found.level++;
      refreshRelicStats();
      updateHud();
      showNotice(`${relic.name} · niveau ${found.level}`);
      announceNewSynergies(activeSynergiesBefore);
      return;
    }
    if (uncappedInventory || player.inventory.length < CONFIG.drops.maxRelics) {
      equipRelic({
        ...relic,
        level: 1,
      });
      showNotice(`${relic.name} équipée · niveau 1`);
      return;
    }
    const replaceableRelics = player.inventory
      .map((item, index) => ({ item, index }))
      .filter(({ item }) => !item.locked);
    if (!replaceableRelics.length) {
      showNotice("Sacoche pleine · toutes les reliques sont verrouillées");
      return;
    }
    pendingLoot = relic;
    setState(
      STATES.loot,
      `${relic.name} : ${relic.description}. ${relicComboDescription(relic.id)}. Choisissez la relique à remplacer, ou gardez votre équipement actuel.`,
    );
    ui.upgradeOptions.replaceChildren(
      ...replaceableRelics.map(({ item, index }) =>
        createChoiceCard(
          `Remplacer ${item.name} niv. ${item.level || 1}`,
          `Perdue : ${item.description}. ${relicComboDescription(item.id)}.`,
          () => {
            equipRelic(
              {
                ...relic,
                level: 1,
              },
              index,
            );
            resumeRun();
          },
          [
            { folder: "relics", id: relic.id },
            { folder: "relics", id: item.id },
          ],
        ),
      ),
      createChoiceCard(
        "Passer cette relique",
        "La relique ne rejoint pas la sacoche.",
        resumeRun,
        [{ folder: "relics", id: relic.id }],
      ),
    );
    ui.upgradeOptions.querySelector("button")?.focus();
  }

  function pickWeapon(weaponId) {
    const weapon = WEAPONS[weaponId];
    if (!weapon) return;
    const activeSynergiesBefore = new Set(
      getActiveSynergies(player).map((synergy) => synergy.id),
    );
    const owned = player.weaponInventory.find((item) => item.id === weaponId);
    if (
      !owned &&
      !uncappedInventory &&
      player.weaponInventory.length >= CONFIG.drops.maxWeapons
    ) {
      const replaceableWeapons = player.weaponInventory
        .map((item, index) => ({ item, index }))
        .filter(({ item }) => !item.locked);
      if (!replaceableWeapons.length) {
        showNotice("Arsenal plein · toutes les armes sont verrouillées");
        return;
      }
      pendingLoot = { type: "weapon", id: weaponId };
      setState(
        STATES.loot,
        `${weapon.name} : ${weapon.description}. ${weaponComboDescription(weaponId)}. Choisissez l’arme à remplacer, ou gardez votre arsenal actuel.`,
      );
      showWeaponLootPreview(weaponId);
      ui.upgradeOptions.replaceChildren(
        ...replaceableWeapons.map(({ item, index }) =>
          createChoiceCard(
            `Remplacer ${WEAPONS[item.id].name} niv. ${item.level}`,
            `Retirée : ${WEAPONS[item.id].description}. ${weaponComboDescription(item.id)}`,
            () => {
              player.weaponInventory[index] = {
                id: weaponId,
                level: 1,
                special: false,
              };
              markDiscovered("discoveredWeapons", weaponId);
              if (player.weapon === item.id) player.weapon = weaponId;
              updateHud();
              showNotice(`${weapon.name} remplace ${WEAPONS[item.id].name}`);
              announceNewSynergies(activeSynergiesBefore);
              resumeRun();
            },
            [{ folder: "weapons", id: item.id }],
          ),
        ),
        createChoiceCard(
          "Passer cette arme",
          "L’arme ne rejoint pas l’arsenal.",
          resumeRun,
          [{ folder: "weapons", id: weaponId }],
        ),
      );
      ui.upgradeOptions.querySelector("button")?.focus();
      return;
    }
    const result = upgradeWeapon(player, weaponId);
    if (result.kind !== "maximum") markDiscovered("discoveredWeapons", weaponId);

    const weaponName = weapon.name;

    const messages = {
      collected: `${weaponName} ajoutée à l’arsenal · niveau 1`,
      level: `${weaponName} · niveau ${result.level}`,
      special: `${weaponName} spéciale obtenue !`,
      maximum: "Cette arme est déjà au maximum",
    };

    showNotice(messages[result.kind]);
    announceNewSynergies(activeSynergiesBefore);

    updateHud();
  }

  function showWeaponLootPreview(weaponId) {
    const weapon = WEAPONS[weaponId];
    const icon = document.createElement("img");
    icon.src = `assets/weapons/${weaponId}.svg`;
    icon.alt = "";
    const label = document.createElement("strong");
    label.textContent = weapon.name;
    const combo = SYNERGIES.find((item) => item.weaponId === weaponId);
    const relic = combo && player.inventory.find((item) => item.id === combo.relicId);
    const detail = document.createElement("small");
    detail.textContent =
      combo && relic && saveData.discoveredSynergies[combo.id]
        ? `Combo connu avec ${relic.name} : ${combo.description} (arme spéciale niv. ${SYNERGY_REQUIREMENTS.weaponLevel} + relique niv. ${SYNERGY_REQUIREMENTS.relicLevel}).`
        : "Aucun combo déjà découvert avec les reliques portées.";
    ui.lootPreview.replaceChildren(icon, label, detail);
    ui.lootPreview.hidden = false;
  }

  function announceNewSynergies(previousIds) {
    const unlocked = getActiveSynergies(player).filter(
      (synergy) => !previousIds.has(synergy.id),
    );
    if (unlocked.length)
      showNotice(`Synergie activée · ${unlocked[0].name}${unlocked.length > 1 ? ` · +${unlocked.length - 1}` : ""}`);
  }

  // Combat and enemy interactions
  function finishRun(result) {
    runSeconds = Math.max(
      0,
      Math.floor((performance.now() - runStarted) / 1000),
    );
    saveData.bestKills = Math.max(saveData.bestKills || 0, defeated);
    if (result === "victory") {
      saveData.wins = (saveData.wins || 0) + 1;
      saveData.shards = (saveData.shards || 0) + 1;
    }
    saveData.run = null;
    saveProgress();
    showProgress();
    const time = `${Math.floor(runSeconds / 60)} min ${String(runSeconds % 60).padStart(2, "0")} s`;
    const copy = `Durée : ${time} · Vague atteinte : ${wave}/${WAVES.length} · Créatures vaincues : ${defeated} · Niveau : ${player.level} · Boss : ${result === "victory" ? "vaincu" : "non vaincu"} · Reliques : ${player.inventory.length}${result === "victory" ? " · Récompense : 1 Éclat du Gardien" : ""}.`;
    setState(result === "victory" ? STATES.victory : STATES.defeat, copy);
  }

  function damagePlayer(amount, source = "source inconnue", attacker = null) {
    if (state !== STATES.playing || player.invuln > 0 || player.cheatInfiniteLife)
      return false;
    sound(90, 0.11, "square");
    const hpBefore = player.hp,
      actualDamage =
        amount * (1 - Math.min(0.8, player.equipmentDefense + player.levelDefense)),
      absorbedDamage = Math.min(player.shield || 0, actualDamage);
    player.shield = Math.max(0, (player.shield || 0) - absorbedDamage);
    player.hp = Math.max(
      0,
      player.hp - actualDamage + absorbedDamage,
    );
    console.info("[dégâts joueur]", {
      source,
      attackerPosition: attacker
        ? {
            x: Math.round(attacker.x),
            y: Math.round(attacker.y),
            screenX: Math.round(attacker.x - camera.x),
            screenY: Math.round(attacker.y - camera.y),
          }
        : null,
      damage: Number((hpBefore - player.hp).toFixed(2)),
      shieldAbsorbed: Number(absorbedDamage.toFixed(2)),
      rawDamage: amount,
      hpBefore,
      hpAfter: player.hp,
      wave,
      difficulty,
      mode: runMode,
      position: { x: Math.round(player.x), y: Math.round(player.y) },
      time: Number(((performance.now() - runStarted) / 1000).toFixed(2)),
    });
    player.invuln = CONFIG.combat.playerInvulnerability;
    burst(player.x, player.y, "#bb493c", 4);
    if (player.hp === 0) finishRun("defeat");
    return true;
  }

  function dodge() {
    if (state !== STATES.playing || player.dodgeCooldown > 0) return;
    let x =
        (input.keys.has("d") || input.keys.has("arrowright") ? 1 : 0) -
        (input.keys.has("a") || input.keys.has("arrowleft") ? 1 : 0),
      y =
        (input.keys.has("s") || input.keys.has("arrowdown") ? 1 : 0) -
        (input.keys.has("w") || input.keys.has("arrowup") ? 1 : 0),
      length = Math.hypot(x, y);
    if (length) {
      player.dodgeX = x / length;
      player.dodgeY = y / length;
    } else {
      player.dodgeX = player.faceX;
      player.dodgeY = player.faceY;
    }
    player.dodgeTime = CONFIG.combat.dodgeDuration;
    player.dodgeCooldown = CONFIG.combat.dodgeCooldown;
    player.invuln = Math.max(player.invuln, CONFIG.combat.dodgeInvulnerability);
    burst(player.x, player.y, "#d9c18a", 8);
    updateHud();
  }

  function attack(manual = false) {
    if (state !== STATES.playing) return;
    for (const item of player.weaponInventory) {
      if ((player.weaponCooldowns[item.id] || 0) <= 0)
        attackWeapon(item.id, manual);
    }
  }

  function launchArcVolley(shot) {
    discoverSynergy("arc-quiver");
    const baseAngle = Math.atan2(shot.vy, shot.vx),
      speed = Math.hypot(shot.vx, shot.vy);
    for (const [offset, damage] of [[-0.2, 0.72], [0, 1], [0.2, 0.72]]) {
      const angle = baseAngle + offset;
      projectiles.push({
        ...shot,
        vx: Math.cos(angle) * speed,
        vy: Math.sin(angle) * speed,
        damage: shot.damage * damage,
        hitTargets: [],
      });
    }
  }

  function attackWeapon(weaponId, manual = false) {
    if (state !== STATES.playing) return;
    const weapon = WEAPONS[weaponId],
      weaponStats = getWeaponCombatStats(player, weaponId, weapon),
      progression = getWeaponProgress(player, weaponId),
      hasSpecial = progression.special,
      weaponDamage = weaponStats.damageMultiplier,
      attackSpeed =
        weapon.speed *
        player.attackSpeedMultiplier *
        weaponStats.attackSpeedMultiplier;
    player.weaponSwingCount ||= {};
    player.weaponSwingCount[weaponId] =
      (player.weaponSwingCount[weaponId] || 0) + 1;
    const swing = player.weaponSwingCount[weaponId];
    let target = null;
    let nearestDistanceSquared = Infinity;
    for (const enemy of enemies) {
      const dx = enemy.x - player.x;
      const dy = enemy.y - player.y;
      const distanceSquared = dx * dx + dy * dy;
      if (distanceSquared < nearestDistanceSquared) {
        target = enemy;
        nearestDistanceSquared = distanceSquared;
      }
    }
    if (weapon.ranged) {
      if (!target) return;
      const distance = Math.hypot(target.x - player.x, target.y - player.y);
      if (distance > weaponStats.range)
        return;
      const dx = target.x - player.x,
        dy = target.y - player.y,
        d = Math.hypot(dx, dy) || 1;
      player.faceX = dx / d;
      player.faceY = dy / d;
      player.weaponCooldowns[weaponId] =
        CONFIG.combat.basicDuration / attackSpeed;
      player.weaponAttackTimers[weaponId] =
        CONFIG.combat.basicDuration / attackSpeed;
      const chargingSpecial =
        hasSpecial && ["arc", "foudre"].includes(weaponId);
      const arcCombo =
        weaponId === "arc" && hasActiveSynergy("arc-quiver");
      if (!chargingSpecial) sound(510, 0.055, "triangle");
      const shot = {
        team: "player",
        weaponId,
        x: player.x + player.faceX * 14,
        y: player.y + player.faceY * 14,
        vx: player.faceX * 520 * player.projectileSpeed,
        vy: player.faceY * 520 * player.projectileSpeed,
        damage:
          (target.kind === "brute" ? weapon.bruteDamage : weapon.ghoulDamage) *
          weaponDamage,
        radius: 5 * player.projectileSize,
        life: Infinity,
        color: weapon.lightning
          ? "#c7a8ff"
          : weapon.frost
            ? "#91e9ef"
          : weapon.explosive
            ? "#ff9a4e"
          : hasSpecial
            ? "#ffe39a"
            : "#85d8ce",
        explosive: !!weapon.explosive,
        explosionRadius: weapon.explosive
          ? (44 + (progression.level - 1) * 9) * (hasSpecial ? 1.35 : 1)
          : 0,
        specialBlast: hasSpecial && !!weapon.explosive,
        lightning: !!weapon.lightning,
        frost: !!weapon.frost,
        slowDuration: weapon.frost
          ? (hasSpecial ? 2.4 : 1.25) * weaponStats.slowDurationMultiplier
          : 0,
        slowFactor: hasSpecial ? 0.42 : 0.58,
        chainTargets:
          weaponStats.chainTargets + (hasSpecial && weapon.lightning ? 1 : 0),
        chainRange:
          190 * (weaponId === "foudre" && hasActiveSynergy("foudre-relic") ? 2 : 1),
        stormSpecial: hasSpecial && weapon.lightning,
        piercing: hasSpecial && weaponId === "arc",
        hitTargets: [],
      };
      if (chargingSpecial)
        weaponEffects.push({
          kind: weaponId === "arc" ? "arcCharge" : "lightningCharge",
          delay: 0.14,
          shot,
          fan: arcCombo,
          angle: Math.atan2(player.faceY, player.faceX),
        });
      else if (arcCombo) launchArcVolley(shot);
      else projectiles.push(shot);
      if (!chargingSpecial)
        burst(
          player.x + player.faceX * 12,
          player.y + player.faceY * 12,
          weapon.lightning
            ? "#c7a8ff"
          : weapon.frost
            ? "#91e9ef"
          : weapon.explosive
              ? "#ff9a4e"
              : hasSpecial
                ? "#ffe39a"
                : "#85d8ce",
          hasSpecial ? 7 : 3,
        );
      return;
    }
    sound(155, 0.045, "triangle");
    player.weaponCooldowns[weaponId] =
      CONFIG.combat.basicDuration / attackSpeed;
    player.weaponAttackTimers[weaponId] =
      CONFIG.combat.basicDuration / attackSpeed;
    if (target) {
      const d = Math.hypot(target.x - player.x, target.y - player.y) || 1;
      player.faceX = (target.x - player.x) / d;
      player.faceY = (target.y - player.y) / d;
    }
    if (manual && input.mouse.active) {
      const dx = input.mouse.x - (player.x - camera.x),
        dy = input.mouse.y - (player.y - camera.y);
      if (Math.hypot(dx, dy) > 5) {
        const d = Math.hypot(dx, dy);
        player.faceX = dx / d;
        player.faceY = dy / d;
      }
    }
    const sabreFinisher = weaponId === "sabre" && hasSpecial && swing % 3 === 0;
    const daggerFinisher = weaponId === "dagues" && hasSpecial && swing % 3 === 0;
    const lanceFinisher = weaponId === "lance" && hasSpecial && swing % 3 === 0;
    const scytheFinisher = weaponId === "faux" && hasSpecial && swing % 3 === 0;
    const sabreCombo = weaponId === "sabre" && hasActiveSynergy("sabre-talisman"),
      lanceCombo = weaponId === "lance" && hasActiveSynergy("lance-seal"),
      sabreComboRadius = 104;
    let hit = false;
    for (const e of [...enemies]) {
      const x = e.x - player.x,
        y = e.y - player.y,
        d = Math.hypot(x, y),
        dot = (x * player.faceX + y * player.faceY) / (d || 1);
      const lanceReach = weaponStats.range;
      const lanceWidth = 18 + e.r + (lanceFinisher ? 8 : 0);
      const inAttackShape = weapon.circular
        ? d < lanceReach
        : weapon.piercing
          ? distanceToSegment(
              e.x,
              e.y,
              player.x,
              player.y,
              player.x + player.faceX * lanceReach,
              player.y + player.faceY * lanceReach,
            ) < lanceWidth
          : d < lanceReach && dot > weapon.arc;
      if (inAttackShape) {
        const sabreComboBurst = sabreCombo && (e.sabreComboMarks || 0) === 4;
        if (sabreCombo) e.sabreComboMarks = sabreComboBurst ? 0 : (e.sabreComboMarks || 0) + 1;
        let damage =
          (e.kind === "brute" ? weapon.bruteDamage : weapon.ghoulDamage) *
          weaponDamage * (lanceFinisher && weaponId === "lance" ? 1.45 : 1);
        damageEnemy(e, damage, weaponId);
        if (sabreComboBurst) {
          discoverSynergy("sabre-talisman");
          weaponEffects.push({
            kind: "sabreBurst",
            x: e.x,
            y: e.y,
            radius: sabreComboRadius,
            life: 0.34,
            maxLife: 0.34,
          });
          for (const nearby of [...enemies]) {
            if (Math.hypot(nearby.x - e.x, nearby.y - e.y) <= sabreComboRadius)
              damageEnemy(
                nearby,
                (nearby.kind === "brute" ? weapon.bruteDamage : weapon.ghoulDamage) *
                  weaponDamage * 1.35,
                weaponId,
              );
          }
        }
        if (lanceCombo) {
          discoverSynergy("lance-seal");
          player.shield = Math.min(player.maxHp * 0.5, (player.shield || 0) + 8);
        }
        if (sabreFinisher && enemies.includes(e)) e.sabreMark = true;
        if (daggerFinisher && enemies.includes(e)) {
          e.daggerBleed = {
            remaining: 1.8,
            tick: 0.45,
            damage:
              (e.kind === "brute" ? weapon.bruteDamage : weapon.ghoulDamage) *
              weaponDamage *
              0.24,
          };
        }
        hit = true;
        if (state !== STATES.playing) break;
      }
    }
    if (hit)
      burst(
        player.x + player.faceX * 65,
        player.y + player.faceY * 65,
        weaponId === "marteau"
          ? "#e99b58"
          : weaponId === "faux"
            ? "#bce7a0"
          : weaponId === "lance"
            ? "#f0dfa8"
          : weaponId === "dagues"
            ? "#b4e2cd"
            : "#e8c57e",
        weaponId === "marteau" ? 11 : 5,
      );
    if (weaponId === "marteau" && hasSpecial) {
      weaponEffects.push({
        kind: "hammerWave",
        x: player.x,
        y: player.y,
        angle: Math.atan2(player.faceY, player.faceX),
        arc: weapon.arc,
        outer: weaponStats.range + 34,
        fullCircle: hasActiveSynergy("marteau-stone"),
        weaponId,
        damageMultiplier: weaponDamage *
          (hasActiveSynergy("marteau-stone") ? 1.05 : 0.55),
        delay: 0.16,
        life: 0.3,
        maxLife: 0.3,
      });
    }
    const releasedSouls =
      weaponId === "faux" && hasActiveSynergy("faux-heart")
        ? player.scytheSouls || 0
        : 0;
    if (scytheFinisher || releasedSouls) {
      if (releasedSouls) discoverSynergy("faux-heart");
      player.scytheSouls = Math.max(0, (player.scytheSouls || 0) - releasedSouls);
      weaponEffects.push({
        kind: "scytheWave", x: player.x, y: player.y,
        radius: weaponStats.range * 1.08, weaponId,
        damage: weapon.ghoulDamage * weaponDamage *
          (0.32 + releasedSouls * 0.42),
        souls: releasedSouls,
        life: 0.42, maxLife: 0.42, active: false,
      });
    }
    if (daggerFinisher && hit) {
      sound(460, 0.08, "sawtooth");
      burst(
        player.x + player.faceX * 48,
        player.y + player.faceY * 48,
        "#a9ffe1",
        12,
      );
    }
  }

  function special() {
    if (state !== STATES.playing || specialCooldown > 0) return;
    const hero = HEROES[player.hero];
    if (hero.special !== "charge") return;
    sound(105, 0.18, "sawtooth");
    specialCooldown = hero.cooldown;
    player.attack = CONFIG.combat.chargeDuration;
    let hit = 0;
    const sx = player.x,
      sy = player.y;
    let distance = hero.chargeDistance;
    for (let step = 12; step <= hero.chargeDistance; step += 12)
      if (isBlocked(sx + player.faceX * step, sy + player.faceY * step, 11)) {
        distance = step - 12;
        break;
      }
    for (const e of [...enemies]) {
      const dx = e.x - sx,
        dy = e.y - sy,
        along = dx * player.faceX + dy * player.faceY,
        cross = Math.abs(dx * player.faceY - dy * player.faceX);
      if (along > 0 && along < distance && cross < hero.chargeWidth) {
        damageEnemy(e, hero.chargeDamage);
        hit++;
      }
    }
    movePlayer(player.faceX * distance, player.faceY * distance);
    player.invuln = Math.max(player.invuln, hero.chargeInvulnerability);
    burst(player.x, player.y, "#d5ae69", 16);
    showNotice(
      `${hero.specialName}${hit ? ` · ${hit} touché${hit > 1 ? "s" : ""}` : ""}`,
    );
    updateHud();
  }

  function chainLightning(firstTarget, projectile) {
    const hitTargets = [firstTarget];

    let currentTarget = firstTarget;

    for (let bounce = 0; bounce < projectile.chainTargets; bounce++) {
      const nextTarget = enemies
        .filter((enemy) => !hitTargets.includes(enemy))
        .filter(
          (enemy) =>
            Math.hypot(enemy.x - currentTarget.x, enemy.y - currentTarget.y) <=
            (projectile.chainRange || 190),
        )
        .sort(
          (a, b) =>
            distanceBetween(a, currentTarget) -
            distanceBetween(b, currentTarget),
        )[0];

      if (!nextTarget) break;
      if (projectile.weaponId === "foudre" && hasActiveSynergy("foudre-relic"))
        discoverSynergy("foudre-relic");

      lightningArcs.push({
        from: currentTarget,
        to: nextTarget,
        life: 0.16,
      });

      hitTargets.push(nextTarget);

      damageEnemy(nextTarget, projectile.damage * 0.72, projectile.weaponId);

      currentTarget = nextTarget;
    }
    if (projectile.stormSpecial)
      weaponEffects.push({
        kind: "lightningZone",
        x: currentTarget.x,
        y: currentTarget.y,
        radius: 34,
        damage: projectile.damage * 0.28,
        weaponId: projectile.weaponId,
        tick: 0.12,
        life: 1.2,
        maxLife: 1.2,
      });
  }

  function detonateBomb(projectile) {
    const { x, y, explosionRadius: radius } = projectile;
    sound(projectile.specialBlast ? 78 : 112, 0.18, "sawtooth");
    weaponEffects.push({
      kind: "bombExplosion",
      x,
      y,
      radius,
      weaponId: projectile.weaponId,
      life: 0.38,
      maxLife: 0.38,
      special: projectile.specialBlast,
    });
    burst(x, y, projectile.specialBlast ? "#ffe18a" : "#ff9a4e", 16);
    for (const enemy of [...enemies]) {
      const dx = enemy.x - x,
        dy = enemy.y - y,
        distance = Math.hypot(dx, dy);
      if (distance <= radius + enemy.r) {
        damageEnemy(enemy, projectile.damage, projectile.weaponId);
        if (enemies.includes(enemy) && distance > 0)
          moveEnemy(enemy, (dx / distance) * 24, (dy / distance) * 24);
      }
      if (state !== STATES.playing) break;
    }
    if (projectile.specialBlast && !projectile.pickupCombo)
      weaponEffects.push({
        kind: "bombBurn",
        x,
        y,
        radius: radius * 0.78,
        damage: projectile.damage * 0.18,
        weaponId: projectile.weaponId,
        tick: 0.16,
        life: 0.82,
        maxLife: 0.82,
      });
  }

  function processWeaponEffects(dt) {
    for (let i = weaponEffects.length - 1; i >= 0; i--) {
      const effect = weaponEffects[i];
      if (effect.kind === "arcCharge" || effect.kind === "lightningCharge") {
        effect.delay -= dt;
        if (effect.delay <= 0) {
          const shotAngle = Math.atan2(effect.shot.vy, effect.shot.vx);
          effect.shot.x = player.x + Math.cos(shotAngle) * 14;
          effect.shot.y = player.y + Math.sin(shotAngle) * 14;
          if (effect.fan) launchArcVolley(effect.shot);
          else projectiles.push(effect.shot);
          sound(
            effect.shot.lightning ? 350 : 640,
            0.075,
            effect.shot.lightning ? "sawtooth" : "triangle",
          );
          burst(
            effect.shot.x,
            effect.shot.y,
            effect.shot.lightning ? "#c7a8ff" : "#ffe39a",
            7,
          );
          weaponEffects.splice(i, 1);
        }
      } else if (effect.kind === "hammerWave") {
        if (!effect.active) {
          effect.delay -= dt;
          if (effect.delay <= 0) {
            effect.active = true;
            if (effect.fullCircle) discoverSynergy("marteau-stone");
            sound(92, 0.13, "sawtooth");
            for (const enemy of [...enemies]) {
              const dx = enemy.x - effect.x,
                dy = enemy.y - effect.y,
                distance = Math.hypot(dx, dy),
                facing =
                  (dx * Math.cos(effect.angle) + dy * Math.sin(effect.angle)) /
                  (distance || 1);
              if (
                distance <= effect.outer &&
                (effect.fullCircle || facing > effect.arc)
              ) {
                damageEnemy(
                  enemy,
                  (enemy.kind === "brute"
                    ? WEAPONS.marteau.bruteDamage
                    : WEAPONS.marteau.ghoulDamage) * effect.damageMultiplier,
                  effect.weaponId,
                );
                if (enemies.includes(enemy) && !effect.fullCircle)
                  moveEnemy(
                    enemy,
                    (dx / (distance || 1)) * (effect.fullCircle ? 58 : 26),
                    (dy / (distance || 1)) * (effect.fullCircle ? 58 : 26),
                  );
              }
              if (state !== STATES.playing) break;
            }
            if (effect.fullCircle)
              weaponEffects.push({
                kind: "hammerShockwave",
                x: effect.x,
                y: effect.y,
                radius: effect.outer + 48,
                delay: 0.12,
                life: 0.28,
                maxLife: 0.28,
              });
            burst(effect.x, effect.y, "#ffd184", 14);
          }
        } else {
          effect.life -= dt;
          if (effect.life <= 0) weaponEffects.splice(i, 1);
        }
      } else if (effect.kind === "hammerShockwave") {
        if (effect.delay > 0) {
          effect.delay -= dt;
          if (effect.delay <= 0) {
            for (const enemy of [...enemies]) {
              const dx = enemy.x - effect.x,
                dy = enemy.y - effect.y,
                distance = Math.hypot(dx, dy);
              if (distance <= effect.radius && distance > 0)
                moveEnemy(enemy, (dx / distance) * 76, (dy / distance) * 76);
            }
            sound(120, 0.09, "sine");
          }
        } else {
          effect.life -= dt;
          if (effect.life <= 0) weaponEffects.splice(i, 1);
        }
      } else if (effect.kind === "bombBurn") {
        effect.life -= dt;
        effect.tick -= dt;
        if (effect.tick <= 0) {
          for (const enemy of [...enemies])
            if (Math.hypot(enemy.x - effect.x, enemy.y - effect.y) < effect.radius)
              damageEnemy(enemy, effect.damage, effect.weaponId);
          effect.tick += 0.2;
        }
        if (effect.life <= 0) weaponEffects.splice(i, 1);
      } else if (effect.kind === "lightningZone") {
        effect.life -= dt;
        effect.tick -= dt;
        if (effect.tick <= 0) {
          for (const enemy of [...enemies])
            if (
              Math.hypot(enemy.x - effect.x, enemy.y - effect.y) < effect.radius
            )
              damageEnemy(enemy, effect.damage, effect.weaponId);
          effect.tick += 0.3;
        }
        if (effect.life <= 0) weaponEffects.splice(i, 1);
      } else if (effect.kind === "scytheWave") {
        if (!effect.active) {
          effect.active = true;
          sound(190, 0.1, "sawtooth");
          for (const enemy of [...enemies])
            if (Math.hypot(enemy.x - effect.x, enemy.y - effect.y) <= effect.radius + enemy.r)
              damageEnemy(enemy, effect.damage, effect.weaponId);
        }
        effect.life -= dt;
        if (effect.life <= 0) weaponEffects.splice(i, 1);
      } else {
        effect.life -= dt;
        if (effect.life <= 0) weaponEffects.splice(i, 1);
      }
    }
  }

  function distanceToSegment(x, y, startX, startY, endX, endY) {
    const dx = endX - startX,
      dy = endY - startY,
      lengthSquared = dx * dx + dy * dy,
      progress = clamp(
        ((x - startX) * dx + (y - startY) * dy) / lengthSquared,
        0,
        1,
      );
    return Math.hypot(
      x - (startX + dx * progress),
      y - (startY + dy * progress),
    );
  }

  function distanceBetween(first, second) {
    return Math.hypot(first.x - second.x, first.y - second.y);
  }

  function kill(e, weaponId = null) {
    if (!enemies.includes(e)) return;
    sound(
      e.kind === "boss" ? 70 : 320,
      e.kind === "boss" ? 0.4 : 0.08,
      "triangle",
    );
    enemies.splice(enemies.indexOf(e), 1);
    defeated++;
    const newDiscovery = recordBestiary(e);
    if (newDiscovery || defeated % 10 === 0) saveProgress();
    progressObjective("kills");
    if (e.eliteId) {
      progressObjective("elite");
      progressObjective("elites");
    }
    const weaponSynergy = weaponId
      ? getWeaponCombatStats(player, weaponId, WEAPONS[weaponId])
      : null;
    if (weaponId === "dagues" && hasActiveSynergy("dagues-boots")) {
      const targets = enemies
        .map((target) => ({ target, distance: distanceBetween(e, target) }))
        .filter(({ distance }) => distance <= 300)
        .sort((a, b) => a.distance - b.distance)
        .slice(0, 3);
      if (targets.length) discoverSynergy("dagues-boots");
      for (const { target } of targets) {
        const angle = Math.atan2(target.y - e.y, target.x - e.x),
          speed = 620;
        projectiles.push({
          team: "player",
          spectralDagger: true,
          weaponId: null,
          x: e.x,
          y: e.y,
          vx: Math.cos(angle) * speed,
          vy: Math.sin(angle) * speed,
          speed,
          homingTarget: target,
          damage: WEAPONS.dagues.ghoulDamage * (weaponSynergy?.damageMultiplier || 1) * 1.4,
          radius: 6,
          color: "#a9ffe1",
          life: 1.4,
        });
      }
    }
    if (
      weaponId === "givre" &&
      e.slowTime > 0 &&
      hasActiveSynergy("givre-vampire")
    ) {
      discoverSynergy("givre-vampire");
      const radius = 124;
      weaponEffects.push({
        kind: "frostNova",
        x: e.x,
        y: e.y,
        radius,
        life: 0.42,
        maxLife: 0.42,
      });
      for (const target of [...enemies]) {
        if (distanceBetween(e, target) > radius) continue;
        target.slowTime = Math.max(target.slowTime || 0, 1.8);
        target.slowFactor = 0.35;
        damageEnemy(
          target,
          WEAPONS.givre.ghoulDamage * (weaponSynergy?.damageMultiplier || 1) * 1.35,
        );
      }
    }
    if (weaponId === "faux" && hasActiveSynergy("faux-heart")) {
      player.scytheSouls = Math.min(5, (player.scytheSouls || 0) + 1);
    }
    if (e.kind === "boss") {
      bossActive = false;
      player.reward = "Éclat de Valombre";
      burst(e.x, e.y, "#d6ad68", 32);
      dropXp(e.x, e.y, (weaponSynergy?.experienceMultiplier || 1) * (e.eliteId ? 1.5 : 1));
      if (runMode === "infinite") {
        saveData.shards = (saveData.shards || 0) + 1;
        saveProgress();
        showNotice(`${e.bossName} vaincu · +1 Éclat · la chasse continue`);
        beginIntermission();
      } else finishRun("victory");
      return;
    }
    const roll = Math.random();
    const difficultyDrops = DIFFICULTIES[difficulty].itemDrop;
    const potionChance = CONFIG.drops.potionChance * difficultyDrops;
    const equipmentChance = CONFIG.drops.relicChance * difficultyDrops;
    if (roll < potionChance)
      spawnDrop(e.x, e.y, {
        type: "potion",
        life: CONFIG.drops.lifetime,
      });
    else if (roll < potionChance + equipmentChance) {
      const weaponIds = getUpgradeableWeaponIds(
        player,
        Object.keys(WEAPONS),
      ).filter(
        (id) =>
          (!singleWeapon || id === player.weapon) &&
          (!ui.customDrops.checked || selectedDropWeapons.includes(id)),
      );
      const relicChoices = getUpgradeableRelics(player, RELICS).filter(
        (relic) =>
          !ui.customDrops.checked || selectedDropRelics.includes(relic.id),
      );
      const dropTypes = [
        ...(weaponIds.length ? ["weapon"] : []),
        ...(relicChoices.length ? ["relic"] : []),
      ];
      const type = dropTypes[Math.floor(Math.random() * dropTypes.length)];
      if (type === "weapon") {
        const id = weaponIds[Math.floor(Math.random() * weaponIds.length)];
        if (id)
          spawnDrop(e.x, e.y, {
            type: "weapon",
            weapon: id,
            life: CONFIG.drops.lifetime,
          });
      } else if (type === "relic") {
        if (relicChoices.length) {
          const relic =
            relicChoices[Math.floor(Math.random() * relicChoices.length)];
          spawnDrop(e.x, e.y, {
            type: "relic",
            relic: relic.id,
            life: CONFIG.drops.lifetime,
          });
        }
      }
    }
    burst(e.x, e.y, e.kind === "brute" ? "#9d5744" : "#b99e68", 9);
    dropXp(e.x, e.y, (weaponSynergy?.experienceMultiplier || 1) * (e.eliteId ? 1.5 : 1));
  }

  function burst(x, y, color, n) {
    for (let i = 0; i < n; i++) {
      const a = rand(0, Math.PI * 2),
        s = rand(35, 150);
      particles.push({
        x,
        y,
        vx: Math.cos(a) * s,
        vy: Math.sin(a) * s,
        life: rand(0.18, 0.5),
        max: 0.5,
        color,
      });
    }
  }

  function updateMagnetSynergy() {
    player.globalPickup = getActiveSynergies(player).some(
      (synergy) => synergy.globalPickup,
    );
  }

  // Per-frame simulation and rendering
  function update(dt) {
    if (runMode === "infinite") {
      const elapsedMinute = Math.floor(infiniteElapsedMinutes());
      if (elapsedMinute !== lastInfiniteHudMinute) {
        lastInfiniteHudMinute = elapsedMinute;
        updateHud();
      }
    }
    if (noticeTimer > 0) {
      noticeTimer -= dt;
      if (noticeTimer <= 0) ui.notice.classList.remove("visible");
    }
    specialCooldown = Math.max(0, specialCooldown - dt);
    player.attack = Math.max(0, player.attack - dt);
    for (const item of player.weaponInventory) {
      player.weaponCooldowns[item.id] = Math.max(
        0,
        (player.weaponCooldowns[item.id] || 0) - dt,
      );
      player.weaponAttackTimers[item.id] = Math.max(
        0,
        (player.weaponAttackTimers[item.id] || 0) - dt,
      );
    }
    player.invuln = Math.max(0, player.invuln - dt);
    player.dodgeCooldown = Math.max(0, player.dodgeCooldown - dt);
    let dx =
        (input.keys.has("d") || input.keys.has("arrowright") ? 1 : 0) -
        (input.keys.has("a") || input.keys.has("arrowleft") ? 1 : 0) +
        input.touchMove.x,
      dy =
        (input.keys.has("s") || input.keys.has("arrowdown") ? 1 : 0) -
        (input.keys.has("w") || input.keys.has("arrowup") ? 1 : 0) +
        input.touchMove.y,
      len = Math.hypot(dx, dy) || 1;
    if (player.dodgeTime > 0) {
      const step = Math.min(dt, player.dodgeTime);
      movePlayer(
        player.dodgeX *
          CONFIG.combat.dodgeSpeed *
          player.movementSpeedMultiplier *
          player.equipmentSpeed *
          step,
        player.dodgeY *
          CONFIG.combat.dodgeSpeed *
          player.movementSpeedMultiplier *
          player.equipmentSpeed *
          step,
      );
      player.dodgeTime -= step;
    } else if (dx || dy) {
      movePlayer(
        (dx / len) *
          player.speed *
          player.movementSpeedMultiplier *
          player.equipmentSpeed *
          dt,
        (dy / len) *
          player.speed *
          player.movementSpeedMultiplier *
          player.equipmentSpeed *
          dt,
      );
      player.faceX = dx / len;
      player.faceY = dy / len;
    }
    player.isMoving = Boolean(dx || dy || player.dodgeTime > 0);

    if (enemies.length) {
      let autoTarget = null;
      let nearestDistance = Infinity;
      const findAutoTarget = () => {
        autoTarget = null;
        nearestDistance = Infinity;
        for (const enemy of enemies) {
          const distance = Math.hypot(enemy.x - player.x, enemy.y - player.y);
          if (distance < nearestDistance) {
            autoTarget = enemy;
            nearestDistance = distance;
          }
        }
      };
      findAutoTarget();
      for (const item of player.weaponInventory) {
        if (state !== STATES.playing || !enemies.length) break;
        const weapon = WEAPONS[item.id];
        if (
          (player.weaponCooldowns[item.id] || 0) <= 0 &&
          nearestDistance <
            getWeaponCombatStats(player, item.id, weapon).range
        ) {
          const enemyCountBeforeAttack = enemies.length;
          attackWeapon(item.id);
          if (enemies.length < enemyCountBeforeAttack) findAutoTarget();
        }
      }
    }
    if (input.keys.has(" ") || input.keys.has("j") || input.touchAttack) {
      attack(true);
    }
    if (state !== STATES.playing) return;

    updateWaves(dt);
    if (state !== STATES.playing) return;
    updateMagnetSynergy();

    for (const e of enemies) {
      if (!Number.isFinite(e.x) || !Number.isFinite(e.y)) {
        console.error("[ennemi invalide retiré]", {
          kind: e.kind,
          position: { x: e.x, y: e.y },
        });
        enemies.splice(enemies.indexOf(e), 1);
        continue;
      }
      if (
        e.x >= camera.x &&
        e.x <= camera.x + VIEW_WIDTH &&
        e.y >= camera.y &&
        e.y <= camera.y + VIEW_HEIGHT
      )
        discoverEnemy(e);
      const attackSpeed = DIFFICULTIES[difficulty].attackSpeed;
      e.phase += dt * 3;
      e.slowTime = Math.max(0, (e.slowTime || 0) - dt);
      const slowFactor =
        e.slowTime > 0 && Number.isFinite(e.slowFactor) ? e.slowFactor : 1;
      e.hit = Math.max(0, e.hit - dt);
      if (e.daggerBleed) {
        e.daggerBleed.remaining -= dt;
        e.daggerBleed.tick -= dt;
        if (e.daggerBleed.tick <= 0) {
          damageEnemy(e, e.daggerBleed.damage, "dagues");
          e.daggerBleed.tick += 0.45;
        }
        if (!enemies.includes(e)) continue;
        if (e.daggerBleed.remaining <= 0) e.daggerBleed = null;
      }
      e.attack -= dt * attackSpeed;
      let x = player.x - e.x,
        y = player.y - e.y,
        d = Math.hypot(x, y) || 1;
      if (e.kind === "boss") {
        const spec = BOSSES[e.bossId] || BOSSES.guardian;
        if (e.dash) {
          const dash = e.dash,
            step = Math.min(dt, dash.remaining),
            fraction = step / dash.remaining,
            startX = e.x,
            startY = e.y,
            moveX = dash.dx * fraction,
            moveY = dash.dy * fraction;
          moveEnemy(e, moveX, moveY);
          const actualX = e.x - startX,
            actualY = e.y - startY,
            actualLengthSq = actualX * actualX + actualY * actualY;
          if (!dash.hit && actualLengthSq > 0) {
            const hitProgress = clamp(
                ((player.x - startX) * actualX +
                  (player.y - startY) * actualY) /
                  actualLengthSq,
                0,
                1,
              ),
              hitX = startX + actualX * hitProgress,
              hitY = startY + actualY * hitProgress;
            if (
              Math.hypot(player.x - hitX, player.y - hitY) <
              dash.hitWidth + 12
            ) {
              damagePlayer(
                e.chargeDamage || spec.chargeDamage,
                `Boss ${e.bossName || e.bossId} · ${dash.kind === "charge" ? "charge" : "ruée"}`,
                e,
              );
              dash.hit = true;
            }
          }
          dash.dx *= 1 - fraction;
          dash.dy *= 1 - fraction;
          dash.remaining -= step;
          if (dash.remaining <= 0) {
            e.dash = null;
            e.dashCooldown = spec.dashCooldown;
            e.attack = Math.max(e.attack, 0.65);
          }
          if (state !== STATES.playing) break;
          continue;
        }
        if (e.dashTelegraph > 0) {
          e.dashTelegraph -= dt * attackSpeed;
          if (e.dashTelegraph <= 0) {
            const dx = e.aimX - e.x,
              dy = e.aimY - e.y,
              distance = Math.hypot(dx, dy) || 1,
              dashDistance = Math.min(
                spec.dashDistance,
                Math.max(0, distance - spec.dashStopDistance),
              );
            e.dash = {
              dx: (dx / distance) * dashDistance,
              dy: (dy / distance) * dashDistance,
              remaining: spec.dashDuration,
              hit: false,
              kind: "approach",
              hitWidth: spec.dashWidth,
            };
          }
          continue;
        }
        e.dashCooldown -= dt * attackSpeed;
        if (
          e.telegraph <= 0 &&
          d > spec.approachRange &&
          e.dashCooldown <= 0
        ) {
          e.aimX = player.x;
          e.aimY = player.y;
          e.dashTelegraph = spec.dashWindup;
          continue;
        }
      }
      if (e.kind === "boss" && e.bossBehavior === "volley") {
        const spec = BOSSES[e.bossId];
        if (d < 210) moveEnemy(e, (-x / d) * e.speed * slowFactor * dt, (-y / d) * e.speed * slowFactor * dt);
        else if (d > 330) moveEnemy(e, (x / d) * e.speed * slowFactor * dt, (y / d) * e.speed * slowFactor * dt);
        if (e.telegraph > 0) {
          e.telegraph -= dt * attackSpeed;
          if (e.telegraph <= 0) {
            const angle = Math.atan2(e.aimY - e.y, e.aimX - e.x);
            for (let shot = 0; shot < 5; shot++) {
              const direction = angle + (shot - 2) * 0.2;
              projectiles.push({
                x: e.x,
                y: e.y,
                vx:
                  Math.cos(direction) *
                  spec.projectileSpeed *
                  DIFFICULTIES[difficulty].projectileSpeed,
                vy:
                  Math.sin(direction) *
                  spec.projectileSpeed *
                  DIFFICULTIES[difficulty].projectileSpeed,
                damage: e.projectileDamage,
                source: `${e.bossName || e.bossId} · projectile`,
                radius: 10,
                life: 3,
                color: "#a8d978",
              });
            }
            e.attack = spec.cooldown;
          }
        } else if (e.attack <= 0) {
          e.aimX = player.x;
          e.aimY = player.y;
          e.telegraph = spec.telegraph;
        }
      } else if (e.kind === "boss") {
        const spec = BOSSES[e.bossId] || BOSSES.guardian;
        if (e.telegraph > 0) {
          e.telegraph -= dt * attackSpeed;
          if (e.telegraph <= 0) {
            if (e.attackMode === "slam") {
              if (Math.hypot(player.x - e.x, player.y - e.y) < spec.slamRadius)
                damagePlayer(
                  e.slamDamage || spec.slamDamage,
                  `Boss ${e.bossName || e.bossId} · frappe au sol`,
                  e,
                );
            } else {
              const dx = e.aimX - e.x,
                dy = e.aimY - e.y,
                len = Math.hypot(dx, dy) || 1,
                dashDistance = Math.min(
                  spec.chargeDistance,
                  Math.max(0, len - spec.dashStopDistance),
                );
              e.dash = {
                dx: (dx / len) * dashDistance,
                dy: (dy / len) * dashDistance,
                remaining: spec.dashDuration,
                hit: false,
                kind: "charge",
                hitWidth: spec.chargeWidth,
              };
            }
            e.attack = spec.cooldown;
            if (e.bossBehavior !== "volley")
              e.attackMode = e.attackMode === "slam" ? "charge" : "slam";
          }
        } else if (e.attack <= 0) {
          e.telegraph = spec.telegraph;
          e.aimX = player.x;
          e.aimY = player.y;
        } else if (d > e.r + 85)
          moveEnemy(e, (x / d) * e.speed * slowFactor * dt, (y / d) * e.speed * slowFactor * dt);
      } else if (e.kind === "leaper") {
        const spec = CONFIG.enemies.leaper;
        if (e.leap) {
          const step = Math.min(dt, e.leap.remaining);
          const fraction = step / e.leap.remaining;
          moveEnemy(e, e.leap.dx * fraction, e.leap.dy * fraction);
          e.leap.dx *= 1 - fraction;
          e.leap.dy *= 1 - fraction;
          e.leap.remaining -= step;
          e.leap.elapsed += step;
          if (e.leap.remaining <= 0) {
            if (Math.hypot(player.x - e.x, player.y - e.y) < spec.landingRadius)
              damagePlayer(e.damage, "Sauteur · atterrissage", e);
            burst(e.x, e.y, "#e7a35c", 8);
            e.leap = null;
          }
        } else if (e.telegraph > 0) {
          e.telegraph -= dt * attackSpeed;
          if (e.telegraph <= 0) {
            e.leap = {
              dx: e.aimX - e.x,
              dy: e.aimY - e.y,
              remaining: 0.24,
              elapsed: 0,
              duration: 0.24,
            };
            e.attack = spec.attackCooldown;
          }
        } else if (e.attack <= 0 && d < spec.leapRange) {
          e.aimX = player.x;
          e.aimY = player.y;
          e.telegraph = spec.windup;
        } else if (d > e.r + CONFIG.combat.enemyReach) {
          moveEnemy(e, (x / d) * e.speed * slowFactor * dt, (y / d) * e.speed * slowFactor * dt);
        }
      } else if (e.kind === "charger") {
        const spec = CONFIG.enemies.charger;
        if (e.telegraph > 0) {
          e.telegraph -= dt * attackSpeed;
          if (e.telegraph <= 0) {
            const tx = e.aimX - e.x,
              ty = e.aimY - e.y,
              len = Math.hypot(tx, ty) || 1,
              along = ((player.x - e.x) * tx + (player.y - e.y) * ty) / len,
              cross =
                Math.abs((player.x - e.x) * ty - (player.y - e.y) * tx) / len;
            if (along > 0 && along < spec.range && cross < 30)
              damagePlayer(e.damage, "Chargeur · charge", e);
            moveEnemy(
              e,
              (tx / len) *
                spec.chargeSpeed *
                DIFFICULTIES[difficulty].speed *
                0.45,
              (ty / len) *
                spec.chargeSpeed *
                DIFFICULTIES[difficulty].speed *
                0.45,
            );
            e.attack = spec.attackCooldown;
          }
        } else if (e.attack <= 0 && d < spec.range) {
          e.aimX = player.x;
          e.aimY = player.y;
          e.telegraph = spec.windup;
        } else if (d > e.r + CONFIG.combat.enemyReach)
          moveEnemy(e, (x / d) * e.speed * slowFactor * dt, (y / d) * e.speed * slowFactor * dt);
      } else if (e.kind === "caster" || e.kind === "shaman") {
        const spec = CONFIG.enemies[e.kind];
        if (d < spec.range * 0.72)
          moveEnemy(e, (-x / d) * e.speed * slowFactor * dt, (-y / d) * e.speed * slowFactor * dt);
        else if (d > spec.range)
          moveEnemy(e, (x / d) * e.speed * slowFactor * dt, (y / d) * e.speed * slowFactor * dt);
        if (e.telegraph > 0) {
          e.telegraph -= dt * attackSpeed;
          if (e.telegraph <= 0) {
            const tx = e.aimX - e.x,
              ty = e.aimY - e.y,
              baseAngle = Math.atan2(ty, tx),
              count = e.kind === "shaman" ? 3 : 1;
            for (let shot = 0; shot < count; shot++) {
              const angle = baseAngle + (shot - (count - 1) / 2) * 0.24;
              projectiles.push({
                x: e.x,
                y: e.y,
                vx:
                  Math.cos(angle) *
                  spec.projectileSpeed *
                  DIFFICULTIES[difficulty].projectileSpeed,
                vy:
                  Math.sin(angle) *
                  spec.projectileSpeed *
                  DIFFICULTIES[difficulty].projectileSpeed,
                damage: e.damage,
                source: `${e.kind} · projectile`,
                radius: e.kind === "shaman" ? 8 : 7,
                life: 2,
                color: e.kind === "shaman" ? "#bd79ce" : undefined,
              });
            }
            e.attack = spec.attackCooldown;
          }
        } else if (e.attack <= 0 && d < spec.range + 115) {
          e.aimX = player.x;
          e.aimY = player.y;
          e.telegraph = spec.windup;
        }
      } else if (d > e.r + CONFIG.combat.enemyReach)
        moveEnemy(e, (x / d) * e.speed * slowFactor * dt, (y / d) * e.speed * slowFactor * dt);
      else if (e.attack <= 0) {
        e.attack = CONFIG.enemies.attackCooldown;
        const wasHit =
          player.invuln <= 0
            ? damagePlayer(e.damage, `${e.kind} · contact`, e)
            : false;
        if (wasHit && e.healOnHit > 0 && player.hp > 0)
          e.hp = Math.min(e.maxHp, e.hp + e.healOnHit);
        if (state !== STATES.playing) break;
      }
    }
    if (state !== STATES.playing) return;

    processWeaponEffects(dt);

    for (let i = projectiles.length - 1; i >= 0; i--) {
      const p = projectiles[i];
      if (p.homingTarget && enemies.includes(p.homingTarget)) {
        const angle = Math.atan2(p.homingTarget.y - p.y, p.homingTarget.x - p.x);
        p.vx = Math.cos(angle) * p.speed;
        p.vy = Math.sin(angle) * p.speed;
      }
      p.x += p.vx * dt;
      p.y += p.vy * dt;
      p.life -= dt;
      if (p.team === "player") {
        const target = enemies.find(
          (e) =>
            !p.hitTargets?.includes(e) &&
            Math.hypot(e.x - p.x, e.y - p.y) < e.r + p.radius,
        );
        if (target) {
          if (p.explosive) {
            detonateBomb(p);
            projectiles.splice(i, 1);
            continue;
          }
          if (p.frost && enemies.includes(target)) {
            target.slowTime = Math.max(target.slowTime || 0, p.slowDuration);
            target.slowFactor = p.slowFactor;
          }
          damageEnemy(target, p.damage, p.weaponId);
          if (p.lightning) chainLightning(target, p);
          burst(p.x, p.y, p.color || "#85d8ce", 5);
          if (p.piercing) {
            p.hitTargets.push(target);
            p.damage *= 1.18;
          } else projectiles.splice(i, 1);
        }
      } else if (Math.hypot(p.x - player.x, p.y - player.y) < p.radius + 10) {
        damagePlayer(p.damage, p.source || "Projectile ennemi", p);
        projectiles.splice(i, 1);
        if (state !== STATES.playing) return;
      }
      if (p.life <= 0 || isBlocked(p.x, p.y, p.radius)) {
        if (p.explosive) detonateBomb(p);
        projectiles.splice(i, 1);
      }
    }

    let bombComboPickups = 0;
    for (let i = drops.length - 1; i >= 0; i--) {
      const d = drops[i];
      if (!player.globalPickup) d.life -= dt;
      const dx = player.x - d.x,
        dy = player.y - d.y,
        distance = Math.hypot(dx, dy),
        pickupRadius = 22;
      if (
        distance > pickupRadius &&
        (distance < player.pickupRange || player.globalPickup || d.pullTime > 0)
      ) {
        d.pullTime = (d.pullTime || 0) + dt;
        const speed =
          player.speed *
          player.movementSpeedMultiplier *
          player.equipmentSpeed *
          1.2;
        d.vx = (dx / distance) * speed;
        d.vy = (dy / distance) * speed;
        const step = Math.min(distance, speed * dt);
        d.x += (dx / distance) * step;
        d.y += (dy / distance) * step;
      } else if (distance >= player.pickupRange) {
        d.pullTime = 0;
        d.vx = 0;
        d.vy = 0;
      }
      if (Math.hypot(player.x - d.x, player.y - d.y) <= pickupRadius) {
        drops.splice(i, 1);
        if (player.globalPickup) bombComboPickups++;
        if (d.type === "potion") {
          sound(620, 0.12);
          player.hp = Math.min(
            player.maxHp,
            player.hp + CONFIG.drops.potionHeal,
          );
          showNotice(`Fiole écarlate · +${CONFIG.drops.potionHeal} PV`);
        } else if (d.type === "xp") {
          sound(790, 0.12, "sine");
          progressObjective("xp");
          gainXp(d.amount);
        } else {
          sound(790, 0.16, "triangle");
          if (d.type === "weapon") pickWeapon(d.weapon);
          else pickRelic(d.relic);
        }
        if (state !== STATES.playing) break;
      } else if (d.life <= 0) drops.splice(i, 1);
    }
    if (bombComboPickups) {
      discoverSynergy("bombe-magnet");
      const bombStats = getWeaponCombatStats(player, "bombe", WEAPONS.bombe);
      detonateBomb({
        x: player.x,
        y: player.y,
        explosionRadius: 92,
        damage:
          WEAPONS.bombe.ghoulDamage *
          bombStats.damageMultiplier *
          Math.min(4, 1.4 + (bombComboPickups - 1) * 0.55),
        weaponId: "bombe",
        specialBlast: true,
        pickupCombo: true,
      });
    }

    for (let i = particles.length - 1; i >= 0; i--) {
      const p = particles[i];
      p.life -= dt;
      p.x += p.vx * dt;
      p.y += p.vy * dt;
      p.vx *= 0.94;
      p.vy *= 0.94;
      if (p.life <= 0) particles.splice(i, 1);
    }

    for (let i = lightningArcs.length - 1; i >= 0; i--) {
      lightningArcs[i].life -= dt;
      if (lightningArcs[i].life <= 0) lightningArcs.splice(i, 1);
    }

    for (let i = damageNumbers.length - 1; i >= 0; i--) {
      const n = damageNumbers[i];
      n.life -= dt;
      n.y -= 25 * dt;
      if (n.life <= 0) damageNumbers.splice(i, 1);
    }

    separateEnemyCrowds(dt);
    camera.x = clamp(player.x - VIEW_WIDTH / 2, 0, world.width - VIEW_WIDTH);
    camera.y = clamp(player.y - VIEW_HEIGHT / 2, 0, world.height - VIEW_HEIGHT);
    updateHud();
  }

  function draw() {
    renderGame({
      player,
      enemies,
      drops,
      particles,
      projectiles,
      damageNumbers,
      lightningArcs,
      weaponEffects,
      camera,
    });
  }

  function loop(t) {
    animationFrameId = null;
    if (state === STATES.playing) {
      const dt =
        Math.max(0, Math.min((t - last) / 1000, 0.04)) * (runMode === "infinite" ? 1.25 : 1);
      if (!Number.isFinite(dt)) {
        console.error("[horloge simulation invalide]", { t, last, dt, runMode });
        last = Math.max(last, t);
        draw();
        scheduleLoop();
        return;
      }
      last = Math.max(last, t);
      update(dt);
    }
    draw();
    if (
      [STATES.playing, STATES.paused, STATES.levelUp, STATES.loot].includes(state)
    )
      scheduleLoop();
  }

  function scheduleLoop() {
    if (animationFrameId !== null) return;
    animationFrameId = requestAnimationFrame(loop);
  }

  reset();
  showProgress();
  setState(STATES.title);
  draw();
})();
