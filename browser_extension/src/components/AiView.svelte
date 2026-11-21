<script lang="ts">
  import { onMount, onDestroy } from 'svelte';
  import { marked } from 'marked';
  import Sparkles from 'lucide-svelte/icons/sparkles';
  import Languages from 'lucide-svelte/icons/languages';
  import Copy from 'lucide-svelte/icons/copy';
  import Check from 'lucide-svelte/icons/check';
  import RotateCw from 'lucide-svelte/icons/rotate-cw';
  import CircleAlert from 'lucide-svelte/icons/circle-alert';
  import LoaderCircle from 'lucide-svelte/icons/loader-circle';
  import { createAiStream } from '../utils/messaging';

  let {
    mode,
    text,
    serverUrl,
  }: {
    mode: 'explain' | 'translate';
    text: string;
    serverUrl: string;
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
    if (!text.trim()) return;

    if (cancelStream) {
      cancelStream();
      cancelStream = null;
    }

    content = '';
    errorMsg = '';
    streaming = true;

    cancelStream = createAiStream(
      {
        mode,
        text,
        serverUrl,
      },
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
    } catch (_) {}
  }

  onMount(() => {
    startStream();
  });

  onDestroy(() => {
    if (cancelStream) {
      cancelStream();
    }
  });

  $effect(() => {
    const _t = text;
    const _m = mode;
    startStream();
  });
</script>

<div class="p-3.5 flex flex-col gap-3 font-sans">
  <div class="flex items-center justify-between pb-2 border-b border-zinc-200/80 dark:border-zinc-800">
    <span
      class="inline-flex items-center gap-1.5 px-2.5 py-0.5 rounded-full text-xs font-medium {mode === 'translate'
        ? 'bg-blue-50 text-blue-700 dark:bg-blue-950/50 dark:text-blue-300 border border-blue-200/60 dark:border-blue-800/60'
        : 'bg-violet-50 text-violet-700 dark:bg-violet-950/50 dark:text-violet-300 border border-violet-200/60 dark:border-violet-800/60'}"
    >
      {#if mode === 'translate'}
        <Languages class="w-3.5 h-3.5" />
        <span>AI 智能翻译</span>
      {:else}
        <Sparkles class="w-3.5 h-3.5" />
        <span>AI 深度解析</span>
      {/if}
    </span>

    <div class="flex items-center gap-1.5">
      {#if content && !streaming}
        <button
          class="inline-flex items-center gap-1 px-2 py-1 rounded-lg text-xs font-medium text-zinc-600 dark:text-zinc-400 hover:text-zinc-900 dark:hover:text-zinc-100 hover:bg-zinc-100 dark:hover:bg-zinc-800 border border-zinc-200 dark:border-zinc-750 transition-all cursor-pointer"
          onclick={copyContent}
          title={copied ? '已复制' : '复制内容'}
        >
          {#if copied}
            <Check class="w-3.5 h-3.5 text-emerald-500" />
            <span class="text-emerald-600 dark:text-emerald-400">已复制</span>
          {:else}
            <Copy class="w-3.5 h-3.5" />
            <span>复制</span>
          {/if}
        </button>
      {/if}
      {#if !streaming}
        <button
          class="inline-flex items-center gap-1 px-2 py-1 rounded-lg text-xs font-medium text-zinc-600 dark:text-zinc-400 hover:text-zinc-900 dark:hover:text-zinc-100 hover:bg-zinc-100 dark:hover:bg-zinc-800 border border-zinc-200 dark:border-zinc-750 transition-all cursor-pointer"
          onclick={startStream}
          title="重新生成"
        >
          <RotateCw class="w-3.5 h-3.5" />
          <span>重试</span>
        </button>
      {/if}
    </div>
  </div>

  {#if errorMsg}
    <div class="p-4 text-center bg-rose-50/70 dark:bg-rose-950/30 rounded-xl border border-dashed border-rose-300 dark:border-rose-800 flex flex-col items-center gap-1.5">
      <CircleAlert class="w-6 h-6 text-rose-500 mb-1" />
      <div class="text-xs font-semibold text-rose-700 dark:text-rose-400">{errorMsg}</div>
      <div class="text-[11px] text-zinc-500 dark:text-zinc-400">请在词悦桌面端「设置」->「AI 模型服务」中配置 API Key。</div>
    </div>
  {:else}
    <div class="relative leading-relaxed text-[13.5px] text-zinc-800 dark:text-zinc-200 max-h-[380px] overflow-y-auto pr-1">
      {#if content}
        <div class="markdown-body">
          <!-- eslint-disable-next-line svelte/no-at-html-tags -->
          {@html renderedMarkdown}
        </div>
      {/if}
      {#if streaming && !content}
        <div class="flex items-center justify-center gap-2 py-10 text-xs text-zinc-500 dark:text-zinc-400">
          <LoaderCircle class="w-4 h-4 animate-spin text-violet-600 dark:text-violet-400" />
          <span>正在连接 AI 模型生成解析...</span>
        </div>
      {/if}
      {#if streaming && content}
        <span class="inline-block w-1.5 h-3.5 bg-violet-600 dark:bg-violet-400 ml-0.5 align-middle animate-pulse"></span>
      {/if}
    </div>
  {/if}
</div>

<style>
  :global(.markdown-body h1),
  :global(.markdown-body h2),
  :global(.markdown-body h3) {
    margin: 10px 0 6px 0;
    color: #7c3aed;
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
    background: rgba(120, 119, 198, 0.1);
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
    border-left: 3px solid #7c3aed;
    color: #71717a;
  }
</style>
