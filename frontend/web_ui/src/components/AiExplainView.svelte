<script lang="ts">
  import { onMount, onDestroy } from 'svelte';
  import { marked } from 'marked';
  import Sparkles from '@lucide/svelte/icons/sparkles';
  import Copy from '@lucide/svelte/icons/copy';
  import Check from '@lucide/svelte/icons/check';
  import RotateCw from '@lucide/svelte/icons/rotate-cw';
  import X from '@lucide/svelte/icons/x';
  import CircleAlert from '@lucide/svelte/icons/circle-alert';
  import LoaderCircle from '@lucide/svelte/icons/loader-circle';
  import { fetchSseStream } from '../utils/sse';
  import { t } from '../utils/i18n.svelte';

  let {
    word,
    onClose,
  }: {
    word: string;
    onClose: () => void;
  } = $props();

  let content = $state('');
  let streaming = $state(false);
  let errorMsg = $state('');
  let copied = $state(false);

  let cancelStream: (() => void) | null = null;

  let renderedMarkdown = $derived.by(() => {
    if (!content) return '';
    return marked.parse(content) as string;
  });

  function startStream() {
    if (!word) return;
    if (cancelStream) {
      cancelStream();
      cancelStream = null;
    }
    content = '';
    errorMsg = '';
    streaming = true;

    cancelStream = fetchSseStream(
      `/api/ai/explain?word=${encodeURIComponent(word)}&stream=true`,
      {},
      (chunk) => {
        content += chunk;
      },
      (err) => {
        errorMsg = err;
        streaming = false;
      },
      () => {
        streaming = false;
      },
    );
  }

  async function copyContent() {
    if (!content) return;
    try {
      await navigator.clipboard.writeText(content);
      copied = true;
      setTimeout(() => {
        copied = false;
      }, 2000);
    } catch {}
  }

  onMount(() => {
    startStream();
  });

  onDestroy(() => {
    if (cancelStream) cancelStream();
  });

  $effect(() => {
    const _ = word;
    startStream();
  });
</script>

<div class="p-4 bg-white dark:bg-zinc-900 border border-zinc-200/90 dark:border-zinc-800 rounded-2xl shadow-xs flex flex-col gap-3 font-sans">
  <div class="flex items-center justify-between pb-2 border-b border-zinc-100 dark:border-zinc-800">
    <div class="flex items-center gap-2">
      <Sparkles class="w-4 h-4 text-primary-600 dark:text-primary-400" />
      <span class="text-xs font-bold text-zinc-900 dark:text-zinc-100">{t('aiExplain.title', { word })}</span>
    </div>

    <div class="flex items-center gap-1.5">
      {#if content && !streaming}
        <button
          class="inline-flex items-center gap-1 px-2.5 py-1 rounded-lg text-xs font-medium text-zinc-600 dark:text-zinc-400 hover:text-zinc-900 dark:hover:text-zinc-100 hover:bg-zinc-100 dark:hover:bg-zinc-800 border border-zinc-200 dark:border-zinc-700 transition-all cursor-pointer"
          onclick={copyContent}
          title={copied ? t('common.copied') : t('common.copy')}
        >
          {#if copied}
            <Check class="w-3.5 h-3.5 text-emerald-500" />
            <span class="text-emerald-600 dark:text-emerald-400">{t('common.copied')}</span>
          {:else}
            <Copy class="w-3.5 h-3.5" />
            <span>{t('common.copy')}</span>
          {/if}
        </button>
      {/if}
      {#if !streaming}
        <button
          class="inline-flex items-center gap-1 px-2.5 py-1 rounded-lg text-xs font-medium text-zinc-600 dark:text-zinc-400 hover:text-zinc-900 dark:hover:text-zinc-100 hover:bg-zinc-100 dark:hover:bg-zinc-800 border border-zinc-200 dark:border-zinc-700 transition-all cursor-pointer"
          onclick={startStream}
          title={t('common.retry')}
        >
          <RotateCw class="w-3.5 h-3.5" />
          <span>{t('common.retry')}</span>
        </button>
      {/if}
      <button
        class="p-1 rounded-lg text-zinc-400 hover:text-zinc-700 dark:hover:text-zinc-200 hover:bg-zinc-100 dark:hover:bg-zinc-800 transition-colors cursor-pointer"
        onclick={onClose}
        title={t('common.close')}
      >
        <X class="w-4 h-4" />
      </button>
    </div>
  </div>

  {#if errorMsg}
    <div class="p-4 text-center bg-rose-50/70 dark:bg-rose-950/30 rounded-xl border border-dashed border-rose-300 dark:border-rose-800 flex flex-col items-center gap-1.5">
      <CircleAlert class="w-5 h-5 text-rose-500 mb-0.5" />
      <div class="text-xs font-semibold text-rose-700 dark:text-rose-400">{errorMsg}</div>
      <div class="text-[11px] text-zinc-500 dark:text-zinc-400">{t('aiExplain.promptHint')}</div>
    </div>
  {:else}
    <div class="relative leading-relaxed text-[13.5px] text-zinc-800 dark:text-zinc-200 max-h-[420px] overflow-y-auto pr-1">
      {#if content}
        <div class="markdown-body">
          <!-- eslint-disable-next-line svelte/no-at-html-tags -->
          {@html renderedMarkdown}
        </div>
      {/if}
      {#if streaming && !content}
        <div class="flex items-center justify-center gap-2 py-10 text-xs text-zinc-500 dark:text-zinc-400">
          <LoaderCircle class="w-4 h-4 animate-spin text-primary-600 dark:text-primary-400" />
          <span>{t('aiExplain.generating')}</span>
        </div>
      {/if}
      {#if streaming && content}
        <span class="inline-block w-1.5 h-3.5 bg-primary-600 dark:bg-primary-400 ml-0.5 align-middle animate-pulse"></span>
      {/if}
    </div>
  {/if}
</div>

<style>
  :global(.markdown-body h1),
  :global(.markdown-body h2),
  :global(.markdown-body h3) {
    margin: 10px 0 6px 0;
    color: var(--primary-600);
    font-size: 14px;
    font-weight: 600;
  }
  :global(.markdown-body p) {
    margin: 6px 0;
  }
  :global(.markdown-body ul),
  :global(.markdown-body ol) {
    padding-left: 18px;
    margin: 6px 0;
  }
  :global(.markdown-body li) {
    margin-bottom: 2px;
  }
  :global(.markdown-body code) {
    background: var(--primary-50);
    color: var(--primary-700);
    padding: 2px 5px;
    border-radius: 4px;
    font-size: 12px;
    font-family: monospace;
  }
  :global(.markdown-body pre) {
    background: rgba(0, 0, 0, 0.04);
    padding: 10px;
    border-radius: 8px;
    overflow-x: auto;
    border: 1px solid rgba(0, 0, 0, 0.08);
  }
  :global(.markdown-body blockquote) {
    margin: 6px 0;
    padding-left: 10px;
    border-left: 3px solid var(--primary-600);
    color: #71717a;
  }
</style>
