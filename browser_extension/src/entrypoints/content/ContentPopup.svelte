<script lang="ts">
  import { onMount, onDestroy } from 'svelte';
  import BookOpen from 'lucide-svelte/icons/book-open';
  import Sparkles from 'lucide-svelte/icons/sparkles';
  import Languages from 'lucide-svelte/icons/languages';
  import WifiOff from 'lucide-svelte/icons/wifi-off';
  import LoaderCircle from 'lucide-svelte/icons/loader-circle';
  import WordHeader from '../../components/WordHeader.svelte';
  import DictCard from '../../components/DictCard.svelte';
  import AiView from '../../components/AiView.svelte';
  import { CiyueApiClient } from '../../api/client';
  import { onSettingsChanged } from '../../utils/settings';
  import type { DictionaryResult, ThemeColor } from '../../api/types';

  let {
    serverUrl,
    themeColor = 'blue',
  }: {
    serverUrl: string;
    themeColor?: ThemeColor;
  } = $props();

  let overrideTheme = $state<ThemeColor | null>(null);
  let activeTheme = $derived(overrideTheme ?? themeColor);
  let showTrigger = $state(false);
  let triggerX = $state(0);
  let triggerY = $state(0);

  let showCard = $state(false);
  let cardX = $state(100);
  let cardY = $state(100);

  let currentWord = $state('');
  let activeTab = $state<'dicts' | 'ai-explain' | 'ai-translate'>('dicts');
  let loading = $state(false);
  let loadError = $state(false);
  let isStared = $state(false);
  let loadingStar = $state(false);
  let dictResults = $state<DictionaryResult[]>([]);

  let apiClient = $derived(new CiyueApiClient(serverUrl));
  let unlistenSettings: (() => void) | null = null;

  onMount(() => {
    unlistenSettings = onSettingsChanged((newSettings) => {
      overrideTheme = newSettings.themeColor;
    });
  });

  onDestroy(() => {
    if (unlistenSettings) unlistenSettings();
  });

  export function displayTrigger(x: number, y: number, word: string) {
    currentWord = word;
    triggerX = x;
    triggerY = y;
    showTrigger = true;
  }

  export function hideTrigger() {
    showTrigger = false;
  }

  export function openCard(word: string, x: number, y: number) {
    const popupWidth = 440;
    const padding = 16;
    const posX = Math.max(padding, Math.min(x, window.innerWidth - popupWidth - padding));
    let posY = y + 15;

    if (posY + 420 > window.innerHeight + window.scrollY) {
      posY = Math.max(10, y - 440);
    }

    cardX = posX;
    cardY = posY;
    showCard = true;
    hideTrigger();

    doLookup(word);
  }

  export function closeCard() {
    showCard = false;
  }

  function onTriggerClick(e: MouseEvent) {
    e.stopPropagation();
    hideTrigger();
    openCard(currentWord, triggerX, triggerY);
  }

  async function doLookup(word: string) {
    currentWord = word;
    loading = true;
    loadError = false;
    activeTab = 'dicts';

    try {
      apiClient.setServerUrl(serverUrl);
      const data = await apiClient.lookup(word);
      dictResults = data.results || [];
      isStared = !!data.stared;
    } catch (_) {
      loadError = true;
    } finally {
      loading = false;
    }
  }

  async function toggleStar() {
    if (loadingStar || !currentWord) return;
    loadingStar = true;
    try {
      if (isStared) {
        await apiClient.removeFromWordbook(currentWord);
        isStared = false;
      } else {
        await apiClient.addToWordbook(currentWord);
        isStared = true;
      }
    } catch (_) {
    } finally {
      loadingStar = false;
    }
  }

  // Dragging support
  let isDragging = false;
  let startMouseX = 0;
  let startMouseY = 0;
  let origLeft = 0;
  let origTop = 0;

  function startDrag(e: MouseEvent) {
    if ((e.target as HTMLElement).closest('button')) return;
    isDragging = true;
    startMouseX = e.clientX;
    startMouseY = e.clientY;
    origLeft = cardX;
    origTop = cardY;

    window.addEventListener('mousemove', onDragging);
    window.addEventListener('mouseup', stopDrag);
    e.preventDefault();
  }

  function onDragging(e: MouseEvent) {
    if (!isDragging) return;
    cardX = origLeft + (e.clientX - startMouseX);
    cardY = origTop + (e.clientY - startMouseY);
  }

  function stopDrag() {
    isDragging = false;
    window.removeEventListener('mousemove', onDragging);
    window.removeEventListener('mouseup', stopDrag);
  }
</script>

<div data-theme={activeTheme} class="relative font-sans text-zinc-900 dark:text-zinc-100 antialiased">
  {#if showTrigger}
    <!-- svelte-ignore a11y_click_events_have_key_events -->
    <!-- svelte-ignore a11y_no_static_element_interactions -->
    <div
      class="fixed z-[2147483647] flex items-center justify-center w-7 h-7 rounded-full text-white transition-all cursor-pointer select-none active:scale-95 hover:scale-110 ring-2 ring-white/90 dark:ring-zinc-900/90"
      style:left="{triggerX}px"
      style:top="{triggerY}px"
      style:background="linear-gradient(135deg, var(--primary-gradient-from), var(--primary-gradient-to))"
      style:box-shadow="0 6px 14px -2px var(--primary-shadow)"
      onmousedown={(e) => e.stopPropagation()}
      onclick={onTriggerClick}
      title="词悦查词"
    >
      <BookOpen class="w-3.5 h-3.5 text-white stroke-[2.2]" />
    </div>
  {/if}

  {#if showCard}
    <!-- svelte-ignore a11y_no_static_element_interactions -->
    <div
      class="fixed z-[2147483647] w-[440px] max-h-[520px] rounded-2xl bg-white/95 dark:bg-zinc-900/95 backdrop-blur-md border border-zinc-200/90 dark:border-zinc-800 shadow-2xl overflow-hidden flex flex-col font-sans text-sm select-none"
      style:left="{cardX}px"
      style:top="{cardY}px"
      onmousedown={(e) => e.stopPropagation()}
    >
      <!-- Header Area (Draggable) -->
      <!-- svelte-ignore a11y_no_static_element_interactions -->
      <div class="cursor-move select-none" onmousedown={startDrag}>
        <WordHeader
          word={currentWord}
          stared={isStared}
          loadingStar={loadingStar}
          showClose={true}
          onToggleStar={toggleStar}
          onClose={closeCard}
        />
      </div>

      <!-- Navigation Tabs -->
      {#if !loading && !loadError}
        <div class="flex items-center px-3 pt-1 gap-1 border-b border-zinc-200/80 dark:border-zinc-800 bg-zinc-50/60 dark:bg-zinc-900/60">
          <!-- svelte-ignore a11y_click_events_have_key_events -->
          <!-- svelte-ignore a11y_no_static_element_interactions -->
          <div
            class="flex items-center gap-1.5 px-3 py-1.5 text-xs rounded-t-lg transition-all cursor-pointer select-none {activeTab ===
            'dicts'
              ? 'text-primary-600 dark:text-primary-400 border-b-2 border-primary-600 dark:border-primary-400 font-semibold bg-white dark:bg-zinc-800/80'
              : 'text-zinc-500 hover:text-zinc-700 dark:hover:text-zinc-300 font-medium'}"
            onclick={() => (activeTab = 'dicts')}
          >
            <BookOpen class="w-3.5 h-3.5" />
            <span>本地词典 ({dictResults.length})</span>
          </div>

          <!-- svelte-ignore a11y_click_events_have_key_events -->
          <!-- svelte-ignore a11y_no_static_element_interactions -->
          <div
            class="flex items-center gap-1.5 px-3 py-1.5 text-xs rounded-t-lg transition-all cursor-pointer select-none {activeTab ===
            'ai-explain'
              ? 'text-primary-600 dark:text-primary-400 border-b-2 border-primary-600 dark:border-primary-400 font-semibold bg-white dark:bg-zinc-800/80'
              : 'text-zinc-500 hover:text-zinc-700 dark:hover:text-zinc-300 font-medium'}"
            onclick={() => (activeTab = 'ai-explain')}
          >
            <Sparkles class="w-3.5 h-3.5" />
            <span>AI 解析</span>
          </div>

          <!-- svelte-ignore a11y_click_events_have_key_events -->
          <!-- svelte-ignore a11y_no_static_element_interactions -->
          <div
            class="flex items-center gap-1.5 px-3 py-1.5 text-xs rounded-t-lg transition-all cursor-pointer select-none {activeTab ===
            'ai-translate'
              ? 'text-primary-600 dark:text-primary-400 border-b-2 border-primary-600 dark:border-primary-400 font-semibold bg-white dark:bg-zinc-800/80'
              : 'text-zinc-500 hover:text-zinc-700 dark:hover:text-zinc-300 font-medium'}"
            onclick={() => (activeTab = 'ai-translate')}
          >
            <Languages class="w-3.5 h-3.5" />
            <span>划词翻译</span>
          </div>
        </div>
      {/if}

      <!-- Main Body Scroll Area -->
      <div class="flex-1 overflow-y-auto p-3 max-h-[420px]">
        {#if loading}
          <div class="flex flex-col items-center justify-center py-12 gap-2 text-zinc-400">
            <LoaderCircle class="w-5 h-5 animate-spin text-primary-600 dark:text-primary-400" />
            <span class="text-xs">正在查询词典...</span>
          </div>
        {:else if loadError}
          <div class="p-5 text-center bg-zinc-50 dark:bg-zinc-800/50 rounded-xl border border-dashed border-zinc-200 dark:border-zinc-700 flex flex-col items-center gap-2">
            <WifiOff class="w-6 h-6 text-rose-500" />
            <div class="text-xs font-semibold text-zinc-800 dark:text-zinc-200">无法连接到词悦桌面端服务</div>
            <div class="text-[11px] text-zinc-500 dark:text-zinc-400 leading-normal">
              请确认词悦桌面端已打开，并在「设置」中开启「Web 与 API 服务」。
            </div>
          </div>
        {:else if activeTab === 'dicts'}
          {#if dictResults.length === 0}
            <div class="text-center py-12 text-zinc-400 text-xs">
              未在当前词典分组中找到 “{currentWord}”
            </div>
          {:else}
            {#each dictResults as item, idx (item.dictId + idx)}
              <DictCard
                {item}
                index={idx}
                {serverUrl}
                onSubLookup={doLookup}
              />
            {/each}
          {/if}
        {:else if activeTab === 'ai-explain'}
          <AiView
            mode="explain"
            text={currentWord}
            {serverUrl}
          />
        {:else if activeTab === 'ai-translate'}
          <AiView
            mode="translate"
            text={currentWord}
            {serverUrl}
          />
        {/if}
      </div>
    </div>
  {/if}
</div>
