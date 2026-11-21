<script lang="ts">
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

<div class="ciyue-word-header">
  <div class="ciyue-title-area">
    <span class="ciyue-book-icon">📖</span>
    <span class="ciyue-word-text" title={word}>{word}</span>
  </div>
  <div class="ciyue-actions">
    <button
      class="ciyue-icon-btn star-btn"
      class:active={stared}
      class:loading={loadingStar}
      title={stared ? '从生词本移除' : '加入生词本'}
      onclick={onToggleStar}
    >
      {stared ? '★' : '☆'}
    </button>
    {#if showClose}
      <button
        class="ciyue-icon-btn close-btn"
        title="关闭"
        onclick={onClose}
      >
        ✕
      </button>
    {/if}
  </div>
</div>

<style>
  .ciyue-word-header {
    padding: 10px 14px;
    background: var(--surface);
    display: flex;
    align-items: center;
    justify-content: space-between;
    border-bottom: 1px solid var(--border);
    user-select: none;
  }
  .ciyue-title-area {
    display: flex;
    align-items: center;
    gap: 8px;
    min-width: 0;
  }
  .ciyue-book-icon {
    font-size: 16px;
    flex-shrink: 0;
  }
  .ciyue-word-text {
    font-size: 16px;
    font-weight: 700;
    color: var(--primary);
    white-space: nowrap;
    overflow: hidden;
    text-overflow: ellipsis;
  }
  .ciyue-actions {
    display: flex;
    align-items: center;
    gap: 6px;
    flex-shrink: 0;
  }
  .ciyue-icon-btn {
    background: none;
    border: none;
    cursor: pointer;
    padding: 4px 8px;
    border-radius: 8px;
    font-size: 14px;
    color: var(--text-muted);
    display: flex;
    align-items: center;
    justify-content: center;
    transition: all 0.15s ease;
  }
  .ciyue-icon-btn:hover {
    background: rgba(128, 128, 128, 0.15);
    color: var(--text);
  }
  .star-btn {
    font-size: 18px;
    line-height: 1;
  }
  .star-btn.active {
    color: var(--star);
  }
  .close-btn {
    font-size: 13px;
  }
</style>
