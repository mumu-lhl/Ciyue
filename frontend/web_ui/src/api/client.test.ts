import { describe, it, expect } from "vitest";
import { api, CiyueWebApiClient } from "./client";

describe("web_ui api client", () => {
  it("initializes CiyueWebApiClient default instance", () => {
    expect(api).toBeInstanceOf(CiyueWebApiClient);
    expect(api.getServerUrl()).toBe("");
  });
});
