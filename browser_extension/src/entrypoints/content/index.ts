import { defineContentScript } from "wxt/utils/define-content-script";
import { createShadowRootUi } from "wxt/utils/content-script-ui/shadow-root";
import { mount, unmount } from "svelte";
import ContentPopup from "./ContentPopup.svelte";
import styleText from "./style.css?raw";
import { getSettings, onSettingsChanged } from "../../utils/settings";
import {
  checkModifierKey,
  isDomainBlacklisted,
  isEditableElement,
  isValidSelectionText,
} from "../../utils/selection";
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

    // Handle mouse selection
    document.addEventListener("mouseup", (e) => {
      if (!settings.enableSelection) return;
      if (isDomainBlacklisted(window.location.hostname, settings.blacklistUrls)) return;
      if (settings.excludeEditable && isEditableElement(e.target as any)) return;
      if (!checkModifierKey(settings.requireModifierKey, e)) return;

      setTimeout(() => {
        const sel = window.getSelection();
        const text = sel ? sel.toString().trim() : "";

        if (isValidSelectionText(text)) {
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
      if (!settings.enableDoubleClick) return;
      if (isDomainBlacklisted(window.location.hostname, settings.blacklistUrls)) return;
      if (settings.excludeEditable && isEditableElement(e.target as any)) return;

      const sel = window.getSelection();
      const text = sel ? sel.toString().trim() : "";
      if (isValidSelectionText(text) && text.length <= 50) {
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
