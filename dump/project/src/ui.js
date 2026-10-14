const UI_ELEMENT_IDS = [
  "health-fill",
  "xp-fill",
  "health-text",
  "xp-text",
  "level-text",
  "wave-text",
  "enemy-text",
  "skill-text",
  "special-name",
  "special-skill",
  "special-action",
  "dodge-text",
  "hero-name",
  "hero-class",
  "shield-fill",
  "hero-picker",
  "hero-select",
  "weapon-name",
  "weapon-picker",
  "weapon-select",
  "weapon-help",
  "choice-hint",
  "mode-picker",
  "mode-select",
  "difficulty-picker",
  "difficulty-select",
  "custom-drops",
  "drop-settings",
  "drop-options",
  "drop-weapons",
  "drop-relics",
  "difficulty-text",
  "weapon-count",
  "inventory-count",
  "relic-list",
  "weapon-list",
  "weapon-stats",
  "relic-stats",
  "enemy-stats",
  "run-objectives",
  "synergy-count",
  "synergy-list",
  "inventory-toggle",
  "cheat-toggle",
  "inventory-panel",
  "boss-hud",
  "boss-name",
  "boss-fill",
  "notice",
  "overlay",
  "dialog-title",
  "dialog-copy",
  "loot-preview",
  "pause-catalog",
  "upgrade-options",
  "start",
  "restart-run",
  "new-run",
  "return-menu",
  "save-text",
  "share-run",
  "share-link",
  "mute",
  "volume",
  "reset-save",
];

/** Collect the game's DOM controls by both kebab-case and camelCase names. */
export function createUiElements() {
  return Object.fromEntries(
    UI_ELEMENT_IDS.flatMap((id) => {
      const element = document.getElementById(id);
      const camelCaseId = id.replace(/-([a-z])/g, (_, letter) =>
        letter.toUpperCase(),
      );
      return [
        [id, element],
        [camelCaseId, element],
      ];
    }),
  );
}

/** Build an accessible selection card for a level-up or loot choice. */
export function createChoiceCard(titleText, description, onChoose, icons = []) {
  const button = document.createElement("button");
  button.className = "upgrade-card";
  button.type = "button";
  button.setAttribute("aria-label", `${titleText} : ${description}`);

  if (icons.length) {
    const iconList = document.createElement("span");
    iconList.className = "choice-icons";
    for (const { folder, id } of icons) {
      const icon = document.createElement("img");
      icon.className = "choice-icon";
      icon.src = `assets/${folder}/${id}.svg`;
      icon.alt = "";
      icon.setAttribute("aria-hidden", "true");
      iconList.append(icon);
    }
    button.append(iconList);
  }
  const copy = document.createElement("span");
  copy.className = "choice-copy";
  const title = document.createElement("strong");
  title.textContent = titleText;
  const detail = document.createElement("small");
  detail.textContent = description;
  copy.append(title, detail);
  button.append(copy);
  button.addEventListener("click", onChoose);
  return button;
}
