import type { ModifierKey } from "../api/types";

export function isValidSelectionText(text: string): boolean {
  if (!text) return false;
  const trimmed = text.trim();
  if (trimmed.length < 1 || trimmed.length > 250) return false;
  // Ignore multi-paragraph blocks
  if (/\n\s*\n/.test(trimmed)) return false;
  return true;
}

export function isDomainBlacklisted(hostname: string, blacklist: string[]): boolean {
  if (!hostname || !blacklist || blacklist.length === 0) return false;
  const targetHost = hostname.trim().toLowerCase();

  return blacklist.some((item) => {
    let clean = item.trim().toLowerCase();
    if (!clean) return false;
    // Strip leading wildcard or scheme if user pasted full URL
    clean = clean.replace(/^[a-z]+:\/\//, "").replace(/^\*\./, "");
    const hostPart = clean.split("/")[0] ?? "";
    clean = hostPart.split(":")[0] ?? "";

    if (targetHost === clean) return true;
    if (targetHost.endsWith("." + clean)) return true;
    return false;
  });
}

export function checkModifierKey(
  mode: ModifierKey,
  event: { altKey?: boolean; ctrlKey?: boolean; metaKey?: boolean; shiftKey?: boolean },
): boolean {
  switch (mode) {
    case "alt":
      return !!event.altKey;
    case "ctrl":
      return !!(event.ctrlKey || event.metaKey);
    case "shift":
      return !!event.shiftKey;
    case "none":
    default:
      return true;
  }
}

export function isEditableElement(
  el: { isContentEditable?: boolean; tagName?: string } | null,
): boolean {
  if (!el) return false;
  if (el.isContentEditable) return true;
  const tag = (el.tagName || "").toUpperCase();
  return tag === "INPUT" || tag === "TEXTAREA";
}

export function calculatePopupPosition(
  x: number,
  y: number,
  viewportWidth: number,
  viewportHeight: number,
  scrollY: number = 0,
  cardWidth: number = 440,
  cardHeight: number = 440,
): { x: number; y: number } {
  const padding = 16;
  const posX = Math.max(padding, Math.min(x, viewportWidth - cardWidth - padding));

  let posY = y + 15;
  if (posY + cardHeight > viewportHeight + scrollY) {
    posY = Math.max(10, y - cardHeight);
  }

  return { x: posX, y: posY };
}
