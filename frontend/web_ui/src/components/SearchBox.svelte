<script lang="ts">
  import Search from '@lucide/svelte/icons/search';
  import X from '@lucide/svelte/icons/x';
  import { api } from '../api/client';

  let {
    query = $bindable(''),
    onSearch,
  }: {
    query: string;
    onSearch: (word: string) => void;
  } = $props();

  let suggestions = $state<string[]>([]);
  let debounceTimer: any = null;

  function onInput() {
    const val = query.trim();
    if (!val) {
      suggestions = [];
      return;
    }
    clearTimeout(debounceTimer);
    debounceTimer = setTimeout(async () => {
      try {
        const res = await api.getSuggestions(val);
        const list = (res.dictionarySuggestions || []).concat(res.spellingSuggestions || []);
        suggestions = [...new Set(list)].slice(0, 8);
      } catch {
        suggestions = [];
      }
    }, 180);
  }

  function submit(val: string) {
    suggestions = [];
    const target = val.trim();
    if (target) {
      query = target;
      onSearch(target);
    }
  }

  function onKeyDown(e: KeyboardEvent) {
    if (e.key === 'Enter') {
      submit(query);
    } else if (e.key === 'Escape') {
      suggestions = [];
    }
  }
</script>

<div class="relative w-full">
  <div class="relative flex items-center">
    <Search class="w-4 h-4 text-zinc-400 absolute left-4 pointer-events-none" />
    <input
      type="text"
      bind:value={query}
      oninput={onInput}
      onkeydown={onKeyDown}
      placeholder="输入单词按回车查词..."
      autocomplete="off"
      class="w-full pl-11 pr-24 py-3 rounded-2xl border border-zinc-200 dark:border-zinc-800 bg-white dark:bg-zinc-900 text-zinc-900 dark:text-zinc-100 placeholder:text-zinc-400 text-sm outline-none focus:border-primary-500 focus:ring-2 focus:ring-primary-500/15 shadow-xs transition-all"
    />
    <div class="absolute right-2.5 flex items-center gap-1">
      {#if query}
        <button
          class="p-1.5 rounded-full text-zinc-400 hover:text-zinc-600 dark:hover:text-zinc-200 cursor-pointer"
          onclick={() => {
            query = '';
            suggestions = [];
          }}
          title="清空"
        >
          <X class="w-4 h-4" />
        </button>
      {/if}
      <button
        class="px-4 py-1.5 rounded-xl bg-primary-600 hover:bg-primary-700 active:scale-95 text-white text-xs font-semibold cursor-pointer shadow-xs shadow-primary-500/20 transition-all"
        onclick={() => submit(query)}
      >
        查询
      </button>
    </div>
  </div>

  {#if suggestions.length > 0}
    <!-- svelte-ignore a11y_click_events_have_key_events -->
    <!-- svelte-ignore a11y_no_static_element_interactions -->
    <div class="absolute top-13 left-0 right-0 bg-white dark:bg-zinc-900 border border-zinc-200 dark:border-zinc-800 rounded-2xl shadow-xl z-40 overflow-hidden divide-y divide-zinc-100 dark:divide-zinc-800/80">
      {#each suggestions as item, idx (idx)}
        <div
          class="px-4 py-2.5 text-xs text-zinc-700 dark:text-zinc-200 hover:bg-primary-50 dark:hover:bg-primary-950/40 hover:text-primary-600 dark:hover:text-primary-400 cursor-pointer transition-colors"
          onclick={() => submit(item)}
        >
          {item}
        </div>
      {/each}
    </div>
  {/if}
</div>
