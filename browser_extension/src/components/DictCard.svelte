<script lang="ts">
  import { onMount, onDestroy } from 'svelte';
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
        <script src="${darkReaderUrl}"><\/script>
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
        <\/script>
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

<div class="ciyue-dict-card" class:collapsed={isCollapsed}>
  <!-- svelte-ignore a11y_click_events_have_key_events -->
  <!-- svelte-ignore a11y_no_static_element_interactions -->
  <div class="dict-card-header" onclick={() => (isCollapsed = !isCollapsed)}>
    <div class="dict-title-group">
      <span class="chevron">▼</span>
      <span class="dict-title">{item.dictTitle || '词典'}</span>
    </div>
    {#if item.headword}
      <span class="dict-headword">{item.headword}</span>
    {/if}
  </div>
  <div class="dict-card-body" style:display={isCollapsed ? 'none' : 'block'}>
    <iframe
      bind:this={frameRef}
      class="dict-frame"
      style:height={frameHeight}
      sandbox="allow-same-origin allow-scripts"
      title={item.dictTitle || '词典条目'}
    ></iframe>
  </div>
</div>

<style>
  .ciyue-dict-card {
    border: 1px solid var(--border);
    border-radius: 10px;
    margin-top: 8px;
    overflow: hidden;
    background: var(--card-bg);
    box-shadow: 0 1px 3px rgba(0, 0, 0, 0.05);
  }
  .dict-card-header {
    padding: 8px 12px;
    background: var(--surface);
    cursor: pointer;
    display: flex;
    align-items: center;
    justify-content: space-between;
    font-size: 13px;
    font-weight: 600;
    user-select: none;
    transition: background 0.15s ease;
  }
  .dict-card-header:hover {
    background: var(--surface-variant);
  }
  .dict-title-group {
    display: flex;
    align-items: center;
    gap: 6px;
    min-width: 0;
  }
  .chevron {
    font-size: 9px;
    color: var(--primary);
    transition: transform 0.2s ease;
    display: inline-block;
  }
  .ciyue-dict-card.collapsed .chevron {
    transform: rotate(-90deg);
  }
  .dict-title {
    white-space: nowrap;
    overflow: hidden;
    text-overflow: ellipsis;
  }
  .dict-headword {
    font-size: 11px;
    color: var(--text-muted);
    white-space: nowrap;
    overflow: hidden;
    text-overflow: ellipsis;
    max-width: 140px;
  }
  .dict-card-body {
    width: 100%;
  }
  .dict-frame {
    width: 100%;
    border: none;
    display: block;
    background: var(--card-bg);
    transition: height 0.15s ease;
  }
</style>
