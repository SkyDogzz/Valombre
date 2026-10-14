import { BOSSES, CONFIG, WEAPONS } from "./config.js";
import { getWeaponCombatStats } from "./inventory.js";

export function createRenderer(canvas, world, obstacles) {
  const screenCtx = canvas.getContext("2d");
  let ctx = screenCtx;
  const staticLayer = canvas.ownerDocument.createElement("canvas");
  staticLayer.width = world.width;
  staticLayer.height = world.height;
  const staticCtx = staticLayer.getContext("2d");
  const VIEW_WIDTH = canvas.width;
  const VIEW_HEIGHT = canvas.height;
  const clamp = (value, min, max) => Math.max(min, Math.min(max, value));
  const arc = (x, y, radius, start, end) =>
    ctx.arc(x, y, Number.isFinite(radius) ? Math.max(0, radius) : 0, start, end);
  const rand = (min, max) => min + Math.random() * (max - min);
  let player,
    enemies,
    drops,
    particles,
    projectiles,
    damageNumbers,
    lightningArcs,
    weaponEffects,
    camera;
  const isInViewport = (x, y, margin = 0) =>
    x + margin >= camera.x &&
    x - margin <= camera.x + VIEW_WIDTH &&
    y + margin >= camera.y &&
    y - margin <= camera.y + VIEW_HEIGHT;

  const sprites = Object.fromEntries(
    [
      ["pilgrim", "hero"],
      ["sentinel", "sentinel"],
      ["ghoul", "ghoul"],
      ["brute", "brute"],
      ["caster", "caster"],
      ["stalker", "stalker"],
      ["charger", "charger"],
      ["shaman", "shaman"],
      ["boss", "boss"],
      ["matriarch", "matriarch"],
      ["colossus", "colossus"],
      ["leech", "leech"],
      ["leaper", "leaper"],
    ].map(([name, file]) => {
      const image = new Image();
      image.src = `assets/${file}.svg`;
      return [name, image];
    }),
  );
  const heldWeaponSprites = Object.fromEntries(
    Object.keys(WEAPONS).map((type) => {
      const image = new Image();
      image.src = `assets/held-weapons/${type}.svg`;
      return [type, image];
    }),
  );
  const dropSprites = Object.fromEntries(
    [
      ["weapon", "weapons/category"],
      ["relic", "relics/category"],
      ["xp", "xp"],
    ].map(([key, file]) => {
      const image = new Image();
      image.src = `assets/${file}.svg${key === "xp" ? "?v=3" : ""}`;
      return [key, image];
    }),
  );

  function draw(frame) {
    ({
      player,
      enemies,
      drops,
      particles,
      projectiles,
      damageNumbers,
      lightningArcs,
      weaponEffects,
      camera,
    } = frame);
    ctx.clearRect(0, 0, VIEW_WIDTH, VIEW_HEIGHT);
    ctx.save();
    ctx.translate(-camera.x, -camera.y);
    ctx.drawImage(staticLayer, 0, 0);
    for (const d of drops)
      if (isInViewport(d.x, d.y, 30)) drawDrop(d);
    for (const p of projectiles)
      if (isInViewport(p.x, p.y, p.radius * 4 + 16)) drawProjectile(p);
    for (const arc of lightningArcs) drawLightningArc(arc);
    for (const effect of weaponEffects)
      if (
        (effect.kind !== "hammerWave" || effect.fullCircle) &&
        (!Number.isFinite(effect.x) ||
          isInViewport(
            effect.x,
            effect.y,
            Math.max(effect.radius || 0, effect.outer || 0) + 24,
          ))
      )
        drawWeaponEffect(effect);
    drawPlayer();
    for (const e of enemies)
      if (isInViewport(e.x, e.y, e.r + 18)) drawEnemy(e);
    for (const p of particles) {
      if (!isInViewport(p.x, p.y, 3)) continue;
      ctx.globalAlpha = clamp(p.life * 3, 0, 1);
      ctx.fillStyle = p.color;
      ctx.beginPath();
      arc(p.x, p.y, 2.2, 0, Math.PI * 2);
      ctx.fill();
    }
    for (const n of damageNumbers) {
      if (!isInViewport(n.x, n.y, 24)) continue;
      ctx.globalAlpha = clamp(n.life / n.maxLife, 0, 1);
      ctx.font = "bold 12px Georgia";
      ctx.textAlign = "center";
      ctx.lineWidth = 3;
      ctx.strokeStyle = "#17130e";
      ctx.fillStyle = "#f5dda0";
      ctx.strokeText(n.text, n.x, n.y);
      ctx.fillText(n.text, n.x, n.y);
    }
    ctx.globalAlpha = 1;
    ctx.restore();
  }

  function drawGround() {
    ctx.fillStyle = "#22251b";
    ctx.fillRect(0, 0, world.width, world.height);
    for (let y = 0; y < world.height; y += 64)
      for (let x = 0; x < world.width; x += 64) {
        let n = Math.sin(x * 12.9898 + y * 78.233) * 43758.5453;
        n -= Math.floor(n);
        ctx.fillStyle = n > 0.87 ? "#292a1f" : n < 0.12 ? "#1e2119" : "#24261d";
        ctx.fillRect(x, y, 63, 63);
        if (n > 0.78) {
          ctx.fillStyle = "#3c3a2b";
          ctx.fillRect(x + 13, y + 19, 2, 2);
          ctx.fillRect(x + 42, y + 47, 3, 2);
        }
      }
    ctx.fillStyle = "#343126";
    ctx.fillRect(world.width / 2 - 185, world.height / 2 - 155, 370, 310);
    ctx.fillStyle = "#302e23";
    ctx.fillRect(world.width / 2 - 178, world.height / 2 - 148, 356, 296);
    ctx.strokeStyle = "#494332";
    ctx.lineWidth = 3;
    ctx.strokeRect(world.width / 2 - 178, world.height / 2 - 148, 356, 296);
    ctx.strokeStyle = "#3d392a";
    ctx.setLineDash([5, 9]);
    ctx.lineWidth = 2;
    ctx.strokeRect(world.width / 2 - 118, world.height / 2 - 97, 236, 194);
    ctx.setLineDash([]);
    ctx.strokeStyle = "#62583e";
    ctx.lineWidth = 12;
    ctx.strokeRect(6, 6, world.width - 12, world.height - 12);
    ctx.strokeStyle = "#25251d";
    ctx.lineWidth = 4;
    ctx.strokeRect(6, 6, world.width - 12, world.height - 12);
  }

  function drawProps() {
    for (let y = 55; y < world.height; y += 88)
      for (let x = 55; x < world.width; x += 96) {
        let n = Math.sin(x * 24.1 + y * 8.7) * 17453.2;
        n -= Math.floor(n);
        if (
          n > 0.87 ||
          Math.hypot(x - world.width / 2, y - world.height / 2) < 245
        )
          continue;
        let xx = x + Math.sin(y) * 15,
          yy = y + Math.cos(x) * 12,
          r = 10 + n * 12;
        ctx.fillStyle = "#151811";
        ctx.beginPath();
        ctx.ellipse(xx, yy + 7, r * 1.2, r * 0.48, 0, 0, 7);
        ctx.fill();
        ctx.fillStyle = n > 0.94 ? "#343025" : "#303426";
        ctx.beginPath();
        arc(xx, yy, r, 0, 7);
        ctx.fill();
        ctx.fillStyle = "#424331";
        ctx.beginPath();
        arc(xx - r * 0.25, yy - r * 0.3, r * 0.58, 0, 7);
        ctx.fill();
        ctx.strokeStyle = "#594c33";
        ctx.lineWidth = 2;
        ctx.beginPath();
        ctx.moveTo(xx - r * 0.8, yy + r * 0.25);
        ctx.lineTo(xx + r * 0.8, yy - r * 0.25);
        ctx.stroke();
      }
  }

  function drawObstacles() {
    for (const o of obstacles) {
      ctx.fillStyle = "#161712";
      ctx.beginPath();
      ctx.ellipse(o.x, o.y + 8, o.r * 1.3, o.r * 0.55, 0, 0, 7);
      ctx.fill();
      ctx.fillStyle = "#4a4737";
      ctx.beginPath();
      arc(o.x, o.y, o.r, 0, 7);
      ctx.fill();
      ctx.fillStyle = "#66604a";
      ctx.beginPath();
      arc(o.x - o.r * 0.3, o.y - o.r * 0.35, o.r * 0.55, 0, 7);
      ctx.fill();
    }
  }

  function drawPlayer() {
    const x = player.x,
      y = player.y,
      weapon = WEAPONS[player.weapon],
      angle = Math.atan2(player.faceY, player.faceX),
      weaponTimer = player.weaponAttackTimers[player.weapon] || 0;
    const weaponDuration =
      CONFIG.combat.basicDuration /
      (weapon.speed *
        player.attackSpeedMultiplier *
        getWeaponCombatStats(player, player.weapon, weapon)
          .attackSpeedMultiplier);
    const weaponProgress =
      weaponTimer > 0 ? clamp(1 - weaponTimer / weaponDuration, 0, 1) : null;
    ctx.fillStyle = "#10110eaa";
    ctx.beginPath();
    ctx.ellipse(x, y + 10, 18, 9, 0, 0, 7);
    ctx.fill();

    if (player.shield > 0) {
      ctx.strokeStyle = "#9ae9f0";
      ctx.shadowColor = "#73d7e3";
      ctx.shadowBlur = 8;
      ctx.globalAlpha = Math.min(0.82, 0.3 + player.shield / player.maxHp);
      ctx.lineWidth = 2.5;
      ctx.beginPath();
      arc(x, y - 3, 23 + Math.min(5, player.shield / 10), 0, Math.PI * 2);
      ctx.stroke();
      ctx.globalAlpha = 1;
      ctx.shadowBlur = 0;
    }

    if (player.dodgeTime > 0) {
      ctx.strokeStyle = "#d9c18a88";
      ctx.lineWidth = 3;
      ctx.beginPath();
      ctx.moveTo(
        x - player.dodgeX * 32 - player.dodgeY * 7,
        y - player.dodgeY * 32 + player.dodgeX * 7,
      );
      ctx.lineTo(x - player.dodgeX * 12, y - player.dodgeY * 12);
      ctx.stroke();
    }

    for (const item of player.weaponInventory) {
      const attackWeapon = WEAPONS[item.id],
        weaponStats = getWeaponCombatStats(player, item.id, attackWeapon),
        timer = player.weaponAttackTimers[item.id] || 0;
      if (timer <= 0 || attackWeapon.ranged) continue;
      const duration =
        CONFIG.combat.basicDuration /
        (attackWeapon.speed *
          player.attackSpeedMultiplier *
          weaponStats.attackSpeedMultiplier);
      const progress = clamp(1 - timer / duration, 0, 1),
        reach = weaponStats.range;
      const hammerImpact =
        item.id === "marteau" ? 1 - clamp(progress / 0.62, 0, 1) : null;
      ctx.save();
      ctx.translate(x, y);
      ctx.rotate(angle);
      if (item.id === "sabre") {
        const direction =
          (player.weaponSwingCount?.[item.id] || 0) % 2 ? 1 : -1;
        const start = direction === 1 ? -1.3 : 1.3,
          end = direction === 1 ? 1.3 : -1.3;
        const sweep = start + (end - start) * progress;
        ctx.lineCap = "round";
        ctx.save();
        ctx.rotate(sweep);
        const guard = reach * 0.2,
          tip = reach * 0.88;
        ctx.shadowColor = "#e8c57e";
        ctx.shadowBlur = 12;
        ctx.strokeStyle = "#8b593b";
        ctx.lineWidth = 6;
        ctx.beginPath();
        ctx.moveTo(7, 0);
        ctx.lineTo(guard, 0);
        ctx.stroke();
        ctx.fillStyle = "#c88759";
        ctx.beginPath();
        arc(7, 0, 3.5, 0, Math.PI * 2);
        ctx.fill();
        ctx.strokeStyle = "#e9c77e";
        ctx.lineWidth = 3;
        ctx.beginPath();
        ctx.moveTo(guard, -9);
        ctx.lineTo(guard + 3, 0);
        ctx.lineTo(guard, 9);
        ctx.stroke();
        const blade = ctx.createLinearGradient(guard, 0, tip, 0);
        blade.addColorStop(0, "#b8a77d");
        blade.addColorStop(0.28, "#fff2c8");
        blade.addColorStop(0.82, "#e8dfc3");
        blade.addColorStop(1, "#fff9e9");
        ctx.fillStyle = blade;
        ctx.strokeStyle = "#fff7dc";
        ctx.lineWidth = 1.5;
        ctx.beginPath();
        ctx.moveTo(guard + 2, -4.5);
        ctx.lineTo(tip - 7, -2.5);
        ctx.lineTo(tip, 0);
        ctx.lineTo(tip - 7, 2.5);
        ctx.lineTo(guard + 2, 4.5);
        ctx.closePath();
        ctx.fill();
        ctx.stroke();
        ctx.restore();
      } else if (item.id === "marteau") {
        const pulse = 0.5 + 0.5 * Math.sin(progress * 75);
        const impactRadius = 34 + pulse * 12;
        ctx.lineCap = "round";
        for (let i = 0; i < 9; i++) {
          const a = (i / 9) * Math.PI * 2 + progress * 0.4,
            inner = 5 + (i % 3) * 3,
            outer = impactRadius * (0.62 + (i % 2) * 0.34),
            bend = (i % 2 ? 1 : -1) * (0.09 + 0.035 * pulse);
          const point = (radius, direction) => ({
            x: Math.cos(direction) * radius,
            y: Math.sin(direction) * radius,
          });
          const start = point(inner, a),
            middle = point((inner + outer) * 0.52, a + bend),
            end = point(outer, a - bend * 0.45);
          ctx.globalAlpha =
            hammerImpact * (0.55 + 0.45 * Math.sin(progress * 55 + i * 1.4));
          ctx.strokeStyle = i % 3 === 0 ? "#fff2c5" : "#ffd184";
          ctx.shadowColor = "#ff893e";
          ctx.shadowBlur = 8 + 8 * pulse;
          ctx.lineWidth = 2 + 2 * pulse;
          ctx.beginPath();
          ctx.moveTo(start.x, start.y);
          ctx.lineTo(middle.x, middle.y);
          ctx.lineTo(end.x, end.y);
          ctx.stroke();
          const shardAngle = progress * 18 + i * 2.4,
            shardX = end.x + Math.cos(shardAngle) * 3,
            shardY = end.y + Math.sin(shardAngle) * 3,
            shardSize = 3 + 2 * pulse;
          ctx.fillStyle = "#fff0bb";
          ctx.save();
          ctx.translate(shardX, shardY);
          ctx.rotate(shardAngle);
          ctx.fillRect(-shardSize / 2, -shardSize / 2, shardSize, shardSize);
          ctx.restore();
        }
      } else if (item.id === "dagues") {
        const extension = reach * (1 - 0.65 * clamp(progress / 0.42, 0, 1));
        ctx.lineCap = "round";
        ctx.shadowColor = "#a9ffe1";
        ctx.shadowBlur = 10;
        ctx.strokeStyle = "#effff4";
        ctx.lineWidth = 3.5;
        for (const side of [-1, 1]) {
          ctx.beginPath();
          ctx.moveTo(8, side * 5);
          ctx.lineTo(8 + extension, side * 5);
          ctx.stroke();
          ctx.fillStyle = "#a9e6d0";
          ctx.beginPath();
          ctx.moveTo(12 + extension, side * 5);
          ctx.lineTo(5 + extension, side * 2);
          ctx.lineTo(5 + extension, side * 8);
          ctx.closePath();
          ctx.fill();
        }
      } else if (item.id === "lance") {
        const reachPoint = reach * (0.48 + 0.52 * Math.sin(progress * Math.PI));
        ctx.globalAlpha = 0.55 + 0.45 * Math.sin(progress * Math.PI);
        ctx.strokeStyle = "#b1815e";
        ctx.lineWidth = 5;
        ctx.beginPath();
        ctx.moveTo(4, 0);
        ctx.lineTo(reachPoint * 0.83, 0);
        ctx.stroke();
        ctx.fillStyle = "#f4e8bd";
        ctx.shadowColor = "#fff0b8";
        ctx.shadowBlur = 12;
        ctx.beginPath();
        ctx.moveTo(reachPoint, 0);
        ctx.lineTo(reachPoint * 0.8, -5);
        ctx.lineTo(reachPoint * 0.8, 5);
        ctx.closePath();
        ctx.fill();
      } else if (item.id === "faux") {
        const start = -Math.PI + progress * Math.PI * 2,
          end = start + progress * Math.PI * 2,
          sweepRadius = reach * 0.86;
        ctx.strokeStyle = "#bfe69a";
        ctx.shadowColor = "#a8e67e";
        ctx.shadowBlur = 14;
        ctx.lineWidth = 5 + 3 * Math.sin(progress * Math.PI);
        ctx.globalAlpha = 0.35 + 0.6 * Math.sin(progress * Math.PI);
        ctx.beginPath();
        arc(0, 0, sweepRadius, start, end);
        ctx.stroke();
      }
      ctx.restore();
    }

    const sprite = sprites[player.hero];
    if (sprite.complete && sprite.naturalWidth) {
      ctx.globalAlpha =
        player.invuln > 0 && Math.floor(performance.now() / 70) % 2 ? 0.55 : 1;
      ctx.drawImage(sprite, x - 24, y - 34, 48, 60);
      ctx.globalAlpha = 1;
      drawWeapon(
        x + player.faceX * 7,
        y + player.faceY * 7,
        angle,
        player.weapon,
        weaponProgress,
      );
      drawSpecialWeaponVisual(x, y, angle, player.weapon, weaponProgress);
      return;
    }

    ctx.fillStyle = "#27221a";
    ctx.beginPath();
    ctx.ellipse(x, y + 1, 11, 14, 0, 0, 7);
    ctx.fill();
    ctx.fillStyle =
      player.invuln > 0 && Math.floor(performance.now() / 70) % 2
        ? "#d9c69b"
        : "#aa966d";
    ctx.beginPath();
    arc(x, y - 9, 8, 0, 7);
    ctx.fill();
    ctx.fillStyle = "#382b20";
    ctx.beginPath();
    ctx.moveTo(x - 8, y - 13);
    ctx.lineTo(x, y - 22);
    ctx.lineTo(x + 8, y - 13);
    ctx.closePath();
    ctx.fill();
    drawWeapon(
      x + player.faceX * 7,
      y + player.faceY * 7,
      angle,
      player.weapon,
      weaponProgress,
    );
    drawSpecialWeaponVisual(x, y, angle, player.weapon, weaponProgress);
  }

  function drawSpecialWeaponVisual(x, y, angle, type, progress) {
    const special = player.weaponInventory.find(
      (item) => item.id === type,
    )?.special;
    const chargeKind = type === "arc" ? "arcCharge" : "lightningCharge";
    if (
      ["arc", "foudre"].includes(type) &&
      weaponEffects.some((effect) => effect.kind === chargeKind)
    ) {
      const charge = weaponEffects.find((effect) => effect.kind === chargeKind),
        amount = clamp(1 - charge.delay / 0.14, 0, 1),
        chargeAngle = charge.angle + (type === "foudre" ? -0.45 : 0),
        px = x + Math.cos(chargeAngle) * (type === "foudre" ? 23 : 31),
        py = y + Math.sin(chargeAngle) * (type === "foudre" ? 23 : 31),
        color = type === "foudre" ? "#cbb2ff" : "#ffe39a";
      ctx.save();
      ctx.globalAlpha = 0.5 + amount * 0.5;
      ctx.fillStyle = color;
      ctx.strokeStyle = color;
      ctx.shadowColor = color;
      ctx.shadowBlur = 14 + amount * 18;
      ctx.beginPath();
      arc(px, py, 3 + amount * 5, 0, Math.PI * 2);
      ctx.fill();
      if (type === "foudre")
        for (let i = -1; i <= 1; i++) {
          const startAngle = chargeAngle + i * 0.38,
            startX = x + Math.cos(startAngle) * 12,
            startY = y + Math.sin(startAngle) * 12;
          ctx.beginPath();
          ctx.moveTo(startX, startY);
          ctx.lineTo(
            (startX + px) / 2 + Math.sin(performance.now() / 30 + i) * 5,
            (startY + py) / 2,
          );
          ctx.lineTo(px, py);
          ctx.stroke();
        }
      ctx.restore();
    }
    if (
      type === "sabre" &&
      special &&
      progress !== null &&
      (player.weaponSwingCount?.[type] || 0) % 3 === 0
    ) {
      const swing = (player.weaponSwingCount?.[type] || 0) % 2 ? 1 : -1,
        bladeAngle = angle + swing * (-1.3 + 2.6 * progress),
        reach = getWeaponCombatStats(player, type, WEAPONS[type]).range;
      ctx.save();
      ctx.strokeStyle = "#fff0b3";
      ctx.shadowColor = "#ffc65e";
      ctx.shadowBlur = 16;
      ctx.lineWidth = 5;
      ctx.beginPath();
      ctx.moveTo(x + Math.cos(bladeAngle) * 12, y + Math.sin(bladeAngle) * 12);
      ctx.lineTo(
        x + Math.cos(bladeAngle) * reach * 0.88,
        y + Math.sin(bladeAngle) * reach * 0.88,
      );
      ctx.stroke();
      ctx.restore();
    }
  }

  function drawWeapon(x, y, angle, type, attackProgress = null) {
    ctx.save();
    ctx.translate(x, y);
    ctx.rotate(angle);
    if (attackProgress !== null) {
      const progress = clamp(attackProgress, 0, 1),
        recovery = 1 - clamp(progress / 0.32, 0, 1);
      if (type === "sabre") {
        const direction = (player.weaponSwingCount?.[type] || 0) % 2 ? 1 : -1;
        ctx.rotate(direction * (-1.3 + 2.6 * progress));
      } else if (type === "marteau") ctx.rotate(1.25 * recovery);
      else if (type === "dagues") ctx.translate(12 * recovery, 0);
      else if (type === "arc") {
        ctx.rotate(-0.1 * recovery);
        ctx.scale(1, 1 + 0.25 * recovery);
      } else if (type === "foudre") {
        ctx.rotate(-0.18 * recovery);
        ctx.shadowColor = "#a88aff";
        ctx.shadowBlur = 10 + 12 * recovery;
      } else if (type === "bombe") {
        ctx.translate(7 * recovery, 0);
        ctx.rotate(Math.sin(progress * Math.PI) * 0.12);
        ctx.shadowColor = "#ff9a4e";
        ctx.shadowBlur = 8 + 10 * recovery;
      }
    }
    const sprite = heldWeaponSprites[type];
    if (sprite?.complete && sprite.naturalWidth) {
      ctx.drawImage(sprite, type === "arc" ? -21 : -4, -9, 42, 18);
      ctx.restore();
      return;
    }
    ctx.strokeStyle = "#c1c0ad";
    ctx.fillStyle = "#817251";
    ctx.lineWidth = 2;
    if (type === "marteau") {
      ctx.strokeStyle = "#8c603e";
      ctx.lineWidth = 4;
      ctx.beginPath();
      ctx.moveTo(0, 0);
      ctx.lineTo(20, 0);
      ctx.stroke();
      ctx.fillStyle = "#e0a45d";
      ctx.strokeStyle = "#f2cf86";
      ctx.lineWidth = 1.5;
      ctx.fillRect(15, -7, 12, 14);
      ctx.strokeRect(15, -7, 12, 14);
    } else if (type === "dagues") {
      ctx.strokeStyle = "#d9e4db";
      ctx.lineWidth = 2.5;
      ctx.beginPath();
      ctx.moveTo(0, -5);
      ctx.lineTo(16, -5);
      ctx.moveTo(0, 5);
      ctx.lineTo(16, 5);
      ctx.stroke();
      ctx.fillStyle = "#c97b55";
      ctx.fillRect(-3, -6, 5, 3);
      ctx.fillRect(-3, 3, 5, 3);
    } else if (type === "foudre") {
      ctx.strokeStyle = "#a88aff";
      ctx.lineWidth = 3;
      ctx.beginPath();
      ctx.moveTo(0, 0);
      ctx.lineTo(9, -5);
      ctx.lineTo(15, 3);
      ctx.lineTo(25, -4);
      ctx.stroke();
      ctx.fillStyle = "#c6a6ff";
      ctx.beginPath();
      arc(25, -4, 3, 0, Math.PI * 2);
      ctx.fill();
    } else if (type === "arc") {
      ctx.strokeStyle = "#79c9c0";
      ctx.lineWidth = 2.5;
      ctx.beginPath();
      arc(2, 0, 14, -1.2, 1.2);
      ctx.stroke();
      ctx.strokeStyle = "#e8d8a8";
      ctx.lineWidth = 1;
      ctx.beginPath();
      ctx.moveTo(7, -13);
      ctx.lineTo(7, 13);
      ctx.stroke();
      ctx.fillStyle = "#85d8ce";
      ctx.beginPath();
      ctx.moveTo(20, 0);
      ctx.lineTo(12, -3);
      ctx.lineTo(12, 3);
      ctx.closePath();
      ctx.fill();
    } else {
      ctx.beginPath();
      ctx.moveTo(0, 0);
      ctx.lineTo(25, 0);
      ctx.stroke();
      ctx.beginPath();
      ctx.moveTo(7, -2);
      ctx.lineTo(3, 2);
      ctx.stroke();
    }
    ctx.restore();
  }

  function drawEnemy(e) {
    const bob = Math.sin(e.phase) * 2,
      jumpProgress = e.leap ? e.leap.elapsed / e.leap.duration : 0,
      jumpHeight = Math.sin(jumpProgress * Math.PI) * 28,
      x = e.x,
      y = e.y + bob - jumpHeight;

    if (e.dash) {
      const length = Math.hypot(e.dash.dx, e.dash.dy) || 1,
        dx = e.dash.dx / length,
        dy = e.dash.dy / length;
      ctx.strokeStyle = "rgba(255,118,75,.7)";
      ctx.lineWidth = e.r * 0.8;
      ctx.lineCap = "round";
      ctx.beginPath();
      ctx.moveTo(x - dx * e.r * 1.8, y - dy * e.r * 1.8);
      ctx.lineTo(x - dx * e.r * 0.25, y - dy * e.r * 0.25);
      ctx.stroke();
      ctx.lineCap = "butt";
    }

    if (e.kind === "boss" && e.dashTelegraph > 0) {
      const spec = BOSSES[e.bossId] || CONFIG.boss,
        dx = e.aimX - e.x,
        dy = e.aimY - e.y,
        distance = Math.hypot(dx, dy) || 1,
        dashDistance = Math.min(
          spec.dashDistance,
          Math.max(0, distance - spec.dashStopDistance),
        ),
        nx = (dy / distance) * spec.dashWidth,
        ny = (-dx / distance) * spec.dashWidth,
        endX = e.x + (dx / distance) * dashDistance,
        endY = e.y + (dy / distance) * dashDistance;
      ctx.fillStyle = "rgba(255,118,75,.18)";
      ctx.strokeStyle = "rgba(255,151,94,.9)";
      ctx.lineWidth = 3;
      ctx.beginPath();
      ctx.moveTo(e.x + nx, e.y + ny);
      ctx.lineTo(endX + nx, endY + ny);
      ctx.lineTo(endX - nx, endY - ny);
      ctx.lineTo(e.x - nx, e.y - ny);
      ctx.closePath();
      ctx.fill();
      ctx.stroke();
    }

    if (e.eliteId) {
      ctx.strokeStyle = e.eliteColor || "#e2c47b";
      ctx.shadowColor = e.eliteColor || "#e2c47b";
      ctx.shadowBlur = 12;
      ctx.lineWidth = 3;
      ctx.beginPath();
      arc(x, y, e.r + 6 + Math.sin(performance.now() / 100) * 1.5, 0, Math.PI * 2);
      ctx.stroke();
      ctx.shadowBlur = 0;
    }

    if (e.sabreMark) {
      ctx.strokeStyle = "#ffe39a";
      ctx.shadowColor = "#ffca67";
      ctx.shadowBlur = 10;
      ctx.lineWidth = 2;
      ctx.beginPath();
      arc(
        x,
        y,
        e.r + 5 + Math.sin(performance.now() / 90) * 2,
        0,
        Math.PI * 2,
      );
      ctx.stroke();
      ctx.shadowBlur = 0;
    }

    if (e.sabreComboMarks) {
      ctx.fillStyle = "#ffb257";
      ctx.shadowColor = "#ff713c";
      ctx.shadowBlur = 8;
      for (let mark = 0; mark < e.sabreComboMarks; mark++) {
        const angle = (mark / 5) * Math.PI * 2 - Math.PI / 2;
        ctx.beginPath();
        arc(
          x + Math.cos(angle) * (e.r + 5),
          y + Math.sin(angle) * (e.r + 5),
          2.5,
          0,
          Math.PI * 2,
        );
        ctx.fill();
      }
      ctx.shadowBlur = 0;
    }

    if (e.daggerBleed) {
      const pulse = 0.5 + 0.5 * Math.sin(performance.now() / 75);
      ctx.strokeStyle = `rgba(137, 255, 207, ${0.55 + pulse * 0.4})`;
      ctx.shadowColor = "#65efbd";
      ctx.shadowBlur = 5 + pulse * 7;
      ctx.lineWidth = 2;
      ctx.beginPath();
      arc(x, y, e.r + 3 + pulse * 2, 0, Math.PI * 2);
      ctx.stroke();
      ctx.shadowBlur = 0;
    }

    if (e.kind === "boss" && e.bossBehavior !== "volley" && e.telegraph > 0) {
      ctx.fillStyle = "rgba(190,52,38,.17)";
      ctx.strokeStyle = "rgba(235,91,65,.8)";
      ctx.lineWidth = 3;
      ctx.beginPath();
      if (e.attackMode === "slam") {
        arc(e.x, e.y, BOSSES[e.bossId]?.slamRadius || CONFIG.boss.slamRadius, 0, Math.PI * 2);
        ctx.fill();
        ctx.stroke();
      } else {
        const bossConfig = BOSSES[e.bossId] || CONFIG.boss;
        const dx = e.aimX - e.x,
          dy = e.aimY - e.y,
          len = Math.hypot(dx, dy) || 1,
          dashDistance = Math.min(
            bossConfig.chargeDistance,
            Math.max(0, len - bossConfig.dashStopDistance),
          ),
          nx = (dy / len) * (bossConfig?.chargeWidth || CONFIG.boss.chargeWidth),
          ny = (-dx / len) * (bossConfig?.chargeWidth || CONFIG.boss.chargeWidth);
        ctx.moveTo(e.x + nx, e.y + ny);
        ctx.lineTo(
          e.x + (dx / len) * dashDistance + nx,
          e.y + (dy / len) * dashDistance + ny,
        );
        ctx.lineTo(
          e.x + (dx / len) * dashDistance - nx,
          e.y + (dy / len) * dashDistance - ny,
        );
        ctx.lineTo(e.x - nx, e.y - ny);
        ctx.closePath();
        ctx.fill();
        ctx.stroke();
      }
    }

    if (e.telegraph > 0) {
      const warning =
        e.bossBehavior === "volley" || e.kind === "shaman"
          ? "#bd79ce"
          : e.kind === "charger" || e.kind === "leaper"
            ? "#f2ae5a"
            : "#db5644";
      ctx.strokeStyle = warning;
      ctx.globalAlpha = 0.48 + Math.sin(e.phase * 4) * 0.22;
      ctx.lineWidth = e.kind === "charger" || e.kind === "leaper" ? 5 : 2;
      ctx.beginPath();
      ctx.moveTo(e.x, e.y);
      ctx.lineTo(e.aimX, e.aimY);
      ctx.stroke();
      if (e.kind === "leaper") {
        ctx.fillStyle = "rgba(242,174,90,.16)";
        ctx.beginPath();
        arc(e.aimX, e.aimY, CONFIG.enemies.leaper.landingRadius, 0, Math.PI * 2);
        ctx.fill();
        ctx.strokeStyle = warning;
        ctx.lineWidth = 2;
        ctx.beginPath();
        arc(e.aimX, e.aimY, CONFIG.enemies.leaper.landingRadius, 0, Math.PI * 2);
        ctx.stroke();
      } else if (e.bossBehavior === "volley") {
        const angle = Math.atan2(e.aimY - e.y, e.aimX - e.x);
        for (let shot = -2; shot <= 2; shot++) {
          ctx.beginPath();
          ctx.moveTo(e.x, e.y);
          ctx.lineTo(
            e.x + Math.cos(angle + shot * 0.2) * 330,
            e.y + Math.sin(angle + shot * 0.2) * 330,
          );
          ctx.stroke();
        }
      } else if (e.kind === "shaman") {
        const angle = Math.atan2(e.aimY - e.y, e.aimX - e.x);
        for (const offset of [-0.24, 0.24]) {
          ctx.beginPath();
          ctx.moveTo(e.x, e.y);
          ctx.lineTo(
            e.x + Math.cos(angle + offset) * CONFIG.enemies.shaman.range,
            e.y + Math.sin(angle + offset) * CONFIG.enemies.shaman.range,
          );
          ctx.stroke();
        }
      }
      ctx.globalAlpha = 1;
    }

    ctx.fillStyle = "#0d0e0caa";
    ctx.beginPath();
    ctx.ellipse(e.x, e.y + 8, e.r * (1.2 - jumpProgress * 0.25), e.r * (0.5 - jumpProgress * 0.12), 0, 0, 7);
    ctx.fill();

    const sprite = sprites[e.bossId === "guardian" ? "boss" : e.bossId || e.kind];
    if (sprite?.complete && sprite.naturalWidth) {
      const size =
        e.kind === "boss"
          ? e.bossId === "colossus"
            ? 118
            : 100
          : e.kind === "brute"
            ? 66
            : e.kind === "caster"
              ? 58
              : e.kind === "leaper"
                ? 56
              : 48;
      ctx.drawImage(sprite, x - size / 2, y - size * 0.78, size, size);
      if (e.eliteName) {
        ctx.fillStyle = e.eliteColor;
        ctx.font = "bold 10px Georgia";
        ctx.textAlign = "center";
        ctx.fillText(e.eliteName, x, y - size * 0.82);
      }
      if (e.hp < e.maxHp) {
        ctx.fillStyle = "#171713";
        ctx.fillRect(x - e.r, y - e.r - 9, e.r * 2, 3);
        ctx.fillStyle = "#aa4939";
        ctx.fillRect(x - e.r, y - e.r - 9, (e.r * 2 * e.hp) / e.maxHp, 3);
      }
      return;
    }

    const caster = e.kind === "caster" || e.kind === "shaman",
      shaman = e.kind === "shaman",
      charger = e.kind === "charger",
      boss = e.kind === "boss",
      stalker = e.kind === "stalker",
      leech = e.kind === "leech",
      leaper = e.kind === "leaper";

    ctx.fillStyle = e.hit
      ? "#eee1bd"
      : boss
        ? "#38242b"
        : e.kind === "brute"
          ? "#6f3930"
          : leaper
            ? "#493127"
          : leech
            ? "#343e45"
          : caster
            ? "#51343d"
            : stalker
              ? "#354d3a"
              : charger
                ? "#59402d"
                : shaman
                  ? "#3d354b"
                  : "#756246";
    ctx.beginPath();
    ctx.ellipse(x, y, e.r * (stalker ? 0.65 : 0.82), e.r, 0, 0, 7);
    ctx.fill();

    ctx.fillStyle = boss
      ? "#755044"
      : e.kind === "brute"
        ? "#aa6250"
        : leaper
          ? "#aa654a"
        : leech
          ? "#648c7a"
        : caster
          ? "#a35e62"
          : stalker
            ? "#72a06d"
            : charger
              ? "#d68c4e"
              : shaman
                ? "#bd79ce"
                : "#b4a271";
    ctx.beginPath();
    arc(x, y - e.r * 0.58, e.r * (boss ? 0.62 : 0.52), 0, 7);
    ctx.fill();

    if (boss) {
      ctx.fillStyle = "#d6ad68";
      ctx.beginPath();
      ctx.moveTo(x - e.r * 0.42, y - e.r * 0.88);
      ctx.lineTo(x - e.r * 0.76, y - e.r * 1.34);
      ctx.lineTo(x - e.r * 0.18, y - e.r * 1.1);
      ctx.moveTo(x + e.r * 0.42, y - e.r * 0.88);
      ctx.lineTo(x + e.r * 0.76, y - e.r * 1.34);
      ctx.lineTo(x + e.r * 0.18, y - e.r * 1.1);
      ctx.fill();
      ctx.strokeStyle = "#b78355";
      ctx.lineWidth = 3;
      ctx.beginPath();
      ctx.moveTo(x - e.r * 0.55, y + e.r * 0.35);
      ctx.lineTo(x - e.r * 0.9, y + e.r * 0.88);
      ctx.moveTo(x + e.r * 0.55, y + e.r * 0.35);
      ctx.lineTo(x + e.r * 0.9, y + e.r * 0.88);
      ctx.stroke();
    }

    ctx.fillStyle = shaman
      ? "#e3a4ef"
      : caster
        ? "#f0926b"
        : leech
          ? "#b6e5bf"
        : leaper
          ? "#f1d18a"
        : charger
          ? "#f1c271"
          : "#e1a35f";
    ctx.fillRect(x - 5, y - e.r * 0.62, 3, 3);
    ctx.fillRect(x + 3, y - e.r * 0.62, 3, 3);

    if (caster) {
      ctx.strokeStyle = "#b77870";
      ctx.lineWidth = 2;
      ctx.beginPath();
      ctx.moveTo(x + e.r, y - 4);
      ctx.lineTo(x + e.r + 7, y + e.r);
      ctx.stroke();
    }

    if (e.hp < e.maxHp) {
      ctx.fillStyle = "#171713";
      ctx.fillRect(x - e.r, y - e.r - 9, e.r * 2, 3);
      ctx.fillStyle = "#aa4939";
      ctx.fillRect(x - e.r, y - e.r - 9, (e.r * 2 * e.hp) / e.maxHp, 3);
    }
  }

  function drawProjectile(p) {
    const angle = Math.atan2(p.vy, p.vx),
      color = p.color || "#e36d5c";
    ctx.save();
    ctx.translate(p.x, p.y);
    ctx.rotate(angle);
    ctx.strokeStyle = color;
    ctx.globalAlpha = 0.72;
    ctx.lineWidth = Math.max(2, p.radius * 0.65);
    ctx.beginPath();
    ctx.moveTo(-p.radius * 3, 0);
    ctx.lineTo(-p.radius * 0.25, 0);
    ctx.stroke();
    ctx.globalAlpha = 1;
    ctx.fillStyle = color;
    ctx.shadowColor = color;
    ctx.shadowBlur = 14;
    ctx.beginPath();
    if (p.explosive) {
      arc(0, 0, p.radius + 1, 0, Math.PI * 2);
      ctx.fill();
      ctx.strokeStyle = p.specialBlast ? "#ffe18a" : "#ffd18a";
      ctx.lineWidth = 1.5;
      ctx.beginPath();
      arc(0, 0, p.radius + 3, 0, Math.PI * 2);
      ctx.stroke();
    } else if (p.team === "player") {
      ctx.moveTo(p.radius * 1.7, 0);
      ctx.lineTo(-p.radius * 0.6, -p.radius * 0.72);
      ctx.lineTo(-p.radius * 0.2, 0);
      ctx.lineTo(-p.radius * 0.6, p.radius * 0.72);
      ctx.closePath();
    } else arc(0, 0, p.radius, 0, Math.PI * 2);
    ctx.fill();
    if (p.piercing) {
      ctx.strokeStyle = "#fff0bd";
      ctx.lineWidth = 1.5;
      ctx.beginPath();
      arc(0, 0, p.radius + 2, 0, Math.PI * 2);
      ctx.stroke();
    }
    ctx.restore();
  }

  function drawLightningArc(arc) {
    ctx.save();

    ctx.globalAlpha = Math.min(1, arc.life / 0.16);

    ctx.strokeStyle = "#c6a6ff";

    ctx.shadowColor = "#a88aff";

    ctx.shadowBlur = 12;

    ctx.lineWidth = 3;

    ctx.beginPath();

    ctx.moveTo(arc.from.x, arc.from.y);

    const segments = 5;

    for (let segment = 1; segment < segments; segment++) {
      const progress = segment / segments;

      const x = arc.from.x + (arc.to.x - arc.from.x) * progress + rand(-9, 9);

      const y = arc.from.y + (arc.to.y - arc.from.y) * progress + rand(-9, 9);

      ctx.lineTo(x, y);
    }

    ctx.lineTo(arc.to.x, arc.to.y);

    ctx.stroke();

    ctx.restore();
  }

  function drawWeaponEffect(effect) {
    ctx.save();
    if (effect.kind === "hammerWave" && effect.fullCircle) {
      const progress = clamp(1 - effect.life / effect.maxLife, 0, 1),
        radius = effect.outer * progress;
      ctx.translate(effect.x, effect.y);
      ctx.globalAlpha = 1 - progress * 0.55;
      ctx.strokeStyle = "#ffe5a0";
      ctx.fillStyle = "#ffbd5b18";
      ctx.shadowColor = "#ff8b3d";
      ctx.shadowBlur = 18;
      ctx.lineWidth = 5 * (1 - progress) + 1;
      ctx.beginPath();
      arc(0, 0, radius, 0, Math.PI * 2);
      ctx.fill();
      ctx.stroke();
      for (let i = 0; i < 12; i++) {
        const angle = (i / 12) * Math.PI * 2 + progress * 0.14;
        ctx.beginPath();
        ctx.moveTo(Math.cos(angle) * radius * 0.72, Math.sin(angle) * radius * 0.72);
        ctx.lineTo(Math.cos(angle) * radius, Math.sin(angle) * radius);
        ctx.stroke();
      }
    } else if (effect.kind === "hammerShockwave") {
      const progress = clamp(1 - effect.life / effect.maxLife, 0, 1);
      ctx.translate(effect.x, effect.y);
      ctx.globalAlpha = 0.82 * (1 - progress);
      ctx.strokeStyle = "#fff0bd";
      ctx.shadowColor = "#ffd27a";
      ctx.shadowBlur = 16;
      ctx.lineWidth = 4 * (1 - progress) + 1;
      ctx.beginPath();
      arc(0, 0, effect.radius * progress, 0, Math.PI * 2);
      ctx.stroke();
    } else if (effect.kind === "sabreBurst" || effect.kind === "frostNova") {
      const progress = clamp(1 - effect.life / effect.maxLife, 0, 1),
        color = effect.kind === "frostNova" ? "#a3f4ff" : "#ffc16a";
      ctx.translate(effect.x, effect.y);
      ctx.globalAlpha = 1 - progress;
      ctx.strokeStyle = color;
      ctx.fillStyle = effect.kind === "frostNova" ? "#8cecff1a" : "#ff9c451a";
      ctx.shadowColor = color;
      ctx.shadowBlur = 18;
      ctx.lineWidth = 4 * (1 - progress) + 1;
      ctx.beginPath();
      arc(0, 0, effect.radius * progress, 0, Math.PI * 2);
      ctx.fill();
      ctx.stroke();
      for (let i = 0; i < 8; i++) {
        const angle = (i / 8) * Math.PI * 2 + progress * 0.25;
        ctx.beginPath();
        ctx.moveTo(Math.cos(angle) * effect.radius * progress * 0.55, Math.sin(angle) * effect.radius * progress * 0.55);
        ctx.lineTo(Math.cos(angle) * effect.radius * progress, Math.sin(angle) * effect.radius * progress);
        ctx.stroke();
      }
    } else if (effect.kind === "scytheWave") {
      const progress = clamp(1 - effect.life / effect.maxLife, 0, 1),
        radius = effect.radius * progress;
      ctx.translate(effect.x, effect.y);
      ctx.globalAlpha = 1 - progress;
      ctx.strokeStyle = "#c9f09e";
      ctx.shadowColor = "#a8e67e";
      ctx.shadowBlur = 18;
      ctx.lineWidth = 5 * (1 - progress) + 1;
      ctx.beginPath();
      arc(0, 0, radius, 0, Math.PI * 2);
      ctx.stroke();
      for (let i = 0; i < 8 + (effect.souls || 0) * 2; i++) {
        const angle = (i / (8 + (effect.souls || 0) * 2)) * Math.PI * 2 + progress * 0.4;
        ctx.beginPath();
        ctx.moveTo(Math.cos(angle) * radius * 0.72, Math.sin(angle) * radius * 0.72);
        ctx.lineTo(Math.cos(angle) * radius, Math.sin(angle) * radius);
        ctx.stroke();
      }
    } else if (effect.kind === "bombExplosion") {
      const progress = clamp(1 - effect.life / effect.maxLife, 0, 1),
        radius = Math.max(0, effect.radius),
        reach = radius * (1 - (1 - progress) ** 3),
        fade = 1 - progress;
      ctx.translate(effect.x, effect.y);
      ctx.globalAlpha = fade;
      ctx.fillStyle = effect.special ? "#ffb34b55" : "#ef633c44";
      ctx.strokeStyle = effect.special ? "#fff0a1" : "#ffbb68";
      ctx.shadowColor = "#ff713c";
      ctx.shadowBlur = 22;
      ctx.lineWidth = 4 * fade + 1;
      ctx.beginPath();
      arc(0, 0, reach, 0, Math.PI * 2);
      ctx.fill();
      ctx.stroke();
      ctx.strokeStyle = "#fff1c2";
      ctx.lineWidth = 2;
      for (let i = 0; i < 10; i++) {
        const angle = (i / 10) * Math.PI * 2 + progress * 0.22,
          inner = reach * (0.54 + (i % 3) * 0.07),
          outer = reach * (0.82 + (i % 2) * 0.14);
        ctx.beginPath();
        ctx.moveTo(Math.cos(angle) * inner, Math.sin(angle) * inner);
        ctx.lineTo(Math.cos(angle) * outer, Math.sin(angle) * outer);
        ctx.stroke();
      }
    } else if (effect.kind === "bombBurn") {
      const pulse = 0.94 + Math.sin(performance.now() / 40) * 0.06,
        radius = Math.max(0, effect.radius);
      ctx.translate(effect.x, effect.y);
      ctx.globalAlpha = Math.min(0.72, effect.life / effect.maxLife);
      ctx.fillStyle = "#e85d3028";
      ctx.strokeStyle = "#ffae4f";
      ctx.shadowColor = "#ff6b35";
      ctx.shadowBlur = 16;
      ctx.lineWidth = 2;
      ctx.beginPath();
      arc(0, 0, radius * pulse, 0, Math.PI * 2);
      ctx.fill();
      ctx.stroke();
      for (let i = 0; i < 7; i++) {
        const angle = performance.now() / 190 + (i / 7) * Math.PI * 2,
          distance = radius * (0.56 + (i % 3) * 0.1);
        ctx.fillStyle = i % 2 ? "#ffb04d" : "#ffe28a";
        ctx.beginPath();
        arc(Math.cos(angle) * distance, Math.sin(angle) * distance, 2, 0, Math.PI * 2);
        ctx.fill();
      }
    } else if (effect.kind === "lightningZone") {
      const pulse = 1 + Math.sin(performance.now() / 45) * 0.12;
      ctx.globalAlpha = Math.min(1, effect.life / 0.3);
      ctx.translate(effect.x, effect.y);
      ctx.strokeStyle = "#d8c4ff";
      ctx.fillStyle = "#a88aff22";
      ctx.shadowColor = "#a88aff";
      ctx.shadowBlur = 14;
      ctx.lineWidth = 3;
      ctx.beginPath();
      arc(0, 0, effect.radius * pulse, 0, Math.PI * 2);
      ctx.fill();
      ctx.stroke();
      for (let i = 0; i < 4; i++) {
        const angle = performance.now() / 170 + (i * Math.PI) / 2;
        ctx.beginPath();
        ctx.moveTo(Math.cos(angle) * 7, Math.sin(angle) * 7);
        ctx.lineTo(
          Math.cos(angle) * effect.radius * 0.8,
          Math.sin(angle) * effect.radius * 0.8,
        );
        ctx.stroke();
      }
    }
    ctx.restore();
  }

  function drawDrop(d) {
    const pulling = d.pullTime > 0;
    const speed = Math.hypot(d.vx || 0, d.vy || 0);
    ctx.save();
    ctx.translate(
      d.x,
      d.y + (pulling ? 0 : Math.sin(performance.now() / 180 + d.x) * 3),
    );
    if (pulling && speed > 0) {
      const trailX = -(d.vx || 0) / speed;
      const trailY = -(d.vy || 0) / speed;
      ctx.strokeStyle = d.type === "xp" ? "#d9a2ff" : "#d6c184";
      ctx.globalAlpha = Math.min(speed / 260, 0.65);
      ctx.lineWidth = 2;
      ctx.beginPath();
      ctx.moveTo(trailX * 15, trailY * 15);
      ctx.lineTo(trailX * 7, trailY * 7);
      ctx.stroke();
      ctx.globalAlpha = 1;
    }
    ctx.fillStyle =
      d.type === "potion"
        ? "#9c3832"
        : d.type === "xp"
          ? "#d9a2ff"
          : d.type === "weapon"
            ? "#85c5b3"
            : "#d6b765";
    ctx.shadowColor = ctx.fillStyle;
    ctx.shadowBlur = d.type === "xp" ? 28 : 10;
    const icon = dropSprites[d.type];
    if (icon?.complete && icon.naturalWidth) {
      const size = d.type === "xp" ? 24 : 22;
      ctx.drawImage(icon, -size / 2, -size / 2, size, size);
      ctx.restore();
      return;
    }
    ctx.beginPath();
    if (d.type === "potion") arc(0, 0, 6, 0, 7);
    else {
      ctx.moveTo(0, -7);
      ctx.lineTo(6, 0);
      ctx.lineTo(0, 7);
      ctx.lineTo(-6, 0);
      ctx.closePath();
    }
    ctx.fill();
    ctx.restore();
  }

  ctx = staticCtx;
  drawGround();
  drawProps();
  drawObstacles();
  ctx = screenCtx;

  return draw;
}
