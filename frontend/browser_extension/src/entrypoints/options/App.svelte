<script lang="ts">
  import { onMount } from "svelte";
  import BookOpen from "@lucide/svelte/icons/book-open";
  import Server from "@lucide/svelte/icons/server";
  import Palette from "@lucide/svelte/icons/palette";
  import MousePointerClick from "@lucide/svelte/icons/mouse-pointer-click";
  import ShieldAlert from "@lucide/svelte/icons/shield-alert";
  import CircleCheck from "@lucide/svelte/icons/circle-check";
  import CircleAlert from "@lucide/svelte/icons/circle-alert";
  import LoaderCircle from "@lucide/svelte/icons/loader-circle";
  import Save from "@lucide/svelte/icons/save";
  import Check from "@lucide/svelte/icons/check";
  import Sun from "@lucide/svelte/icons/sun";
  import Moon from "@lucide/svelte/icons/moon";
  import SunMoon from "@lucide/svelte/icons/sun-moon";
  import Globe from "@lucide/svelte/icons/globe";
  import { getSettings, saveSettings } from "../../utils/settings";
  import { CiyueApiClient } from "../../api/client";
  import {
    THEME_OPTIONS,
    applyThemeColor,
    applyThemeMode,
    getThemeName,
  } from "../../utils/theme";
  import { t, i18n } from "../../utils/i18n.svelte";
  import type { ExtensionSettings } from "../../api/types";

  let form = $state<ExtensionSettings>({
    serverUrl: "http://127.0.0.1:47117",
    themeColor: "blue",
    themeMode: "auto",
    locale: "auto",
    enableSelection: true,
    enableDoubleClick: false,
    requireModifierKey: "none",
    excludeEditable: true,
    blacklistUrls: [],
  });

  let blacklistText = $state("");
  let testing = $state(false);
  let testResult = $state<{
    status: "success" | "error";
    message: string;
  } | null>(null);
  let savedToast = $state(false);

  onMount(async () => {
    const current = await getSettings();
    form = { ...current };
    blacklistText = (form.blacklistUrls || []).join("\n");
    applyThemeColor(form.themeColor);
    applyThemeMode(form.themeMode);
    i18n.setLocalePreference(form.locale ?? "auto");

    if (typeof window !== "undefined" && window.matchMedia) {
      const media = window.matchMedia("(prefers-color-scheme: dark)");
      const listener = () => {
        if (form.themeMode === "auto") {
          applyThemeMode("auto");
        }
      };
      media.addEventListener("change", listener);
      return () => media.removeEventListener("change", listener);
    }
  });

  async function testConnection() {
    testing = true;
    testResult = null;

    try {
      const client = new CiyueApiClient(form.serverUrl);
      const status = await client.getStatus();
      testResult = {
        status: "success",
        message: t("extensionOptions.testConnSuccess", {
          count: status.dictionariesCount || 0,
        }),
      };
    } catch (err: any) {
      testResult = {
        status: "error",
        message: t("extensionOptions.testConnFailed", {
          error: err.message || t("common.error"),
        }),
      };
    } finally {
      testing = false;
    }
  }

  async function save() {
    form.blacklistUrls = blacklistText
      .split("\n")
      .map((s) => s.trim())
      .filter(Boolean);

    await saveSettings(form);

    savedToast = true;
    setTimeout(() => {
      savedToast = false;
    }, 2500);
  }
</script>

<div
  data-theme={form.themeColor}
  class="min-h-screen bg-zinc-50 dark:bg-zinc-950 text-zinc-900 dark:text-zinc-100 py-10 px-4 font-sans antialiased flex justify-center"
>
  <div class="w-full max-w-2xl flex flex-col gap-6">
    <!-- Header -->
    <header class="flex items-center gap-3 pb-2">
      <div
        class="w-10 h-10 rounded-xl bg-primary-600/10 dark:bg-primary-400/10 flex items-center justify-center text-primary-600 dark:text-primary-400 shrink-0"
      >
        <BookOpen class="w-5 h-5" />
      </div>
      <div>
        <h1
          class="text-lg font-bold text-zinc-900 dark:text-zinc-100 tracking-tight"
        >
          {t("extensionOptions.extSettingsTitle")}
        </h1>
        <p class="text-xs text-zinc-500 dark:text-zinc-400">
          {t("extensionOptions.extSettingsDesc")}
        </p>
      </div>
    </header>

    <!-- Card 1: Appearance & Theme Color & Language -->
    <section
      class="bg-white dark:bg-zinc-900 border border-zinc-200/90 dark:border-zinc-800 rounded-2xl p-6 shadow-xs flex flex-col gap-5"
    >
      <div
        class="flex items-center gap-2 text-sm font-bold text-zinc-900 dark:text-zinc-100"
      >
        <Palette class="w-4 h-4 text-primary-600 dark:text-primary-400" />
        <h2>{t("theme.appearanceTitle")}</h2>
      </div>

      <!-- Theme Mode -->
      <div class="flex flex-col gap-2.5">
        <span class="text-xs font-semibold text-zinc-700 dark:text-zinc-300">
          {t("theme.modeTitle")}
        </span>
        <p class="text-[11px] text-zinc-400">
          {t("theme.modeDesc")}
        </p>

        <div class="grid grid-cols-3 gap-2.5 pt-1">
          <button
            type="button"
            class="flex items-center gap-2.5 p-2.5 rounded-xl border text-left cursor-pointer transition-all {form.themeMode ===
            'auto'
              ? 'border-primary-600 bg-primary-50/50 dark:bg-primary-950/30 ring-2 ring-primary-500/20 text-zinc-900 dark:text-zinc-100 font-semibold'
              : 'border-zinc-200 dark:border-zinc-800 hover:bg-zinc-50 dark:hover:bg-zinc-800/50 text-zinc-700 dark:text-zinc-300'}"
            onclick={() => {
              form.themeMode = "auto";
              applyThemeMode("auto");
            }}
          >
            <SunMoon
              class="w-4 h-4 text-primary-600 dark:text-primary-400 shrink-0"
            />
            <span class="text-xs font-medium">{t("theme.modeAuto")}</span>
          </button>

          <button
            type="button"
            class="flex items-center gap-2.5 p-2.5 rounded-xl border text-left cursor-pointer transition-all {form.themeMode ===
            'light'
              ? 'border-primary-600 bg-primary-50/50 dark:bg-primary-950/30 ring-2 ring-primary-500/20 text-zinc-900 dark:text-zinc-100 font-semibold'
              : 'border-zinc-200 dark:border-zinc-800 hover:bg-zinc-50 dark:hover:bg-zinc-800/50 text-zinc-700 dark:text-zinc-300'}"
            onclick={() => {
              form.themeMode = "light";
              applyThemeMode("light");
            }}
          >
            <Sun class="w-4 h-4 text-amber-500 shrink-0" />
            <span class="text-xs font-medium">{t("theme.modeLight")}</span>
          </button>

          <button
            type="button"
            class="flex items-center gap-2.5 p-2.5 rounded-xl border text-left cursor-pointer transition-all {form.themeMode ===
            'dark'
              ? 'border-primary-600 bg-primary-50/50 dark:bg-primary-950/30 ring-2 ring-primary-500/20 text-zinc-900 dark:text-zinc-100 font-semibold'
              : 'border-zinc-200 dark:border-zinc-800 hover:bg-zinc-50 dark:hover:bg-zinc-800/50 text-zinc-700 dark:text-zinc-300'}"
            onclick={() => {
              form.themeMode = "dark";
              applyThemeMode("dark");
            }}
          >
            <Moon class="w-4 h-4 text-indigo-400 shrink-0" />
            <span class="text-xs font-medium">{t("theme.modeDark")}</span>
          </button>
        </div>
      </div>

      <!-- Language Preference -->
      <div
        class="flex flex-col gap-2.5 pt-1 border-t border-zinc-100 dark:border-zinc-800/80"
      >
        <span class="text-xs font-semibold text-zinc-700 dark:text-zinc-300">
          {t("language.title")}
        </span>
        <p class="text-[11px] text-zinc-400">
          {t("language.desc")}
        </p>

        <div class="grid grid-cols-3 gap-2.5 pt-1">
          <button
            type="button"
            class="flex items-center gap-2.5 p-2.5 rounded-xl border text-left cursor-pointer transition-all {form.locale ===
            'auto'
              ? 'border-primary-600 bg-primary-50/50 dark:bg-primary-950/30 ring-2 ring-primary-500/20 text-zinc-900 dark:text-zinc-100 font-semibold'
              : 'border-zinc-200 dark:border-zinc-800 hover:bg-zinc-50 dark:hover:bg-zinc-800/50 text-zinc-700 dark:text-zinc-300'}"
            onclick={() => {
              form.locale = "auto";
              i18n.setLocalePreference("auto");
            }}
          >
            <Globe
              class="w-4 h-4 text-primary-600 dark:text-primary-400 shrink-0"
            />
            <span class="text-xs font-medium">{t("language.auto")}</span>
          </button>

          <button
            type="button"
            class="flex items-center gap-2.5 p-2.5 rounded-xl border text-left cursor-pointer transition-all {form.locale ===
            'zh'
              ? 'border-primary-600 bg-primary-50/50 dark:bg-primary-950/30 ring-2 ring-primary-500/20 text-zinc-900 dark:text-zinc-100 font-semibold'
              : 'border-zinc-200 dark:border-zinc-800 hover:bg-zinc-50 dark:hover:bg-zinc-800/50 text-zinc-700 dark:text-zinc-300'}"
            onclick={() => {
              form.locale = "zh";
              i18n.setLocalePreference("zh");
            }}
          >
            <span
              class="w-4 h-4 flex items-center justify-center font-bold text-xs text-primary-600 dark:text-primary-400 shrink-0"
              >中</span
            >
            <span class="text-xs font-medium">{t("language.zh")}</span>
          </button>

          <button
            type="button"
            class="flex items-center gap-2.5 p-2.5 rounded-xl border text-left cursor-pointer transition-all {form.locale ===
            'en'
              ? 'border-primary-600 bg-primary-50/50 dark:bg-primary-950/30 ring-2 ring-primary-500/20 text-zinc-900 dark:text-zinc-100 font-semibold'
              : 'border-zinc-200 dark:border-zinc-800 hover:bg-zinc-50 dark:hover:bg-zinc-800/50 text-zinc-700 dark:text-zinc-300'}"
            onclick={() => {
              form.locale = "en";
              i18n.setLocalePreference("en");
            }}
          >
            <span
              class="w-4 h-4 flex items-center justify-center font-bold text-xs text-primary-600 dark:text-primary-400 shrink-0"
              >EN</span
            >
            <span class="text-xs font-medium">{t("language.en")}</span>
          </button>
        </div>
      </div>

      <!-- Theme Color -->
      <div
        class="flex flex-col gap-2.5 pt-1 border-t border-zinc-100 dark:border-zinc-800/80"
      >
        <span class="text-xs font-semibold text-zinc-700 dark:text-zinc-300">
          {t("theme.colorTitle")}
        </span>
        <p class="text-[11px] text-zinc-400">
          {t("theme.colorDesc")}
        </p>

        <div class="grid grid-cols-2 sm:grid-cols-3 gap-2.5 pt-1">
          {#each THEME_OPTIONS as opt (opt.id)}
            <button
              type="button"
              class="flex items-center gap-2.5 p-2.5 rounded-xl border text-left cursor-pointer transition-all {form.themeColor ===
              opt.id
                ? 'border-primary-600 bg-primary-50/50 dark:bg-primary-950/30 ring-2 ring-primary-500/20 text-zinc-900 dark:text-zinc-100 font-semibold'
                : 'border-zinc-200 dark:border-zinc-800 hover:bg-zinc-50 dark:hover:bg-zinc-800/50 text-zinc-700 dark:text-zinc-300'}"
              onclick={() => {
                form.themeColor = opt.id;
                applyThemeColor(opt.id);
              }}
            >
              <span
                class="w-5 h-5 rounded-full shrink-0 flex items-center justify-center text-white shadow-xs transition-transform duration-150 {form.themeColor ===
                opt.id
                  ? 'scale-110'
                  : ''}"
                style:background-color={opt.primaryHex}
              >
                {#if form.themeColor === opt.id}
                  <Check class="w-3 h-3 stroke-[3]" />
                {/if}
              </span>
              <span class="text-xs truncate"
                >{getThemeName(opt.id, i18n.currentLocale)}</span
              >
            </button>
          {/each}
        </div>
      </div>
    </section>

    <!-- Card 2: Desktop Connection -->
    <section
      class="bg-white dark:bg-zinc-900 border border-zinc-200/90 dark:border-zinc-800 rounded-2xl p-6 shadow-xs flex flex-col gap-4"
    >
      <div
        class="flex items-center gap-2 text-sm font-bold text-zinc-900 dark:text-zinc-100"
      >
        <Server class="w-4 h-4 text-primary-600 dark:text-primary-400" />
        <h2>{t("extensionOptions.serverConnection")}</h2>
      </div>

      <div class="flex flex-col gap-2">
        <label
          for="server-url"
          class="text-xs font-semibold text-zinc-700 dark:text-zinc-300"
        >
          {t("extensionOptions.serverUrl")}
        </label>
        <p class="text-[11px] text-zinc-400">
          {t("extensionOptions.serverUrlDesc")}
        </p>
        <div class="flex gap-2">
          <input
            id="server-url"
            type="text"
            bind:value={form.serverUrl}
            placeholder="http://127.0.0.1:47117"
            class="flex-1 px-3.5 py-2 rounded-xl border border-zinc-200 dark:border-zinc-750 bg-zinc-50/70 dark:bg-zinc-800/60 text-xs text-zinc-900 dark:text-zinc-100 outline-none focus:border-primary-500 focus:ring-2 focus:ring-primary-500/15 transition-all"
          />
          <button
            class="px-4 py-2 rounded-xl bg-zinc-100 hover:bg-zinc-200/80 dark:bg-zinc-800 dark:hover:bg-zinc-700 text-zinc-700 dark:text-zinc-200 text-xs font-semibold border border-zinc-200 dark:border-zinc-700 transition-all cursor-pointer flex items-center gap-1.5 shrink-0 disabled:opacity-60"
            disabled={testing}
            onclick={testConnection}
          >
            {#if testing}
              <LoaderCircle class="w-3.5 h-3.5 animate-spin" />
              <span>{t("common.testing")}</span>
            {:else}
              <span>{t("common.test")}</span>
            {/if}
          </button>
        </div>

        {#if testResult}
          <div
            class="mt-2 p-3 rounded-xl flex items-start gap-2 text-xs {testResult.status ===
            'success'
              ? 'bg-emerald-50 dark:bg-emerald-950/30 text-emerald-700 dark:text-emerald-300 border border-emerald-200/60 dark:border-emerald-800/60'
              : 'bg-rose-50 dark:bg-rose-950/30 text-rose-700 dark:text-rose-300 border border-rose-200/60 dark:border-rose-800/60'}"
          >
            {#if testResult.status === "success"}
              <CircleCheck class="w-4 h-4 shrink-0 mt-0.5 text-emerald-500" />
            {:else}
              <CircleAlert class="w-4 h-4 shrink-0 mt-0.5 text-rose-500" />
            {/if}
            <span>{testResult.message}</span>
          </div>
        {/if}
      </div>
    </section>

    <!-- Card 3: Trigger Interaction -->
    <section
      class="bg-white dark:bg-zinc-900 border border-zinc-200/90 dark:border-zinc-800 rounded-2xl p-6 shadow-xs flex flex-col gap-5"
    >
      <div
        class="flex items-center gap-2 text-sm font-bold text-zinc-900 dark:text-zinc-100"
      >
        <MousePointerClick
          class="w-4 h-4 text-primary-600 dark:text-primary-400"
        />
        <h2>{t("extensionOptions.selectionBehavior")}</h2>
      </div>

      <div
        class="flex flex-col gap-4 divide-y divide-zinc-100 dark:divide-zinc-800"
      >
        <div class="flex items-start justify-between gap-4 pt-1">
          <div>
            <span
              class="text-xs font-semibold text-zinc-800 dark:text-zinc-200 block"
            >
              {t("extensionOptions.enableSelection")}
            </span>
            <span class="text-[11px] text-zinc-400">
              {t("extensionOptions.enableSelectionDesc")}
            </span>
          </div>
          <input
            type="checkbox"
            bind:checked={form.enableSelection}
            class="w-4 h-4 rounded text-primary-600 accent-primary-600 cursor-pointer shrink-0 mt-1"
          />
        </div>

        <div class="flex items-start justify-between gap-4 pt-4">
          <div>
            <span
              class="text-xs font-semibold text-zinc-800 dark:text-zinc-200 block"
            >
              {t("extensionOptions.enableDoubleClick")}
            </span>
            <span class="text-[11px] text-zinc-400">
              {t("extensionOptions.enableDoubleClickDesc")}
            </span>
          </div>
          <input
            type="checkbox"
            bind:checked={form.enableDoubleClick}
            class="w-4 h-4 rounded text-primary-600 accent-primary-600 cursor-pointer shrink-0 mt-1"
          />
        </div>

        <div class="flex flex-col gap-2 pt-4">
          <label
            for="modifier-key"
            class="text-xs font-semibold text-zinc-800 dark:text-zinc-200"
          >
            {t("extensionOptions.modifierKey")}
          </label>
          <span class="text-[11px] text-zinc-400">
            {t("extensionOptions.modifierKeyDesc")}
          </span>
          <select
            id="modifier-key"
            bind:value={form.requireModifierKey}
            class="px-3 py-2 rounded-xl border border-zinc-200 dark:border-zinc-750 bg-zinc-50/70 dark:bg-zinc-800/60 text-xs text-zinc-800 dark:text-zinc-200 outline-none cursor-pointer max-w-sm"
          >
            <option value="none">{t("extensionOptions.modNone")}</option>
            <option value="alt">{t("extensionOptions.modAlt")}</option>
            <option value="ctrl">{t("extensionOptions.modCtrl")}</option>
            <option value="shift">{t("extensionOptions.modShift")}</option>
          </select>
        </div>

        <div class="flex items-start justify-between gap-4 pt-4">
          <div>
            <span
              class="text-xs font-semibold text-zinc-800 dark:text-zinc-200 block"
            >
              {t("extensionOptions.excludeEditable")}
            </span>
            <span class="text-[11px] text-zinc-400">
              {t("extensionOptions.excludeEditableDesc")}
            </span>
          </div>
          <input
            type="checkbox"
            bind:checked={form.excludeEditable}
            class="w-4 h-4 rounded text-primary-600 accent-primary-600 cursor-pointer shrink-0 mt-1"
          />
        </div>
      </div>
    </section>

    <!-- Card 4: Blacklist -->
    <section
      class="bg-white dark:bg-zinc-900 border border-zinc-200/90 dark:border-zinc-800 rounded-2xl p-6 shadow-xs flex flex-col gap-4"
    >
      <div
        class="flex items-center gap-2 text-sm font-bold text-zinc-900 dark:text-zinc-100"
      >
        <ShieldAlert class="w-4 h-4 text-primary-600 dark:text-primary-400" />
        <h2>{t("extensionOptions.blacklist")}</h2>
      </div>

      <div class="flex flex-col gap-2">
        <label
          for="blacklist"
          class="text-xs font-semibold text-zinc-700 dark:text-zinc-300"
        >
          {t("extensionOptions.blacklist")}
        </label>
        <span class="text-[11px] text-zinc-400">
          {t("extensionOptions.blacklistDesc")}
        </span>
        <textarea
          id="blacklist"
          rows="4"
          bind:value={blacklistText}
          placeholder={t("extensionOptions.blacklistPlaceholder")}
          class="w-full p-3 rounded-xl border border-zinc-200 dark:border-zinc-750 bg-zinc-50/70 dark:bg-zinc-800/60 font-mono text-xs text-zinc-800 dark:text-zinc-200 outline-none focus:border-primary-500 focus:ring-2 focus:ring-primary-500/15 transition-all resize-y"
        ></textarea>
      </div>
    </section>

    <!-- Footer Actions -->
    <div class="flex items-center justify-end gap-3 pb-8">
      {#if savedToast}
        <div
          class="flex items-center gap-1.5 text-xs text-emerald-600 dark:text-emerald-400 font-semibold animate-fade-in"
        >
          <CircleCheck class="w-4 h-4" />
          <span>{t("common.saved")}</span>
        </div>
      {/if}

      <button
        class="px-5 py-2.5 rounded-xl bg-primary-600 hover:bg-primary-700 active:scale-95 text-white text-xs font-semibold shadow-xs shadow-primary-500/20 cursor-pointer transition-all flex items-center gap-1.5"
        onclick={save}
      >
        <Save class="w-4 h-4" />
        <span>{t("common.save")}</span>
      </button>
    </div>
  </div>
</div>
