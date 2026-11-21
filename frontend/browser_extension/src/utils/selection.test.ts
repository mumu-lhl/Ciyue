import { describe, it, expect } from "vitest";
import {
  calculatePopupPosition,
  checkModifierKey,
  isDomainBlacklisted,
  isEditableElement,
  isValidSelectionText,
} from "./selection";

describe("selection utilities", () => {
  describe("isValidSelectionText", () => {
    it("returns false for empty, whitespace, or invalid text", () => {
      expect(isValidSelectionText("")).toBe(false);
      expect(isValidSelectionText("   ")).toBe(false);
      expect(isValidSelectionText("\n\t")).toBe(false);
    });

    it("returns false for text exceeding 250 characters", () => {
      const longText = "a".repeat(251);
      expect(isValidSelectionText(longText)).toBe(false);
    });

    it("returns false for multi-paragraph text with double newlines", () => {
      expect(isValidSelectionText("paragraph one\n\nparagraph two")).toBe(false);
      expect(isValidSelectionText("line one\n  \nline two")).toBe(false);
    });

    it("returns true for valid words and phrases", () => {
      expect(isValidSelectionText("word")).toBe(true);
      expect(isValidSelectionText("look up")).toBe(true);
      expect(isValidSelectionText("A single line sentence without paragraph breaks.")).toBe(true);
      expect(isValidSelectionText("a".repeat(250))).toBe(true);
    });
  });

  describe("isDomainBlacklisted", () => {
    it("returns false when blacklist is empty", () => {
      expect(isDomainBlacklisted("github.com", [])).toBe(false);
    });

    it("matches exact domains case-insensitively", () => {
      expect(isDomainBlacklisted("github.com", ["github.com"])).toBe(true);
      expect(isDomainBlacklisted("GITHUB.COM", ["github.com"])).toBe(true);
      expect(isDomainBlacklisted("github.com", ["GITHUB.COM"])).toBe(true);
    });

    it("matches subdomains correctly", () => {
      expect(isDomainBlacklisted("gist.github.com", ["github.com"])).toBe(true);
      expect(isDomainBlacklisted("api.sub.github.com", ["github.com"])).toBe(true);
    });

    it("does not match partial prefix domain names", () => {
      expect(isDomainBlacklisted("notgithub.com", ["github.com"])).toBe(false);
      expect(isDomainBlacklisted("my-github.com", ["github.com"])).toBe(false);
    });

    it("cleans URL scheme, path, and port from user blacklist inputs", () => {
      expect(isDomainBlacklisted("twitter.com", ["https://twitter.com/home"])).toBe(true);
      expect(isDomainBlacklisted("localhost", ["http://localhost:3000"])).toBe(true);
      expect(isDomainBlacklisted("example.org", ["*.example.org"])).toBe(true);
    });
  });

  describe("checkModifierKey", () => {
    it("always passes when mode is none", () => {
      expect(
        checkModifierKey("none", {
          altKey: false,
          ctrlKey: false,
          metaKey: false,
          shiftKey: false,
        }),
      ).toBe(true);
      expect(checkModifierKey("none", { altKey: true })).toBe(true);
    });

    it("requires alt key when mode is alt", () => {
      expect(checkModifierKey("alt", { altKey: true })).toBe(true);
      expect(checkModifierKey("alt", { altKey: false })).toBe(false);
    });

    it("requires ctrl or meta key when mode is ctrl", () => {
      expect(checkModifierKey("ctrl", { ctrlKey: true })).toBe(true);
      expect(checkModifierKey("ctrl", { metaKey: true })).toBe(true);
      expect(checkModifierKey("ctrl", { ctrlKey: false, metaKey: false })).toBe(false);
    });

    it("requires shift key when mode is shift", () => {
      expect(checkModifierKey("shift", { shiftKey: true })).toBe(true);
      expect(checkModifierKey("shift", { shiftKey: false })).toBe(false);
    });
  });

  describe("isEditableElement", () => {
    it("returns false for null or undefined", () => {
      expect(isEditableElement(null)).toBe(false);
      expect(isEditableElement(undefined as any)).toBe(false);
    });

    it("returns true for contenteditable elements", () => {
      expect(isEditableElement({ isContentEditable: true, tagName: "DIV" })).toBe(true);
    });

    it("returns true for INPUT and TEXTAREA", () => {
      expect(isEditableElement({ tagName: "INPUT" })).toBe(true);
      expect(isEditableElement({ tagName: "input" })).toBe(true);
      expect(isEditableElement({ tagName: "TEXTAREA" })).toBe(true);
    });

    it("returns false for ordinary text elements", () => {
      expect(isEditableElement({ tagName: "DIV", isContentEditable: false })).toBe(false);
      expect(isEditableElement({ tagName: "SPAN" })).toBe(false);
      expect(isEditableElement({ tagName: "P" })).toBe(false);
    });
  });

  describe("calculatePopupPosition", () => {
    it("calculates position offset from mouse coordinates", () => {
      const pos = calculatePopupPosition(100, 200, 1920, 1080, 0, 440, 440);
      expect(pos.x).toBe(100);
      expect(pos.y).toBe(215); // 200 + 15
    });

    it("clamps to left edge padding when mouse is near 0", () => {
      const pos = calculatePopupPosition(5, 100, 1920, 1080, 0, 440, 440);
      expect(pos.x).toBe(16);
    });

    it("clamps to right edge when popup would overflow viewport", () => {
      const pos = calculatePopupPosition(1800, 100, 1920, 1080, 0, 440, 440);
      expect(pos.x).toBe(1920 - 440 - 16);
    });

    it("flips popup above cursor when near the bottom of the viewport", () => {
      const pos = calculatePopupPosition(100, 900, 1920, 1080, 0, 440, 440);
      expect(pos.y).toBe(900 - 440); // 460
    });
  });
});
