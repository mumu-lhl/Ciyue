import { defineContentScript } from "wxt/utils/define-content-script";
import { createShadowRootUi } from "wxt/utils/content-script-ui/shadow-root";
import { mount, unmount } from "svelte";
import ContentPopup from "./ContentPopup.svelte";
import styleText from "./style.css?raw";
import { getSettings, onSettingsChanged } from "../../utils/settings";
import type { ExtensionSettings } from "../../api/types";

export default defineContentScript({
  matches: ["<all_urls>"],
  async main(ctx) {
    let settings: ExtensionSettings = await getSettings();
    onSettingsChanged((newSettings) => {
      settings = newSettings;
    });

    let popupInstance: any = null;

    const ui = await createShadowRootUi(ctx, {
      name: "ciyue-extension-host",
      position: "overlay",
      anchor: "html",
      append: "last",
      css: styleText,
      onMount: (container) => {
        popupInstance = mount(ContentPopup, {
          target: container,
          props: {
            serverUrl: settings.serverUrl,
          },
        });
        return popupInstance;
      },
      onRemove: (appInstance) => {
        if (appInstance) {
          unmount(appInstance);
        }
      },
    });

    ui.mount();

    function isBlacklisted(): boolean {
      const currentHost = window.location.hostname;
      return settings.blacklistUrls.some((domain) => {
        const clean = domain.trim().toLowerCase();
        return clean && (currentHost === clean || currentHost.endsWith("." + clean));
      });
    }

    function checkModifier(e: MouseEvent): boolean {
      if (settings.requireModifierKey === "alt") return e.altKey;
      if (settings.requireModifierKey === "ctrl") return e.ctrlKey || e.metaKey;
      if (settings.requireModifierKey === "shift") return e.shiftKey;
      return true;
    }

    function isEditableElement(el: EventTarget | null): boolean {
      if (!el || !(el instanceof HTMLElement)) return false;
      if (el.isContentEditable) return true;
      const tag = el.tagName.toUpperCase();
      return tag === "INPUT" || tag === "TEXTAREA";
    }

    // Handle mouse selection
    document.addEventListener("mouseup", (e) => {
      if (isBlacklisted() || !settings.enableSelection) return;
      if (settings.excludeEditable && isEditableElement(e.target)) return;
      if (!checkModifier(e)) return;

      setTimeout(() => {
        const sel = window.getSelection();
        const text = sel ? sel.toString().trim() : "";

        if (text && text.length >= 1 && text.length <= 250 && !/\n\n/.test(text)) {
          if (popupInstance) {
            popupInstance.displayTrigger(e.pageX + 8, e.pageY + 10, text);
          }
        } else {
          if (popupInstance) {
            popupInstance.hideTrigger();
          }
        }
      }, 10);
    });

    // Handle double-click lookup
    document.addEventListener("dblclick", (e) => {
      if (isBlacklisted() || !settings.enableDoubleClick) return;
      if (settings.excludeEditable && isEditableElement(e.target)) return;

      const sel = window.getSelection();
      const text = sel ? sel.toString().trim() : "";
      if (text && text.length >= 1 && text.length <= 50) {
        if (popupInstance) {
          popupInstance.openCard(text, e.pageX + 10, e.pageY + 10);
        }
      }
    });

    // Dismiss on outside mousedown
    document.addEventListener("mousedown", (e) => {
      if (ui.shadowHost && e.composedPath().includes(ui.shadowHost)) return;
      if (popupInstance) {
        popupInstance.hideTrigger();
      }
    });

    // Dismiss on Escape
    document.addEventListener("keydown", (e) => {
      if (e.key === "Escape") {
        if (popupInstance) {
          popupInstance.hideTrigger();
          popupInstance.closeCard();
        }
      }
    });

    // Messages from background (context menu / hotkeys)
    chrome.runtime.onMessage.addListener((msg) => {
      if (msg.type === "CIYUE_LOOKUP" && msg.word) {
        if (popupInstance) {
          popupInstance.openCard(msg.word, window.innerWidth / 2 - 220, 100);
        }
      } else if (msg.type === "CIYUE_TRIGGER_HOTKEY") {
        const sel = window.getSelection();
        const text = sel ? sel.toString().trim() : "";
        if (text && popupInstance) {
          popupInstance.openCard(text, window.innerWidth / 2 - 220, 100);
        }
      }
    });
  },
});
