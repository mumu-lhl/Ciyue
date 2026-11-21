<script lang="ts">
  import { onMount } from 'svelte';
  import Header from './components/Header.svelte';
  import SearchBox from './components/SearchBox.svelte';
  import WordHeader from './components/WordHeader.svelte';
  import DictCard from './components/DictCard.svelte';
  import AiExplainView from './components/AiExplainView.svelte';
  import TranslateDrawer from './components/TranslateDrawer.svelte';
  import { api } from './api/client';
  import type { DictionaryResult, GroupItem, ThemeColor, ThemeMode } from './api/types';
  import {
    applyThemeColor,
    applyThemeMode,
    getStoredThemeColor,
    getStoredThemeMode,
    setStoredThemeColor,
    setStoredThemeMode,
  } from './utils/theme';
  import LoaderCircle from '@lucide/svelte/icons/loader-circle';
  import WifiOff from '@lucide/svelte/icons/wifi-off';
  import Layers from '@lucide/svelte/icons/layers';

  let themeMode = $state<ThemeMode>('auto');
  let themeColor = $state<ThemeColor>('blue');

  let groups = $state<GroupItem[]>([]);
  let currentGroupId = $state<number | string>('');
  let serverOnline = $state(true);

  let query = $state('');
  let currentWord = $state('');
  let loading = $state(false);
  let errorMsg = $state('');
  let stared = $state(false);
  let loadingStar = $state(false);
  let results = $state<DictionaryResult[]>([]);

  let isTranslateOpen = $state(false);
  let isAiExplainOpen = $state(false);
  let isAllCollapsed = $state(false);
  let dictCardRefs: (DictCard | null)[] = $state([]);

  let targetAnchor = $state('');
  let targetDictId = $state<number | string>('');

  let isDarkActive = $derived(
    themeMode === 'dark' ||
      (themeMode === 'auto' &&
        typeof window !== 'undefined' &&
        window.matchMedia('(prefers-color-scheme: dark)').matches),
  );

  async function init() {
    themeMode = getStoredThemeMode();
    themeColor = getStoredThemeColor();
    applyThemeMode(themeMode);
    applyThemeColor(themeColor);

    try {
      const status = await api.getStatus();
      serverOnline = status.status === 'ok';
      if (status.currentGroupId !== undefined) {
        currentGroupId = status.currentGroupId;
      }
      await loadGroups();
    } catch {
      serverOnline = false;
    }
  }

  async function loadGroups() {
    try {
      const list = await api.getGroups();
      groups = list;
      const cur = list.find((g) => g.isCurrent);
      if (cur) currentGroupId = cur.id;
    } catch {
      groups = [];
    }
  }

  async function onGroupChange(newId: string) {
    currentGroupId = newId;
    try {
      await api.switchGroup(newId);
      if (currentWord) {
        doLookup(currentWord);
      }
    } catch {}
  }

  function onToggleThemeMode() {
    const next: ThemeMode = themeMode === 'auto' ? 'dark' : themeMode === 'dark' ? 'light' : 'auto';
    themeMode = next;
    setStoredThemeMode(next);
    applyThemeMode(next);
  }

  function onSelectThemeColor(color: ThemeColor) {
    themeColor = color;
    setStoredThemeColor(color);
    applyThemeColor(color);
  }

  async function doLookup(word: string, anchor = '', dictId: number | string = '') {
    const target = word.trim();
    if (!target) return;

    currentWord = target;
    query = target;
    targetAnchor = anchor;
    targetDictId = dictId;
    loading = true;
    errorMsg = '';
    isAllCollapsed = false;

    try {
      const data = await api.lookup(target, currentGroupId);
      results = data.results || [];
      stared = !!data.stared;
    } catch (e: any) {
      errorMsg = e?.message ?? '查询失败';
      results = [];
    } finally {
      loading = false;
    }
  }

  async function toggleStar() {
    if (loadingStar || !currentWord) return;
    loadingStar = true;
    try {
      if (stared) {
        await api.removeFromWordbook(currentWord);
        stared = false;
      } else {
        await api.addToWordbook(currentWord);
        stared = true;
      }
    } catch {
    } finally {
      loadingStar = false;
    }
  }

  function toggleAll() {
    isAllCollapsed = !isAllCollapsed;
    for (const card of dictCardRefs) {
      if (card) card.setCollapsed(isAllCollapsed);
    }
  }

  function handleMessage(e: MessageEvent) {
    if (e.data && e.data.type === 'LOOKUP' && e.data.word) {
      doLookup(e.data.word, e.data.anchor || '', e.data.dictId);
    }
  }

  onMount(() => {
    init();
    window.addEventListener('message', handleMessage);

    const mql = window.matchMedia('(prefers-color-scheme: dark)');
    const mqlHandler = () => {
      if (themeMode === 'auto') applyThemeMode('auto');
    };
    mql.addEventListener('change', mqlHandler);

    return () => {
      window.removeEventListener('message', handleMessage);
      mql.removeEventListener('change', mqlHandler);
    };
  });
</script>

<div data-theme={themeColor} class="min-h-screen bg-zinc-50 dark:bg-zinc-950 text-zinc-900 dark:text-zinc-100 flex flex-col items-center px-4 py-6 font-sans antialiased">
  <div class="w-full max-w-4xl flex flex-col gap-5">
    <Header
      {groups}
      {currentGroupId}
      {themeMode}
      {themeColor}
      {isTranslateOpen}
      {onGroupChange}
      onToggleTranslate={() => (isTranslateOpen = !isTranslateOpen)}
      {onToggleThemeMode}
      {onSelectThemeColor}
    />

    <TranslateDrawer
      isOpen={isTranslateOpen}
      onClose={() => (isTranslateOpen = false)}
    />

    <SearchBox
      bind:query
      onSearch={(w) => doLookup(w)}
    />

    {#if loading}
      <div class="flex flex-col items-center justify-center py-20 gap-3 text-zinc-400">
        <LoaderCircle class="w-6 h-6 animate-spin text-primary-600 dark:text-primary-400" />
        <span class="text-xs">正在查询 “{currentWord}”...</span>
      </div>
    {:else if !serverOnline}
      <div class="p-8 text-center bg-rose-50/60 dark:bg-rose-950/30 border border-dashed border-rose-300 dark:border-rose-800 rounded-3xl flex flex-col items-center gap-3">
        <WifiOff class="w-8 h-8 text-rose-500" />
        <span class="text-sm font-bold text-zinc-900 dark:text-zinc-100">无法连接到词悦桌面端 Web 服务</span>
        <span class="text-xs text-zinc-500 dark:text-zinc-400 max-w-md leading-relaxed">
          请确保词悦桌面端已启动，并在桌面端「设置」->「Web 与 API 服务」中确认已开启服务并允许访问。
        </span>
      </div>
    {:else if errorMsg}
      <div class="p-6 text-center text-rose-600 dark:text-rose-400 text-xs font-semibold bg-rose-50/60 dark:bg-rose-950/30 rounded-2xl border border-rose-200 dark:border-rose-800">
        {errorMsg}
      </div>
    {:else if currentWord}
      <WordHeader
        word={currentWord}
        {stared}
        {loadingStar}
        isAiOpen={isAiExplainOpen}
        onToggleStar={toggleStar}
        onToggleAi={() => (isAiExplainOpen = !isAiExplainOpen)}
      />

      {#if isAiExplainOpen}
        <AiExplainView
          word={currentWord}
          onClose={() => (isAiExplainOpen = false)}
        />
      {/if}

      {#if results.length === 0}
        <div class="p-12 text-center text-zinc-400 text-xs bg-white dark:bg-zinc-900 border border-zinc-200/90 dark:border-zinc-800 rounded-2xl">
          未在当前分组词典中找到 “<b>{currentWord}</b>”
        </div>
      {:else}
        <div class="flex items-center justify-between px-1 text-xs text-zinc-500 dark:text-zinc-400">
          <div class="flex items-center gap-1.5 font-medium">
            <Layers class="w-3.5 h-3.5" />
            <span>共找到 {results.length} 本词典释义</span>
          </div>
          <button
            class="px-2.5 py-1 rounded-lg hover:bg-zinc-200/60 dark:hover:bg-zinc-800 text-zinc-700 dark:text-zinc-300 font-medium cursor-pointer transition-colors"
            onclick={toggleAll}
          >
            {isAllCollapsed ? '展开全部' : '折叠全部'}
          </button>
        </div>

        <div class="flex flex-col gap-3">
          {#each results as item, index (String(item.dictId) + index)}
            <DictCard
              bind:this={dictCardRefs[index]}
              {item}
              {index}
              {targetAnchor}
              isTargetDict={String(item.dictId) === String(targetDictId)}
              isDark={isDarkActive}
              onSubLookup={(w, a, dId) => doLookup(w, a, dId)}
            />
          {/each}
        </div>
      {/if}
    {/if}
  </div>
</div>
