<script lang="ts">
  import Languages from 'lucide-svelte/icons/languages';
  import X from 'lucide-svelte/icons/x';
  import Copy from 'lucide-svelte/icons/copy';
  import Check from 'lucide-svelte/icons/check';
  import RotateCw from 'lucide-svelte/icons/rotate-cw';
  import LoaderCircle from 'lucide-svelte/icons/loader-circle';
  import CircleAlert from 'lucide-svelte/icons/circle-alert';
  import { marked } from 'marked';
  import { fetchSseStream } from '../utils/sse';

  let {
    isOpen,
    onClose,
  }: {
    isOpen: boolean;
    onClose: () => void;
  } = $props();

  let text = $state('');
  let targetLang = $state('Simplified Chinese');
  let result = $state('');
  let streaming = $state(false);
  let errorMsg = $state('');
  let copied = $state(false);

  let cancelStream: (() => void) | null = null;

  let renderedResult = $derived.by(() => {
    if (!result) return '';
    return marked.parse(result) as string;
  });

  function startTranslate() {
    const q = text.trim();
    if (!q) return;

    if (cancelStream) {
      cancelStream();
      cancelStream = null;
    }

    result = '';
    errorMsg = '';
    streaming = true;

    cancelStream = fetchSseStream(
      `/api/ai/translate?stream=true&targetLang=${encodeURIComponent(targetLang)}`,
      {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ text: q }),
      },
      (chunk) => {
        result += chunk;
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

  async function copyResult() {
    if (!result) return;
    try {
      await navigator.clipboard.writeText(result);
      copied = true;
      setTimeout(() => {
        copied = false;
      }, 2000);
    } catch {}
  }
</script>

{#if isOpen}
  <div class="p-5 bg-white dark:bg-zinc-900 border border-zinc-200/90 dark:border-zinc-800 rounded-2xl shadow-sm flex flex-col gap-4 font-sans">
    <div class="flex items-center justify-between pb-2 border-b border-zinc-100 dark:border-zinc-800">
      <div class="flex items-center gap-2">
        <Languages class="w-4 h-4 text-primary-600 dark:text-primary-400" />
        <span class="text-sm font-bold text-zinc-900 dark:text-zinc-100">AI 智能翻译</span>
      </div>

      <div class="flex items-center gap-2">
        <select
          bind:value={targetLang}
          class="bg-zinc-100 dark:bg-zinc-800 text-zinc-800 dark:text-zinc-200 border border-zinc-200 dark:border-zinc-700 px-2.5 py-1 rounded-xl text-xs outline-none cursor-pointer"
        >
          <option value="Simplified Chinese">简体中文</option>
          <option value="Traditional Chinese">繁体中文</option>
          <option value="English">English</option>
          <option value="Japanese">日本語</option>
          <option value="Korean">한국어</option>
          <option value="French">Français</option>
          <option value="German">Deutsch</option>
          <option value="Spanish">Español</option>
        </select>

        <button
          class="p-1 rounded-lg text-zinc-400 hover:text-zinc-700 dark:hover:text-zinc-200 hover:bg-zinc-100 dark:hover:bg-zinc-800 cursor-pointer"
          onclick={onClose}
        >
          <X class="w-4 h-4" />
        </button>
      </div>
    </div>

    <div class="flex flex-col gap-2">
      <textarea
        bind:value={text}
        rows="3"
        placeholder="输入或粘贴需要翻译的段落文本..."
        class="w-full p-3 rounded-xl border border-zinc-200 dark:border-zinc-750 bg-zinc-50/70 dark:bg-zinc-800/60 text-xs text-zinc-900 dark:text-zinc-100 outline-none focus:border-primary-500 focus:ring-2 focus:ring-primary-500/15 resize-y transition-all"
        onkeydown={(e) => {
          if (e.key === 'Enter' && (e.ctrlKey || e.metaKey)) {
            startTranslate();
          }
        }}
      ></textarea>

      <div class="flex justify-between items-center">
        <span class="text-[11px] text-zinc-400">快捷键: Ctrl/Cmd + Enter 发送</span>
        <button
          class="px-4 py-1.5 rounded-xl bg-primary-600 hover:bg-primary-700 active:scale-95 text-white text-xs font-semibold cursor-pointer shadow-xs shadow-primary-500/20 transition-all flex items-center gap-1.5 disabled:opacity-50"
          disabled={streaming || !text.trim()}
          onclick={startTranslate}
        >
          {#if streaming}
            <LoaderCircle class="w-3.5 h-3.5 animate-spin" />
            <span>翻译中...</span>
          {:else}
            <span>立即翻译</span>
          {/if}
        </button>
      </div>
    </div>

    {#if errorMsg}
      <div class="p-3 text-center bg-rose-50/70 dark:bg-rose-950/30 rounded-xl border border-dashed border-rose-300 dark:border-rose-800 flex items-center gap-2">
        <CircleAlert class="w-4 h-4 text-rose-500 shrink-0" />
        <span class="text-xs text-rose-700 dark:text-rose-400 font-medium">{errorMsg}</span>
      </div>
    {/if}

    {#if result || streaming}
      <div class="p-4 bg-zinc-50/70 dark:bg-zinc-800/40 border border-zinc-200 dark:border-zinc-750 rounded-xl flex flex-col gap-2 relative">
        <div class="flex items-center justify-between">
          <span class="text-xs font-semibold text-zinc-500 dark:text-zinc-400">译文结果</span>
          {#if result && !streaming}
            <div class="flex items-center gap-1.5">
              <button
                class="inline-flex items-center gap-1 px-2 py-0.5 rounded-md text-xs text-zinc-600 dark:text-zinc-400 hover:bg-zinc-200/60 dark:hover:bg-zinc-700 cursor-pointer"
                onclick={copyResult}
              >
                {#if copied}
                  <Check class="w-3.5 h-3.5 text-emerald-500" />
                  <span class="text-emerald-600 dark:text-emerald-400">已复制</span>
                {:else}
                  <Copy class="w-3.5 h-3.5" />
                  <span>复制</span>
                {/if}
              </button>
              <button
                class="inline-flex items-center gap-1 px-2 py-0.5 rounded-md text-xs text-zinc-600 dark:text-zinc-400 hover:bg-zinc-200/60 dark:hover:bg-zinc-700 cursor-pointer"
                onclick={startTranslate}
              >
                <RotateCw class="w-3.5 h-3.5" />
                <span>重试</span>
              </button>
            </div>
          {/if}
        </div>

        <div class="text-xs text-zinc-800 dark:text-zinc-200 leading-relaxed max-h-[300px] overflow-y-auto">
          {#if result}
            <div class="markdown-body">
              <!-- eslint-disable-next-line svelte/no-at-html-tags -->
              {@html renderedResult}
            </div>
          {/if}
          {#if streaming}
            <span class="inline-block w-1.5 h-3 bg-primary-600 dark:bg-primary-400 ml-0.5 align-middle animate-pulse"></span>
          {/if}
        </div>
      </div>
    {/if}
  </div>
{/if}
