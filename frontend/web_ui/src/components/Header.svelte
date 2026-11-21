<script lang="ts">
  import BookOpen from '@lucide/svelte/icons/book-open';
  import Languages from '@lucide/svelte/icons/languages';
  import Sun from '@lucide/svelte/icons/sun';
  import Moon from '@lucide/svelte/icons/moon';
  import SunMoon from '@lucide/svelte/icons/sun-moon';
  import Palette from '@lucide/svelte/icons/palette';
  import type { GroupItem, ThemeColor, ThemeMode } from '../api/types';
  import { THEME_OPTIONS } from '../utils/theme';

  let {
    groups,
    currentGroupId,
    themeMode,
    themeColor,
    isTranslateOpen,
    onGroupChange,
    onToggleTranslate,
    onToggleThemeMode,
    onSelectThemeColor,
  }: {
    groups: GroupItem[];
    currentGroupId: number | string;
    themeMode: ThemeMode;
    themeColor: ThemeColor;
    isTranslateOpen: boolean;
    onGroupChange: (id: string) => void;
    onToggleTranslate: () => void;
    onToggleThemeMode: () => void;
    onSelectThemeColor: (color: ThemeColor) => void;
  } = $props();

  let showPalette = $state(false);
</script>

<header class="flex items-center justify-between flex-wrap gap-3 py-3 border-b border-zinc-200/80 dark:border-zinc-800">
  <div class="flex items-center gap-2.5">
    <div class="w-8 h-8 rounded-lg bg-primary-600 text-white flex items-center justify-center shadow-xs">
      <BookOpen class="w-4 h-4 stroke-[2.2]" />
    </div>
    <div class="flex flex-col">
      <span class="text-base font-bold text-zinc-900 dark:text-zinc-100 tracking-tight">词悦 Ciyue</span>
      <span class="text-[11px] text-zinc-400">Web 查词与学习中心</span>
    </div>
  </div>

  <div class="flex items-center gap-2 flex-wrap relative">
    {#if groups.length > 0}
      <select
        class="bg-zinc-100 dark:bg-zinc-800 text-zinc-800 dark:text-zinc-200 border border-zinc-200 dark:border-zinc-700 px-3 py-1.5 rounded-xl text-xs font-medium outline-none cursor-pointer max-w-[160px] truncate"
        value={String(currentGroupId)}
        onchange={(e) => onGroupChange((e.target as HTMLSelectElement).value)}
        title="切换词典分组"
      >
        {#each groups as g (g.id)}
          <option value={String(g.id)}>
            {g.name}
          </option>
        {/each}
      </select>
    {/if}

    <button
      class="inline-flex items-center gap-1.5 px-3 py-1.5 rounded-xl text-xs font-medium border transition-all cursor-pointer {isTranslateOpen
        ? 'bg-primary-50 dark:bg-primary-950/40 text-primary-600 dark:text-primary-400 border-primary-500/40'
        : 'bg-zinc-100 dark:bg-zinc-800 text-zinc-700 dark:text-zinc-300 border-zinc-200 dark:border-zinc-700 hover:bg-zinc-200/60 dark:hover:bg-zinc-700'}"
      onclick={onToggleTranslate}
      title="AI 智能翻译面板"
    >
      <Languages class="w-3.5 h-3.5" />
      <span>AI 翻译</span>
    </button>

    <button
      class="p-2 rounded-xl bg-zinc-100 dark:bg-zinc-800 text-zinc-700 dark:text-zinc-300 border border-zinc-200 dark:border-zinc-700 hover:bg-zinc-200/60 dark:hover:bg-zinc-700 transition-colors cursor-pointer"
      onclick={() => (showPalette = !showPalette)}
      title="主题配色"
    >
      <Palette class="w-3.5 h-3.5" />
    </button>

    {#if showPalette}
      <!-- svelte-ignore a11y_click_events_have_key_events -->
      <!-- svelte-ignore a11y_no_static_element_interactions -->
      <div
        class="absolute right-10 top-11 bg-white dark:bg-zinc-800 border border-zinc-200 dark:border-zinc-700 rounded-xl p-2 shadow-xl z-50 flex gap-1.5"
        onclick={(e) => e.stopPropagation()}
      >
        {#each THEME_OPTIONS as opt (opt.id)}
          <button
            class="w-6 h-6 rounded-full border border-black/10 transition-transform {themeColor === opt.id
              ? 'scale-110 ring-2 ring-primary-500 ring-offset-2 dark:ring-offset-zinc-800'
              : 'hover:scale-105'}"
            style:background-color={opt.primaryHex}
            onclick={() => {
              onSelectThemeColor(opt.id);
              showPalette = false;
            }}
            title={opt.name}
          ></button>
        {/each}
      </div>
    {/if}

    <button
      class="p-2 rounded-xl bg-zinc-100 dark:bg-zinc-800 text-zinc-700 dark:text-zinc-300 border border-zinc-200 dark:border-zinc-700 hover:bg-zinc-200/60 dark:hover:bg-zinc-700 transition-colors cursor-pointer"
      onclick={onToggleThemeMode}
      title="切换明暗主题 (当前: {themeMode === 'dark' ? '深色' : themeMode === 'light' ? '浅色' : '自动'})"
    >
      {#if themeMode === 'dark'}
        <Moon class="w-3.5 h-3.5" />
      {:else if themeMode === 'light'}
        <Sun class="w-3.5 h-3.5" />
      {:else}
        <SunMoon class="w-3.5 h-3.5" />
      {/if}
    </button>
  </div>
</header>
