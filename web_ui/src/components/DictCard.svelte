<script lang="ts">
  import { onMount, onDestroy } from 'svelte';
  import ChevronDown from 'lucide-svelte/icons/chevron-down';
  import type { DictionaryResult } from '../api/types';
  import { splitEntryDoctype } from '../utils/entry';

  let {
    item,
    index,
    targetAnchor = '',
    isTargetDict = false,
    isDark = false,
    onSubLookup,
  }: {
    item: DictionaryResult;
    index: number;
    targetAnchor?: string;
    isTargetDict?: boolean;
    isDark?: boolean;
    onSubLookup?: (word: string, anchor?: string, dictId?: number | string) => void;
  } = $props();

  let isCollapsed = $state(false);
  let frameRef: HTMLIFrameElement | null = $state(null);
  let frameHeight = $state('220px');
  let frameId = $derived(`ciyue-web-frame-${index}`);

  export function setCollapsed(val: boolean) {
    isCollapsed = val;
  }

  function renderFrameContent() {
    if (!frameRef) return;
    const frameDoc = frameRef.contentDocument || frameRef.contentWindow?.document;
    if (!frameDoc) return;

    const baseHref = item.resourceBase.startsWith('http')
      ? item.resourceBase
      : `${window.location.origin}${item.resourceBase}`;
    const darkReaderUrl = '/assets/darkreader.js';
    const entry = splitEntryDoctype(item.content);

    frameDoc.open();
    frameDoc.write(`
      ${entry.doctype}
      <html>
      <head>
        <base href="${baseHref}">
        <meta charset="utf-8">
        <style>
          * { box-sizing: border-box; }
          body {
            font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, "Helvetica Neue", Arial, sans-serif;
            padding: 12px 16px;
            margin: 0;
            line-height: 1.5;
            font-size: 14px;
            color: #1f1f1f;
            overflow-x: hidden;
          }
          a { color: #2563eb; text-decoration: none; cursor: pointer; }
          a:hover { text-decoration: underline; }
          img { max-width: 100%; height: auto; }
        </style>
        <script src="${darkReaderUrl}"><` + `/script>
      </head>
      <body>
        ${entry.content}
        <script>
          function syncTheme(dark) {
            if (!window.DarkReader) return;
            try {
              if (dark) {
                window.DarkReader.setFetchMethod(window.fetch);
                window.DarkReader.enable({
                  brightness: 100, contrast: 100, sepia: 0,
                  darkSchemeBackgroundColor: "#18181b", darkSchemeTextColor: "#f4f4f5"
                });
              } else if (window.DarkReader.isEnabled && window.DarkReader.isEnabled()) {
                window.DarkReader.disable();
              }
            } catch (_) {}
          }

          syncTheme(${isDark});

          window.addEventListener('message', (e) => {
            if (e.data && e.data.type === 'THEME_SYNC') {
              syncTheme(e.data.isDark);
            }
          });

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

          function __decode(val) {
            try { return decodeURIComponent(val); } catch(_) { return val; }
          }

          function __parseEntryLink(raw) {
            let w = '', i = 0;
            while (i < raw.length) {
              const ch = raw.charAt(i);
              if (ch !== '#') { w += ch; i++; continue; }
              if (raw.charAt(i + 1) === '#') { w += '#'; i += 2; continue; }
              return { word: __decode(w), anchor: __decode(raw.slice(i + 1)) };
            }
            return { word: __decode(w), anchor: '' };
          }

          document.addEventListener('click', (e) => {
            const a = e.target.closest('a');
            if (!a) return;
            const href = a.getAttribute('href');
            if (!href) return;

            if (href.startsWith('sound://')) {
              e.preventDefault();
              let soundFile = href.replace('sound://', '');
              if (soundFile.toLowerCase().startsWith('localhost/')) {
                soundFile = soundFile.slice('localhost/'.length);
              }
              try { soundFile = decodeURIComponent(soundFile); } catch(_) {}
              new Audio('${baseHref}' + encodeURIComponent(soundFile)).play().catch(() => {});
            } else if (href.startsWith('gdlookup://localhost/')) {
              e.preventDefault();
              const rest = href.slice('gdlookup://localhost/'.length);
              const q = rest.indexOf('?');
              const payload = q < 0 ? rest : rest.slice(0, q);
              const query = q < 0 ? '' : rest.slice(q + 1);
              let anchor = '';
              if (query) {
                anchor = new URLSearchParams(query).get('gdanchor') || '';
              }
              window.parent.postMessage({
                type: 'LOOKUP',
                word: __decode(payload),
                anchor: anchor,
                dictId: '${item.dictId}'
              }, '*');
            } else if (href.startsWith('entry://')) {
              e.preventDefault();
              const target = __parseEntryLink(href.slice('entry://'.length));
              window.parent.postMessage({
                type: 'LOOKUP',
                word: target.word,
                anchor: target.anchor,
                dictId: '${item.dictId}'
              }, '*');
            }
          });
        <` + `/script>
      </body>
      </html>
    `);
    frameDoc.close();

    frameRef.onload = () => {
      if (isTargetDict && targetAnchor) {
        try {
          const el = frameDoc.getElementById(targetAnchor) ||
                     frameDoc.getElementsByName(targetAnchor)[0];
          if (el) el.scrollIntoView({ block: 'start' });
        } catch {}
      }
    };
  }

  function handleMessage(e: MessageEvent) {
    if (!e.data) return;
    if (e.data.type === 'CIYUE_IFRAME_RESIZE' && e.data.frameId === frameId) {
      const targetH = Math.min(Math.max(e.data.height + 10, 140), 700);
      frameHeight = `${targetH}px`;
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
    const __ = isDark;
    renderFrameContent();
  });
</script>

<div class="border border-zinc-200 dark:border-zinc-800 rounded-2xl overflow-hidden bg-white dark:bg-zinc-900 shadow-xs transition-all">
  <!-- svelte-ignore a11y_click_events_have_key_events -->
  <!-- svelte-ignore a11y_no_static_element_interactions -->
  <div
    class="px-4 py-3 bg-zinc-50/80 hover:bg-zinc-100/70 dark:bg-zinc-850/60 dark:hover:bg-zinc-800/80 cursor-pointer flex items-center justify-between text-xs font-semibold select-none transition-colors border-b border-transparent {isCollapsed ? '' : 'border-zinc-100 dark:border-zinc-800/60'}"
    onclick={() => (isCollapsed = !isCollapsed)}
  >
    <div class="flex items-center gap-2 min-w-0">
      <ChevronDown
        class="w-4 h-4 text-primary-600 dark:text-primary-400 shrink-0 transition-transform duration-200 {isCollapsed ? '-rotate-90' : ''}"
      />
      <span class="text-zinc-900 dark:text-zinc-100 font-bold truncate">
        {item.dictTitle || '词典'}
      </span>
    </div>
    {#if item.headword}
      <span class="text-[11px] font-normal text-zinc-400 dark:text-zinc-500 truncate max-w-[200px] ml-2">
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
