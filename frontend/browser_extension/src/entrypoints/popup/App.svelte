<script lang="ts">
  import { onMount, onDestroy } from "svelte";
  import BookOpen from "@lucide/svelte/icons/book-open";
  import Settings from "@lucide/svelte/icons/settings";
  import Search from "@lucide/svelte/icons/search";
  import Sparkles from "@lucide/svelte/icons/sparkles";
  import Languages from "@lucide/svelte/icons/languages";
  import WifiOff from "@lucide/svelte/icons/wifi-off";
  import LoaderCircle from "@lucide/svelte/icons/loader-circle";
  import X from "@lucide/svelte/icons/x";
  import Sun from "@lucide/svelte/icons/sun";
  import Moon from "@lucide/svelte/icons/moon";
  import SunMoon from "@lucide/svelte/icons/sun-moon";
  import WordHeader from "../../components/WordHeader.svelte";
  import DictCard from "../../components/DictCard.svelte";
  import AiView from "../../components/AiView.svelte";
  import { CiyueApiClient } from "../../api/client";
  import {
    getSettings,
    onSettingsChanged,
    saveSettings,
  } from "../../utils/settings";
  import { applyThemeColor, applyThemeMode } from "../../utils/theme";
  import { t, i18n } from "../../utils/i18n.svelte";
  import type {
    DictionaryResult,
    GroupItem,
    ThemeColor,
    ThemeMode,
  } from "../../api/types";

  let serverUrl = $state("http://127.0.0.1:47117");
  let themeColor = $state<ThemeColor>("blue");
  let themeMode = $state<ThemeMode>("auto");
  let serverOnline = $state(false);
  let groups = $state<GroupItem[]>([]);
  let currentGroupId = $state("");

  let searchQuery = $state("");
  let suggestions = $state<string[]>([]);

  let lookupWord = $state("");
  let activeTab = $state<"dicts" | "ai-explain" | "ai-translate">("dicts");
  let loading = $state(false);
  let isStared = $state(false);
  let loadingStar = $state(false);
  let dictResults = $state<DictionaryResult[]>([]);

  let apiClient = $derived(new CiyueApiClient(serverUrl));
  let debounceTimer: any = null;
  let unlistenSettings: (() => void) | null = null;

  async function init() {
    const settings = await getSettings();
    serverUrl = settings.serverUrl;
    themeColor = settings.themeColor;
    themeMode = settings.themeMode ?? "auto";
    applyThemeColor(themeColor);
    applyThemeMode(themeMode);
    i18n.setLocalePreference(settings.locale ?? "auto");
    await checkStatus();
    if (serverOnline) {
      await loadGroups();
    }
  }

  async function checkStatus() {
    try {
      const status = await apiClient.getStatus();
      serverOnline = status.status === "ok";
      if (status.currentGroupId) {
        currentGroupId = status.currentGroupId;
      }
    } catch (_) {
      serverOnline = false;
    }
  }

  async function loadGroups() {
    try {
      const list = await apiClient.getGroups();
      groups = list;
      const current = list.find((g) => g.isCurrent);
      if (current) currentGroupId = current.id;
    } catch (_) {}
  }

  async function onGroupChange() {
    if (!currentGroupId) return;
    try {
      await apiClient.switchGroup(currentGroupId);
      if (lookupWord) {
        searchWordDirectly(lookupWord);
      }
    } catch (_) {}
  }

  function onInput() {
    const val = searchQuery.trim();
    if (!val || !serverOnline) {
      suggestions = [];
      return;
    }

    clearTimeout(debounceTimer);
    debounceTimer = setTimeout(async () => {
      try {
        const res = await apiClient.getSuggestions(val);
        const list = (res.dictionarySuggestions || []).concat(
          res.spellingSuggestions || [],
        );
        suggestions = [...new Set(list)].slice(0, 8);
      } catch (_) {
        suggestions = [];
      }
    }, 180);
  }

  function selectSuggestion(word: string) {
    searchQuery = word;
    suggestions = [];
    searchWordDirectly(word);
  }

  function submitSearch() {
    const val = searchQuery.trim();
    if (!val) return;
    suggestions = [];
    searchWordDirectly(val);
  }

  async function searchWordDirectly(word: string) {
    lookupWord = word;
    searchQuery = word;
    suggestions = [];
    activeTab = "dicts";
    loading = true;

    try {
      const data = await apiClient.lookup(word);
      dictResults = data.results || [];
      isStared = !!data.stared;
    } catch (_) {
      dictResults = [];
    } finally {
      loading = false;
    }
  }

  async function toggleStar() {
    if (loadingStar || !lookupWord) return;
    loadingStar = true;
    try {
      if (isStared) {
        await apiClient.removeFromWordbook(lookupWord);
        isStared = false;
      } else {
        await apiClient.addToWordbook(lookupWord);
        isStared = true;
      }
    } catch (_) {
    } finally {
      loadingStar = false;
    }
  }

  function openOptions() {
    chrome.runtime.openOptionsPage();
  }

  async function toggleThemeMode() {
    const next: ThemeMode =
      themeMode === "auto" ? "dark" : themeMode === "dark" ? "light" : "auto";
    themeMode = next;
    applyThemeMode(next);
    await saveSettings({ themeMode: next });
  }

  onMount(() => {
    init();
    unlistenSettings = onSettingsChanged((newSettings) => {
      themeColor = newSettings.themeColor;
      serverUrl = newSettings.serverUrl;
      themeMode = newSettings.themeMode ?? "auto";
      if (newSettings.locale) {
        i18n.setLocalePreference(newSettings.locale);
      }
      applyThemeColor(themeColor);
      applyThemeMode(themeMode);
    });

    if (typeof window !== "undefined" && window.matchMedia) {
      const media = window.matchMedia("(prefers-color-scheme: dark)");
      const listener = () => {
        if (themeMode === "auto") {
          applyThemeMode("auto");
        }
      };
      media.addEventListener("change", listener);
      return () => media.removeEventListener("change", listener);
    }
  });

  onDestroy(() => {
    if (unlistenSettings) unlistenSettings();
  });
</script>

<div
  data-theme={themeColor}
  class="w-[420px] max-h-[580px] bg-white dark:bg-zinc-900 text-zinc-900 dark:text-zinc-100 flex flex-col overflow-hidden text-sm font-sans antialiased"
>
  <!-- Top Header -->
  <header
    class="px-3.5 py-2.5 flex items-center justify-between border-b border-zinc-200/80 dark:border-zinc-800 bg-zinc-50/70 dark:bg-zinc-900/70 gap-2"
  >
    <div class="flex items-center gap-2">
      <div
        class="w-7 h-7 rounded-lg bg-primary-600/10 dark:bg-primary-400/10 flex items-center justify-center text-primary-600 dark:text-primary-400"
      >
        <BookOpen class="w-4 h-4" />
      </div>
      <span
        class="font-bold text-zinc-900 dark:text-zinc-100 text-sm tracking-tight"
        >{t("common.appName")}</span
      >
      <span
        class="w-2 h-2 rounded-full inline-block {serverOnline
          ? 'bg-emerald-500 shadow-xs shadow-emerald-500/50'
          : 'bg-rose-500 shadow-xs shadow-rose-500/50'}"
        title={serverOnline ? t("common.online") : t("common.offline")}
      ></span>
    </div>

    <div class="flex items-center gap-2">
      {#if groups.length > 0}
        <select
          class="bg-zinc-100 dark:bg-zinc-800 text-zinc-700 dark:text-zinc-300 border border-zinc-200 dark:border-zinc-700 px-2 py-1 rounded-lg text-xs outline-none cursor-pointer max-w-[140px] truncate"
          bind:value={currentGroupId}
          onchange={onGroupChange}
          title={t("header.switchGroup")}
        >
          {#each groups as g (g.id)}
            <option value={g.id}>
              {g.name} ({g.dictCount})
            </option>
          {/each}
        </select>
      {/if}
      <button
        class="p-1.5 rounded-lg text-zinc-400 hover:text-zinc-700 dark:hover:text-zinc-200 hover:bg-zinc-100 dark:hover:bg-zinc-800 transition-colors cursor-pointer"
        onclick={toggleThemeMode}
        title={t("header.toggleThemeMode", {
          mode:
            themeMode === "dark"
              ? t("theme.modeDark")
              : themeMode === "light"
                ? t("theme.modeLight")
                : t("theme.modeAuto"),
        })}
      >
        {#if themeMode === "dark"}
          <Moon class="w-4 h-4" />
        {:else if themeMode === "light"}
          <Sun class="w-4 h-4" />
        {:else}
          <SunMoon class="w-4 h-4" />
        {/if}
      </button>

      <button
        class="p-1.5 rounded-lg text-zinc-400 hover:text-zinc-700 dark:hover:text-zinc-200 hover:bg-zinc-100 dark:hover:bg-zinc-800 transition-colors cursor-pointer"
        onclick={openOptions}
        title={t("header.settings")}
      >
        <Settings class="w-4 h-4" />
      </button>
    </div>
  </header>

  <!-- Search Box -->
  <div class="p-3 border-b border-zinc-100 dark:border-zinc-800/80 relative">
    <div class="flex items-center gap-2">
      <div class="relative flex-1 flex items-center">
        <Search
          class="w-4 h-4 text-zinc-400 absolute left-3 pointer-events-none"
        />
        <!-- svelte-ignore a11y_autofocus -->
        <input
          type="text"
          bind:value={searchQuery}
          placeholder={t("common.searchPlaceholder")}
          autocomplete="off"
          autofocus
          class="w-full pl-9 pr-8 py-2 rounded-xl border border-zinc-200 dark:border-zinc-750 bg-zinc-50/80 dark:bg-zinc-800/70 text-zinc-900 dark:text-zinc-100 placeholder:text-zinc-400 text-xs outline-none focus:border-primary-500 focus:ring-2 focus:ring-primary-500/15 transition-all"
          oninput={onInput}
          onkeydown={(e) => e.key === "Enter" && submitSearch()}
        />
        {#if searchQuery}
          <button
            class="absolute right-2.5 p-0.5 rounded-full text-zinc-400 hover:text-zinc-600 dark:hover:text-zinc-200 cursor-pointer"
            onclick={() => {
              searchQuery = "";
              suggestions = [];
            }}
          >
            <X class="w-3.5 h-3.5" />
          </button>
        {/if}
      </div>

      <button
        class="px-3.5 py-2 rounded-xl bg-primary-600 hover:bg-primary-700 active:scale-95 text-white font-semibold text-xs cursor-pointer shadow-xs shadow-primary-500/20 transition-all shrink-0"
        onclick={submitSearch}
      >
        {t("common.search")}
      </button>
    </div>

    <!-- Autocomplete Suggestions Dropdown -->
    {#if suggestions.length > 0}
      <div
        class="absolute top-[52px] left-3 right-3 bg-white dark:bg-zinc-800 border border-zinc-200 dark:border-zinc-700 rounded-xl max-h-48 overflow-y-auto z-50 shadow-xl divide-y divide-zinc-100 dark:divide-zinc-750"
      >
        {#each suggestions as item, idx (idx)}
          <!-- svelte-ignore a11y_click_events_have_key_events -->
          <!-- svelte-ignore a11y_no_static_element_interactions -->
          <div
            class="px-3 py-2 text-xs text-zinc-700 dark:text-zinc-200 hover:bg-primary-50 dark:hover:bg-primary-950/40 hover:text-primary-600 dark:hover:text-primary-400 cursor-pointer transition-colors"
            onclick={() => selectSuggestion(item)}
          >
            {item}
          </div>
        {/each}
      </div>
    {/if}
  </div>

  <!-- Active Word Header & Tabs -->
  {#if lookupWord}
    <WordHeader
      word={lookupWord}
      stared={isStared}
      {loadingStar}
      onToggleStar={toggleStar}
    />

    <div
      class="flex items-center px-3 pt-1 gap-1 border-b border-zinc-200/80 dark:border-zinc-800 bg-zinc-50/60 dark:bg-zinc-900/60"
    >
      <!-- svelte-ignore a11y_click_events_have_key_events -->
      <!-- svelte-ignore a11y_no_static_element_interactions -->
      <div
        class="flex items-center gap-1.5 px-3 py-1.5 text-xs rounded-t-lg transition-all cursor-pointer select-none {activeTab ===
        'dicts'
          ? 'text-primary-600 dark:text-primary-400 border-b-2 border-primary-600 dark:border-primary-400 font-semibold bg-white dark:bg-zinc-800/80'
          : 'text-zinc-500 hover:text-zinc-700 dark:hover:text-zinc-300 font-medium'}"
        onclick={() => (activeTab = "dicts")}
      >
        <BookOpen class="w-3.5 h-3.5" />
        <span>{t("lookup.localDicts", { count: dictResults.length })}</span>
      </div>

      <!-- svelte-ignore a11y_click_events_have_key_events -->
      <!-- svelte-ignore a11y_no_static_element_interactions -->
      <div
        class="flex items-center gap-1.5 px-3 py-1.5 text-xs rounded-t-lg transition-all cursor-pointer select-none {activeTab ===
        'ai-explain'
          ? 'text-primary-600 dark:text-primary-400 border-b-2 border-primary-600 dark:border-primary-400 font-semibold bg-white dark:bg-zinc-800/80'
          : 'text-zinc-500 hover:text-zinc-700 dark:hover:text-zinc-300 font-medium'}"
        onclick={() => (activeTab = "ai-explain")}
      >
        <Sparkles class="w-3.5 h-3.5" />
        <span>{t("lookup.aiExplainTab")}</span>
      </div>

      <!-- svelte-ignore a11y_click_events_have_key_events -->
      <!-- svelte-ignore a11y_no_static_element_interactions -->
      <div
        class="flex items-center gap-1.5 px-3 py-1.5 text-xs rounded-t-lg transition-all cursor-pointer select-none {activeTab ===
        'ai-translate'
          ? 'text-primary-600 dark:text-primary-400 border-b-2 border-primary-600 dark:border-primary-400 font-semibold bg-white dark:bg-zinc-800/80'
          : 'text-zinc-500 hover:text-zinc-700 dark:hover:text-zinc-300 font-medium'}"
        onclick={() => (activeTab = "ai-translate")}
      >
        <Languages class="w-3.5 h-3.5" />
        <span>{t("lookup.aiTranslateTab")}</span>
      </div>
    </div>
  {/if}

  <!-- Content Area -->
  <main class="flex-1 overflow-y-auto p-3 max-h-[420px]">
    {#if loading}
      <div
        class="flex flex-col items-center justify-center py-16 gap-2 text-zinc-400"
      >
        <LoaderCircle
          class="w-5 h-5 animate-spin text-primary-600 dark:text-primary-400"
        />
        <span class="text-xs"
          >{t("lookup.searchingWord", { word: searchQuery })}</span
        >
      </div>
    {:else if !serverOnline}
      <div
        class="p-6 text-center bg-rose-50/50 dark:bg-rose-950/20 rounded-2xl border border-dashed border-rose-300 dark:border-rose-800/60 flex flex-col items-center gap-2"
      >
        <WifiOff class="w-6 h-6 text-rose-500" />
        <p class="text-xs font-semibold text-zinc-800 dark:text-zinc-200">
          {t("common.offline")}
        </p>
        <p class="text-[11px] text-zinc-500 dark:text-zinc-400 leading-normal">
          {t("lookup.offlineDesc")}
        </p>
      </div>
    {:else if !lookupWord}
      <div
        class="flex flex-col items-center justify-center py-16 gap-2 text-zinc-400"
      >
        <Search class="w-6 h-6 stroke-1 text-zinc-300 dark:text-zinc-600" />
        <span class="text-xs">{t("lookup.enterWordPrompt")}</span>
      </div>
    {:else if activeTab === "dicts"}
      {#if dictResults.length === 0}
        <div class="text-center py-16 text-zinc-400 text-xs">
          {t("lookup.notFound", { word: lookupWord })}
        </div>
      {:else}
        {#each dictResults as item, idx (item.dictId + idx)}
          <DictCard
            {item}
            index={idx}
            {serverUrl}
            onSubLookup={searchWordDirectly}
          />
        {/each}
      {/if}
    {:else if activeTab === "ai-explain"}
      <AiView mode="explain" text={lookupWord} {serverUrl} />
    {:else if activeTab === "ai-translate"}
      <AiView mode="translate" text={lookupWord} {serverUrl} />
    {/if}
  </main>
</div>
