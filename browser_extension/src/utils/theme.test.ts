import { describe, it, expect } from "vitest";
import { THEME_OPTIONS, isValidThemeColor, getThemeOption } from "./theme";

describe("theme utility", () => {
  it("has blue as default recommended theme", () => {
    const defaultTheme = THEME_OPTIONS.find((t) => t.isDefault);
    expect(defaultTheme).toBeDefined();
    expect(defaultTheme?.id).toBe("blue");
  });

  it("validates theme colors properly", () => {
    expect(isValidThemeColor("blue")).toBe(true);
    expect(isValidThemeColor("violet")).toBe(true);
    expect(isValidThemeColor("emerald")).toBe(true);
    expect(isValidThemeColor("invalid-color")).toBe(false);
  });

  it("returns correct theme option fallback", () => {
    expect(getThemeOption("violet").name).toBe("极光紫");
    expect(getThemeOption("blue").name).toBe("经典蓝");
    // @ts-expect-error test fallback
    expect(getThemeOption("unknown").id).toBe("blue");
  });
});
