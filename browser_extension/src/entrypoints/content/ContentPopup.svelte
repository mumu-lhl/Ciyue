<script lang="ts">
  import WordHeader from '../../components/WordHeader.svelte';
  import DictCard from '../../components/DictCard.svelte';
  import AiView from '../../components/AiView.svelte';
  import { CiyueApiClient } from '../../api/client';
  import type { DictionaryResult } from '../../api/types';

  let { serverUrl }: { serverUrl: string } = $props();

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

<div class="ciyue-root-container">
  {#if showTrigger}
    <!-- svelte-ignore a11y_click_events_have_key_events -->
    <!-- svelte-ignore a11y_no_static_element_interactions -->
    <div
      class="ciyue-trigger-icon"
      style:left="{triggerX}px"
      style:top="{triggerY}px"
      onmousedown={(e) => e.stopPropagation()}
      onclick={onTriggerClick}
      title="词悦查词"
    >
      悦
    </div>
  {/if}

  {#if showCard}
    <!-- svelte-ignore a11y_no_static_element_interactions -->
    <div
      class="ciyue-popup-card"
      style:left="{cardX}px"
      style:top="{cardY}px"
      onmousedown={(e) => e.stopPropagation()}
    >
      <!-- Header Area (Draggable) -->
      <!-- svelte-ignore a11y_no_static_element_interactions -->
      <div class="ciyue-drag-bar" onmousedown={startDrag}>
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
        <div class="ciyue-tabs-row">
          <!-- svelte-ignore a11y_click_events_have_key_events -->
          <!-- svelte-ignore a11y_no_static_element_interactions -->
          <div
            class="ciyue-tab-item"
            class:active={activeTab === 'dicts'}
            onclick={() => (activeTab = 'dicts')}
          >
            📚 本地词典 ({dictResults.length})
          </div>
          <!-- svelte-ignore a11y_click_events_have_key_events -->
          <!-- svelte-ignore a11y_no_static_element_interactions -->
          <div
            class="ciyue-tab-item"
            class:active={activeTab === 'ai-explain'}
            onclick={() => (activeTab = 'ai-explain')}
          >
            🤖 AI 深度解析
          </div>
          <!-- svelte-ignore a11y_click_events_have_key_events -->
          <!-- svelte-ignore a11y_no_static_element_interactions -->
          <div
            class="ciyue-tab-item"
            class:active={activeTab === 'ai-translate'}
            onclick={() => (activeTab = 'ai-translate')}
          >
            🌐 划词翻译
          </div>
        </div>
      {/if}

      <!-- Main Body -->
      <div class="ciyue-body-scroll">
        {#if loading}
          <div class="ciyue-loading">正在查询词悦词典...</div>
        {:else if loadError}
          <div class="ciyue-empty">
            <p style="font-weight:600; margin-bottom:6px;">无法连接到词悦桌面端服务</p>
            <p style="font-size:12px; color:var(--text-muted);">
              请确认词悦桌面端已打开，并在「设置」中开启「Web 与 API 服务」。
            </p>
          </div>
        {:else if activeTab === 'dicts'}
          {#if dictResults.length === 0}
            <div class="ciyue-empty">未在当前词典分组中找到 “{currentWord}”</div>
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
