import { STATES } from "./config.js";

export function createInputControls({
  canvas,
  ui,
  getState,
  setState,
  resumeRun,
  toggleInventory,
  attack,
  special,
  dodge,
  resetFrameClock,
}) {
  const keys = new Set();
  const mouse = { x: 0, y: 0, active: false };
  let touchMove = { x: 0, y: 0 };
  let touchAttack = false;

  window.addEventListener("keydown", (e) => {
    const activeElement = document.activeElement,
      activeLock = activeElement.matches(
        "[data-relic-lock], [data-weapon-lock]",
      );
    if (
      getState() === STATES.playing &&
      !ui.inventoryPanel.hidden &&
      activeLock
    ) {
      if (["ArrowUp", "ArrowDown", "ArrowLeft", "ArrowRight"].includes(e.key)) {
        const selector = activeElement.matches("[data-relic-lock]")
            ? "[data-relic-lock]"
            : "[data-weapon-lock]",
          list = selector === "[data-relic-lock]" ? ui.relicList : ui.weaponList,
          locks = [...list.querySelectorAll(selector)],
          index = locks.indexOf(activeElement);
        const step = e.key === "ArrowUp" || e.key === "ArrowLeft" ? -1 : 1;
        if (locks.length) {
          e.preventDefault();
          locks[(index + step + locks.length) % locks.length].focus();
        }
        return;
      }
      if (e.key === "Enter" || e.key === " ") {
        e.preventDefault();
        activeElement.checked = !activeElement.checked;
        activeElement.dispatchEvent(
          new Event("change", { bubbles: true }),
        );
        return;
      }
    }
    if (e.key === "Tab" && getState() === STATES.playing) {
      if (
        !ui.inventoryPanel.hidden &&
        (ui.inventoryPanel.contains(document.activeElement) ||
          document.activeElement === ui.inventoryToggle)
      )
        return;
      e.preventDefault();
      if (!e.repeat) toggleInventory();
      return;
    }
    if (e.key === "Escape") {
      e.preventDefault();
      if (e.repeat) return;
      if (getState() === STATES.playing) setState(STATES.paused);
      else if (getState() === STATES.paused) resumeRun();
      return;
    }
    if (
      !ui.overlay.classList.contains("hidden") &&
      e.key === "Enter" &&
      !e.repeat &&
      document.activeElement.matches("button")
    ) {
      e.preventDefault();
      document.activeElement.click();
      return;
    }
    if (
      !ui.overlay.classList.contains("hidden") &&
      e.key === "Enter" &&
      !e.repeat &&
      document.activeElement.matches('input[type="checkbox"]')
    ) {
      e.preventDefault();
      document.activeElement.checked = !document.activeElement.checked;
      document.activeElement.dispatchEvent(
        new Event("change", { bubbles: true }),
      );
      return;
    }
    if (
      [STATES.levelUp, STATES.loot].includes(getState()) &&
      ["ArrowUp", "ArrowDown", "ArrowLeft", "ArrowRight"].includes(e.key)
    ) {
      const choices = [...ui.upgradeOptions.querySelectorAll("button")];
      if (choices.length) {
        e.preventDefault();
        const current = Math.max(0, choices.indexOf(document.activeElement));
        const direction =
          e.key === "ArrowDown" || e.key === "ArrowRight" ? 1 : -1;
        choices[
          (current + direction + choices.length) % choices.length
        ].focus();
      }
      return;
    }
    if (
      !ui.overlay.classList.contains("hidden") &&
      ["ArrowUp", "ArrowDown", "ArrowLeft", "ArrowRight"].includes(e.key)
    ) {
      const active = document.activeElement;
      if (
        active.matches("select") &&
        (e.key === "ArrowLeft" || e.key === "ArrowRight")
      ) {
        e.preventDefault();
        const step = e.key === "ArrowRight" ? 1 : -1;
        active.selectedIndex =
          (active.selectedIndex + step + active.options.length) %
          active.options.length;
        active.dispatchEvent(new Event("change", { bubbles: true }));
        return;
      }
      if (
        active.matches('input[type="range"]') &&
        (e.key === "ArrowLeft" || e.key === "ArrowRight")
      )
        return;
      const items = [
        ...ui.overlay.querySelectorAll(
          'button,select,input:not([type="hidden"])',
        ),
      ].filter(
        (item) =>
          !item.disabled &&
          !item.closest("[hidden]") &&
          item.getClientRects().length > 0,
      );
      if (items.length) {
        e.preventDefault();
        const index = items.indexOf(active),
          step = e.key === "ArrowDown" || e.key === "ArrowRight" ? 1 : -1;
        items[
          (index < 0 ? 0 : index + step + items.length) % items.length
        ].focus();
      }
      return;
    }
    if (
      [
        "ArrowUp",
        "ArrowDown",
        "ArrowLeft",
        "ArrowRight",
        " ",
        "Shift",
      ].includes(e.key)
    )
      e.preventDefault();
    if (e.repeat && (e.key === "e" || e.key === "E" || e.key === "Shift"))
      return;
    keys.add(e.key.toLowerCase());
    if (e.key === "e" || e.key === "E") special();
    if (e.key === "Shift") dodge();
  });

  window.addEventListener("keyup", (e) => keys.delete(e.key.toLowerCase()));

  window.addEventListener("blur", () => keys.clear());

  document.addEventListener("visibilitychange", () => {
    if (document.hidden) keys.clear();
    resetFrameClock();
  });

  canvas.addEventListener("pointermove", (e) => {
    const r = canvas.getBoundingClientRect();
    mouse.x = ((e.clientX - r.left) * canvas.width) / r.width;
    mouse.y = ((e.clientY - r.top) * canvas.height) / r.height;
    mouse.active = true;
  });

  canvas.addEventListener("pointerdown", (e) => {
    const r = canvas.getBoundingClientRect();
    mouse.x = ((e.clientX - r.left) * canvas.width) / r.width;
    mouse.y = ((e.clientY - r.top) * canvas.height) / r.height;
    mouse.active = true;
    attack(true);
  });

  const joystick = document.querySelector("#joystick"),
    stick = document.querySelector("#stick");
  let joystickPointer = null;

  function moveStick(e) {
    const rect = joystick.getBoundingClientRect(),
      cx = rect.left + rect.width / 2,
      cy = rect.top + rect.height / 2,
      dx = e.clientX - cx,
      dy = e.clientY - cy,
      len = Math.hypot(dx, dy),
      scale = len > 32 ? 32 / len : 1;
    touchMove = {
      x: (dx * scale) / 32,
      y: (dy * scale) / 32,
    };
    stick.style.transform = `translate(${dx * scale}px,${dy * scale}px)`;
  }

  joystick.addEventListener("pointerdown", (e) => {
    e.preventDefault();
    joystickPointer = e.pointerId;
    joystick.setPointerCapture(e.pointerId);
    moveStick(e);
  });
  joystick.addEventListener("pointermove", (e) => {
    if (e.pointerId === joystickPointer) moveStick(e);
  });
  const releaseStick = (e) => {
    if (e.pointerId !== joystickPointer) return;
    joystickPointer = null;
    touchMove = {
      x: 0,
      y: 0,
    };
    stick.style.transform = "";
  };
  joystick.addEventListener("pointerup", releaseStick);
  joystick.addEventListener("pointercancel", releaseStick);

  document.querySelectorAll(".touch-actions button").forEach((button) => {
    const action = button.dataset.action;
    button.addEventListener("pointerdown", (e) => {
      e.preventDefault();
      button.setPointerCapture(e.pointerId);
      if (action === "attack") {
        touchAttack = true;
        attack(true);
      } else if (action === "special") special();
      else if (action === "dodge") dodge();
      else if (action === "pause" && getState() === STATES.playing)
        setState(STATES.paused);
    });
    const release = () => {
      if (action === "attack") touchAttack = false;
    };
    button.addEventListener("pointerup", release);
    button.addEventListener("pointercancel", release);
  });

  return {
    keys,
    mouse,
    get touchMove() {
      return touchMove;
    },
    get touchAttack() {
      return touchAttack;
    },
    reset() {
      keys.clear();
      mouse.active = false;
    },
  };
}
