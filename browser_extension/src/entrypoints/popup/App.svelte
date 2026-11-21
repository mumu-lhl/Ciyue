<script lang="ts">
  import { onMount } from 'svelte';
  import WordHeader from '../../components/WordHeader.svelte';
  import DictCard from '../../components/DictCard.svelte';
  import AiView from '../../components/AiView.svelte';
  import { CiyueApiClient } from '../../api/client';
  import { getSettings } from '../../utils/settings';
  import type { DictionaryResult, GroupItem } from '../../api/types';

  let serverUrl = $state('http://127.0.0.1:47117');
  let serverOnline = $state(false);
  let groups = $state<GroupItem[]>([]);
  let currentGroupId = $state('');

  let searchQuery = $state('');
  let suggestions = $state<string[]>([]);

  let lookupWord = $state('');
  let activeTab = $state<'dicts' | 'ai-explain' | 'ai-translate'>('dicts');
  let loading = $state(false);
  let isStared = $state(false);
  let loadingStar = $state(false);
  let dictResults = $state<DictionaryResult[]>([]);

  let apiClient = $derived(new CiyueApiClient(serverUrl));
  let debounceTimer: any = null;

  async function init() {
    const settings = await getSettings();
    serverUrl = settings.serverUrl;
    await checkStatus();
    if (serverOnline) {
      await loadGroups();
    }
  }

  async function checkStatus() {
    try {
      const status = await apiClient.getStatus();
      serverOnline = status.status === 'ok';
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
        const list = (res.dictionarySuggestions || []).concat(res.spellingSuggestions || []);
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
    activeTab = 'dicts';
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

  onMount(() => {
    init();
  });
</script>

<div class="ciyue-popup-window">
  <!-- Top Header -->
  <header class="header">
    <div class="brand">
      <span class="brand-icon">📖</span>
      <span class="brand-name">词悦</span>
      <span
        class="status-dot"
        class:online={serverOnline}
        class:offline={!serverOnline}
        title={serverOnline ? '已连接到词悦桌面端' : '未连接到桌面端服务'}
      ></span>
    </div>
    <div class="header-right">
      {#if groups.length > 0}
        <select
          class="group-select"
          bind:value={currentGroupId}
          onchange={onGroupChange}
          title="切换词典分组"
        >
          {#each groups as g (g.id)}
            <option value={g.id}>
              {g.name} ({g.dictCount})
            </option>
          {/each}
        </select>
      {/if}
      <button class="settings-btn" onclick={openOptions} title="扩展设置">
        ⚙️
      </button>
    </div>
  </header>

  <!-- Search Box -->
  <div class="search-box">
    <!-- svelte-ignore a11y_autofocus -->
    <input
      type="text"
      bind:value={searchQuery}
      placeholder="输入单词查词..."
      autocomplete="off"
      autofocus
      oninput={onInput}
      onkeydown={(e) => e.key === 'Enter' && submitSearch()}
    />
    <button class="search-btn" onclick={submitSearch}>查询</button>

    <!-- Autocomplete Suggestions Dropdown -->
    {#if suggestions.length > 0}
      <div class="suggestions-dropdown">
        {#each suggestions as item, idx (idx)}
          <!-- svelte-ignore a11y_click_events_have_key_events -->
          <!-- svelte-ignore a11y_no_static_element_interactions -->
          <div
            class="suggestion-item"
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
      loadingStar={loadingStar}
      onToggleStar={toggleStar}
    />

    <div class="nav-tabs">
      <!-- svelte-ignore a11y_click_events_have_key_events -->
      <!-- svelte-ignore a11y_no_static_element_interactions -->
      <div
        class="tab"
        class:active={activeTab === 'dicts'}
        onclick={() => (activeTab = 'dicts')}
      >
        📚 本地词典 ({dictResults.length})
      </div>
      <!-- svelte-ignore a11y_click_events_have_key_events -->
      <!-- svelte-ignore a11y_no_static_element_interactions -->
      <div
        class="tab"
        class:active={activeTab === 'ai-explain'}
        onclick={() => (activeTab = 'ai-explain')}
      >
        🤖 AI 解析
      </div>
      <!-- svelte-ignore a11y_click_events_have_key_events -->
      <!-- svelte-ignore a11y_no_static_element_interactions -->
      <div
        class="tab"
        class:active={activeTab === 'ai-translate'}
        onclick={() => (activeTab = 'ai-translate')}
      >
        🌐 AI 翻译
      </div>
    </div>
  {/if}

  <!-- Content Area -->
  <main class="content-scroll">
    {#if loading}
      <div class="empty-state">
        正在查询 “{searchQuery}”...
      </div>
    {:else if !serverOnline}
      <div class="empty-state offline-box">
        <p style="font-weight:600; margin-bottom:4px;">未连接到词悦桌面端</p>
        <p style="font-size:12px; color:var(--text-muted);">
          请确认词悦桌面端已打开并在设置中开启「Web 与 API 服务」。
        </p>
      </div>
    {:else if !lookupWord}
      <div class="empty-state">
        输入单词并按回车或点击查询
      </div>
    {:else if activeTab === 'dicts'}
      {#if dictResults.length === 0}
        <div class="empty-state">
          未在当前词典分组中找到 “{lookupWord}”
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
    {:else if activeTab === 'ai-explain'}
      <AiView
        mode="explain"
        text={lookupWord}
        {serverUrl}
      />
    {:else if activeTab === 'ai-translate'}
      <AiView
        mode="translate"
        text={lookupWord}
        {serverUrl}
      />
    {/if}
  </main>
</div>

<style>
  .ciyue-popup-window {
    width: 420px;
    max-height: 580px;
    background: var(--bg);
    color: var(--text);
    display: flex;
    flex-direction: column;
    overflow: hidden;
    font-size: 14px;
  }
  .header {
    padding: 10px 14px;
    display: flex;
    align-items: center;
    justify-content: space-between;
    border-bottom: 1px solid var(--border);
    gap: 8px;
  }
  .brand {
    display: flex;
    align-items: center;
    gap: 6px;
    font-weight: 700;
    color: var(--primary);
    font-size: 15px;
  }
  .status-dot {
    width: 8px;
    height: 8px;
    border-radius: 50%;
    display: inline-block;
  }
  .status-dot.online {
    background: var(--success);
  }
  .status-dot.offline {
    background: var(--danger);
  }
  .header-right {
    display: flex;
    align-items: center;
    gap: 8px;
  }
  .group-select {
    background: var(--surface);
    color: inherit;
    border: 1px solid var(--border);
    padding: 3px 8px;
    border-radius: 12px;
    font-size: 11.5px;
    outline: none;
    cursor: pointer;
    max-width: 140px;
  }
  .settings-btn {
    background: none;
    border: none;
    cursor: pointer;
    font-size: 14px;
    padding: 2px 4px;
    border-radius: 6px;
  }
  .settings-btn:hover {
    background: var(--surface);
  }
  .search-box {
    padding: 10px 14px;
    display: flex;
    gap: 8px;
    position: relative;
  }
  .search-box input {
    flex: 1;
    padding: 8px 12px;
    border-radius: 20px;
    border: 1px solid var(--border);
    background: var(--surface);
    color: inherit;
    outline: none;
    font-size: 13.5px;
    transition: border-color 0.15s ease;
  }
  .search-box input:focus {
    border-color: var(--primary);
  }
  .search-btn {
    background: var(--primary);
    color: #ffffff;
    border: none;
    padding: 6px 14px;
    border-radius: 18px;
    cursor: pointer;
    font-weight: 600;
    font-size: 13px;
    transition: background 0.15s ease;
  }
  .search-btn:hover {
    background: var(--primary-hover);
  }
  .suggestions-dropdown {
    position: absolute;
    top: 48px;
    left: 14px;
    right: 14px;
    background: var(--surface);
    border: 1px solid var(--border);
    border-radius: 12px;
    max-height: 200px;
    overflow-y: auto;
    z-index: 100;
    box-shadow: 0 4px 16px rgba(0, 0, 0, 0.15);
  }
  .suggestion-item {
    padding: 8px 14px;
    cursor: pointer;
    font-size: 13px;
    border-bottom: 1px solid var(--border);
    transition: background 0.15s ease;
  }
  .suggestion-item:last-child {
    border-bottom: none;
  }
  .suggestion-item:hover {
    background: var(--surface-variant);
    color: var(--primary);
  }
  .nav-tabs {
    display: flex;
    border-bottom: 1px solid var(--border);
    background: var(--surface);
  }
  .tab {
    padding: 7px 14px;
    cursor: pointer;
    font-size: 12px;
    font-weight: 600;
    color: var(--text-muted);
    border-bottom: 2px solid transparent;
    transition: all 0.15s ease;
  }
  .tab:hover {
    color: var(--text);
  }
  .tab.active {
    color: var(--primary);
    border-bottom-color: var(--primary);
  }
  .content-scroll {
    flex: 1;
    overflow-y: auto;
    padding: 10px 14px;
    max-height: 420px;
  }
  .empty-state {
    text-align: center;
    padding: 36px 10px;
    color: var(--text-muted);
    font-size: 13px;
  }
  .offline-box {
    background: var(--surface);
    border-radius: 12px;
    border: 1px dashed var(--danger);
    margin-top: 10px;
  }
</style>
