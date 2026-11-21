import { describe, it, expect } from "vitest";
import { splitEntryDoctype, parseEntryLink, ciyueDecode } from "./entry";

describe("entry utilities", () => {
  describe("splitEntryDoctype", () => {
    it("handles standards mode HTML5 doctype", () => {
      const res = splitEntryDoctype("<!DOCTYPE html>\n<p>definition</p>");
      expect(res.doctype).toBe("<!DOCTYPE html>");
      expect(res.content).toBe("\n<p>definition</p>");
    });

    it("handles leading comments before doctype", () => {
      const res = splitEntryDoctype("<!-- archived page -->\n<!DOCTYPE html>\n<p>wiki</p>");
      expect(res.doctype).toBe("<!-- archived page -->\n<!DOCTYPE html>");
      expect(res.content).toBe("\n<p>wiki</p>");
    });

    it("returns empty doctype when absent", () => {
      const res = splitEntryDoctype("<html><body>test</body></html>");
      expect(res.doctype).toBe("");
      expect(res.content).toBe("<html><body>test</body></html>");
    });
  });

  describe("parseEntryLink", () => {
    it("parses normal entry without anchor", () => {
      expect(parseEntryLink("apple")).toEqual({ word: "apple", anchor: "" });
    });

    it("parses entry with anchor", () => {
      expect(parseEntryLink("verb#transitive")).toEqual({ word: "verb", anchor: "transitive" });
    });

    it("handles escaped literal hash", () => {
      expect(parseEntryLink("C##")).toEqual({ word: "C#", anchor: "" });
      expect(parseEntryLink("C###intro")).toEqual({ word: "C#", anchor: "intro" });
    });
  });

  describe("ciyueDecode", () => {
    it("decodes encoded uri components", () => {
      expect(ciyueDecode("%E8%AF%8D%E6%82%A6")).toBe("词悦");
    });

    it("gracefully falls back on malformed input", () => {
      expect(ciyueDecode("%E0%A4%A")).toBe("%E0%A4%A");
    });
  });
});
