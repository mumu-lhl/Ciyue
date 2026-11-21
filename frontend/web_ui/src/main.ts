import { mount } from "svelte";
import App from "./App.svelte";
import {
  applyThemeColor,
  applyThemeMode,
  getStoredThemeColor,
  getStoredThemeMode,
} from "@ciyue/shared";
import "./styles/app.css";

applyThemeMode(getStoredThemeMode());
applyThemeColor(getStoredThemeColor());

mount(App, {
  target: document.getElementById("app")!,
});
