<script lang="ts">
  import BookOpen from '@lucide/svelte/icons/book-open';
  import Star from '@lucide/svelte/icons/star';
  import X from '@lucide/svelte/icons/x';
  import LoaderCircle from '@lucide/svelte/icons/loader-circle';
  import { t } from '../utils/i18n.svelte';

  let {
    word = '',
    stared = false,
    loadingStar = false,
    showClose = false,
    onToggleStar,
    onClose,
  }: {
    word: string;
    stared?: boolean;
    loadingStar?: boolean;
    showClose?: boolean;
    onToggleStar?: () => void;
    onClose?: () => void;
  } = $props();
</script>

<div
  class="flex items-center justify-between px-3.5 py-2.5 bg-zinc-50/90 dark:bg-zinc-800/80 border-b border-zinc-200/80 dark:border-zinc-800 select-none"
>
  <div class="flex items-center gap-2 min-w-0">
    <BookOpen class="w-4 h-4 text-primary-600 dark:text-primary-400 shrink-0" />
    <span class="text-sm font-bold text-zinc-900 dark:text-zinc-100 truncate" title={word}>
      {word}
    </span>
  </div>
  <div class="flex items-center gap-1 shrink-0">
    <button
      class="p-1.5 rounded-lg text-zinc-400 hover:text-amber-500 hover:bg-zinc-100 dark:hover:bg-zinc-700/60 transition-all cursor-pointer"
      title={stared ? t('wordHeader.removeFromNotebook') : t('wordHeader.addToNotebook')}
      onclick={onToggleStar}
    >
      {#if loadingStar}
        <LoaderCircle class="w-4 h-4 animate-spin text-amber-500" />
      {:else}
        <Star
          class="w-4 h-4 transition-transform duration-150 {stared
            ? 'fill-amber-400 text-amber-400 scale-105'
            : 'hover:scale-105'}"
        />
      {/if}
    </button>
    {#if showClose}
      <button
        class="p-1.5 rounded-lg text-zinc-400 hover:text-zinc-700 dark:hover:text-zinc-200 hover:bg-zinc-100 dark:hover:bg-zinc-700/60 transition-colors cursor-pointer"
        title={t('common.close')}
        onclick={onClose}
      >
        <X class="w-4 h-4" />
      </button>
    {/if}
  </div>
</div>
