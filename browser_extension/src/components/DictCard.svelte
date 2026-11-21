<script lang="ts">
  import { onMount, onDestroy } from 'svelte';
  import ChevronDown from 'lucide-svelte/icons/chevron-down';
  import type { DictionaryResult } from '../api/types';

  let {
    item,
    index,
    serverUrl,
    onSubLookup,
  }: {
    item: DictionaryResult;
    index: number;
    serverUrl: string;
    onSubLookup?: (word: string) => void;
  } = $props();

  let isCollapsed = $state(false);
  let frameRef: HTMLIFrameElement | null = $state(null);
  let frameHeight = $state('200px');
  let frameId = $derived(`ciyue-frame-${index}`);

  function isDark(): boolean {
    return window.matchMedia('(prefers-color-scheme: dark)').matches;
  }

  function renderFrameContent() {
    if (!frameRef) return;
    const frameDoc = frameRef.contentDocument || frameRef.contentWindow?.document;
    if (!frameDoc) return;

    const cleanBase = serverUrl.replace(/\/+$/, '');
    const baseHref = `${cleanBase}${item.resourceBase}`;
    const darkReaderUrl = chrome.runtime.getURL('assets/darkreader.js');

    frameDoc.open();
    frameDoc.write(`
      <!DOCTYPE html>
      <html>
      <head>
        <base href="${baseHref}">
        <meta charset="utf-8">
        <style>
          * { box-sizing: border-box; }
          body {
            font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, "Helvetica Neue", Arial, sans-serif;
            padding: 10px 14px;
            margin: 0;
            line-height: 1.5;
            font-size: 13.5px;
            color: #1f1f1f;
            overflow-x: hidden;
          }
          a { color: #1a73e8; text-decoration: none; cursor: pointer; }
          a:hover { text-decoration: underline; }
          img { max-width: 100%; height: auto; }
        </style>
        <script src="${darkReaderUrl}"><` + `/script>
      </head>
      <body>
        ${item.content}
        <script>
          if (window.DarkReader && ${isDark()}) {
            try {
              window.DarkReader.setFetchMethod(window.fetch);
              window.DarkReader.enable({
                brightness: 100, contrast: 100, sepia: 0,
                darkSchemeBackgroundColor: "#1e1e24", darkSchemeTextColor: "#e6e0e9"
              });
            } catch (_) {}
          }

          function notifyHeight() {
            try {
              const h = document.documentElement.scrollHeight || document.body.scrollHeight;
              window.parent.postMessage({
                type: 'CIYUE_IFRAME_RESIZE',
                frameId: '${frameId}',
                height: h
              }, '*');
            } catch (_) {}
          }

          notifyHeight();
          if (window.ResizeObserver) {
            const ro = new ResizeObserver(notifyHeight);
            ro.observe(document.body);
          }
          window.addEventListener('load', notifyHeight);

          document.addEventListener('click', (e) => {
            const a = e.target.closest('a');
            if (!a) return;
            const href = a.getAttribute('href');
            if (!href) return;

            if (href.startsWith('sound://')) {
              e.preventDefault();
              const soundFile = href.replace('sound://', '');
              new Audio('${baseHref}' + soundFile).play().catch(() => {});
            } else if (href.startsWith('entry://')) {
              e.preventDefault();
              const targetWord = href.replace('entry://', '').replace(/^#/, '');
              window.parent.postMessage({
                type: 'CIYUE_ENTRY_CLICK',
                word: targetWord
              }, '*');
            }
          });
        <` + `/script>
      </body>
      </html>
    `);
    frameDoc.close();
  }

  function handleMessage(e: MessageEvent) {
    if (!e.data) return;
    if (e.data.type === 'CIYUE_IFRAME_RESIZE' && e.data.frameId === frameId) {
      const targetH = Math.min(Math.max(e.data.height + 8, 120), 450);
      frameHeight = `${targetH}px`;
    } else if (e.data.type === 'CIYUE_ENTRY_CLICK' && e.data.word) {
      onSubLookup?.(e.data.word);
    }
  }

  onMount(() => {
    window.addEventListener('message', handleMessage);
    renderFrameContent();
  });

  onDestroy(() => {
    window.removeEventListener('message', handleMessage);
  });

  $effect(() => {
    const _ = item;
    renderFrameContent();
  });
</script>

<div class="border border-zinc-200 dark:border-zinc-800 rounded-xl overflow-hidden bg-white dark:bg-zinc-900 shadow-xs mt-2 transition-all">
  <!-- svelte-ignore a11y_click_events_have_key_events -->
  <!-- svelte-ignore a11y_no_static_element_interactions -->
  <div
    class="px-3 py-2 bg-zinc-50/70 hover:bg-zinc-100/70 dark:bg-zinc-800/40 dark:hover:bg-zinc-800/70 cursor-pointer flex items-center justify-between text-xs font-semibold select-none transition-colors border-b border-transparent {isCollapsed ? '' : 'border-zinc-100 dark:border-zinc-800/60'}"
    onclick={() => (isCollapsed = !isCollapsed)}
  >
    <div class="flex items-center gap-1.5 min-w-0">
      <ChevronDown
        class="w-3.5 h-3.5 text-primary-600 dark:text-primary-400 shrink-0 transition-transform duration-200 {isCollapsed ? '-rotate-90' : ''}"
      />
      <span class="text-zinc-800 dark:text-zinc-200 truncate">
        {item.dictTitle || '词典'}
      </span>
    </div>
    {#if item.headword}
      <span class="text-[11px] font-normal text-zinc-400 dark:text-zinc-500 truncate max-w-[140px] ml-2">
        {item.headword}
      </span>
    {/if}
  </div>

  <div style:display={isCollapsed ? 'none' : 'block'}>
    <iframe
      bind:this={frameRef}
      class="w-full border-none block bg-white dark:bg-zinc-900 transition-[height] duration-150"
      style:height={frameHeight}
      sandbox="allow-same-origin allow-scripts"
      title={item.dictTitle || '词典条目'}
    ></iframe>
  </div>
</div>
