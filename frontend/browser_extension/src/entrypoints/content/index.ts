import { defineContentScript } from "wxt/utils/define-content-script";
import { createShadowRootUi } from "wxt/utils/content-script-ui/shadow-root";
import { mount, unmount } from "svelte";
import ContentPopup from "./ContentPopup.svelte";
import styleText from "./style.css?inline";
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
            themeColor: settings.themeColor,
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
      if (isDomainBlacklisted(window.location.href, settings.blacklistUrls)) return;
      if (!settings.enableSelection) return;
      if (!checkModifierKey(settings.requireModifierKey, e)) return;
      if (settings.excludeEditable && isEditableElement(e.target as Element)) return;

      setTimeout(() => {
        const selection = window.getSelection();
        const text = selection ? selection.toString() : "";

        if (!isValidSelectionText(text)) {
          popupInstance?.hideTrigger();
          return;
        }

        try {
          const range = selection!.getRangeAt(0);
          const rect = range.getBoundingClientRect();
          const triggerX = rect.right + window.scrollX + 8;
          const triggerY = rect.bottom + window.scrollY - 8;

          popupInstance?.displayTrigger(triggerX, triggerY, text.trim());
        } catch {
          popupInstance?.hideTrigger();
        }
      }, 50);
    });

    // Handle double click
    document.addEventListener("dblclick", (e) => {
      if (isDomainBlacklisted(window.location.href, settings.blacklistUrls)) return;
      if (!settings.enableDoubleClick) return;
      if (settings.excludeEditable && isEditableElement(e.target as Element)) return;

      setTimeout(() => {
        const selection = window.getSelection();
        const text = selection ? selection.toString().trim() : "";

        if (isValidSelectionText(text)) {
          popupInstance?.openCard(text, e.clientX + window.scrollX, e.clientY + window.scrollY);
        }
      }, 30);
    });

    // Global click dismisses floating trigger
    document.addEventListener("mousedown", (e) => {
      const host = document.querySelector("ciyue-extension-host");
      if (host && host.shadowRoot && host.shadowRoot.contains(e.target as Node)) {
        return;
      }
      popupInstance?.hideTrigger();
    });
  },
});
