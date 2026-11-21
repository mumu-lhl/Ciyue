<script lang="ts">
  import BookOpen from 'lucide-svelte/icons/book-open';
  import Star from 'lucide-svelte/icons/star';
  import Sparkles from 'lucide-svelte/icons/sparkles';
  import LoaderCircle from 'lucide-svelte/icons/loader-circle';

  let {
    word,
    stared,
    loadingStar,
    isAiOpen,
    onToggleStar,
    onToggleAi,
  }: {
    word: string;
    stared: boolean;
    loadingStar: boolean;
    isAiOpen: boolean;
    onToggleStar: () => void;
    onToggleAi: () => void;
  } = $props();
</script>

<div class="flex items-center justify-between p-4 bg-white dark:bg-zinc-900 border border-zinc-200/90 dark:border-zinc-800 rounded-2xl shadow-xs gap-3">
  <div class="flex items-center gap-2.5 min-w-0">
    <BookOpen class="w-5 h-5 text-primary-600 dark:text-primary-400 shrink-0" />
    <span class="text-lg font-bold text-zinc-900 dark:text-zinc-100 truncate tracking-tight">{word}</span>
  </div>

  <div class="flex items-center gap-2 shrink-0">
    <button
      class="inline-flex items-center gap-1.5 px-3 py-1.5 rounded-xl text-xs font-semibold border transition-all cursor-pointer {isAiOpen
        ? 'bg-primary-50 dark:bg-primary-950/40 text-primary-600 dark:text-primary-400 border-primary-500/40'
        : 'bg-zinc-50 dark:bg-zinc-800 text-zinc-700 dark:text-zinc-300 border-zinc-200 dark:border-zinc-700 hover:bg-zinc-100 dark:hover:bg-zinc-700/80'}"
      onclick={onToggleAi}
    >
      <Sparkles class="w-3.5 h-3.5" />
      <span>AI 深度解析</span>
    </button>

    <button
      class="inline-flex items-center gap-1.5 px-3 py-1.5 rounded-xl text-xs font-semibold border transition-all cursor-pointer {stared
        ? 'bg-amber-50 dark:bg-amber-950/30 text-amber-600 dark:text-amber-400 border-amber-300 dark:border-amber-800/60'
        : 'bg-zinc-50 dark:bg-zinc-800 text-zinc-700 dark:text-zinc-300 border-zinc-200 dark:border-zinc-700 hover:bg-zinc-100 dark:hover:bg-zinc-700/80'}"
      onclick={onToggleStar}
      title={stared ? '从生词本移除' : '存入生词本'}
    >
      {#if loadingStar}
        <LoaderCircle class="w-3.5 h-3.5 animate-spin text-amber-500" />
      {:else}
        <Star class="w-3.5 h-3.5 {stared ? 'fill-amber-400 text-amber-400' : ''}" />
      {/if}
      <span>{stared ? '已存生词本' : '存入生词本'}</span>
    </button>
  </div>
</div>
