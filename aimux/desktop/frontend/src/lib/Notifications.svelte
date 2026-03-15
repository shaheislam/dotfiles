<script lang="ts">
    import { notifications, unreadCount, markRead, clearAll } from '../stores/notifications';

    export let visible = false;

    const typeColors: Record<string, string> = {
        info: 'var(--blue)',
        success: 'var(--green)',
        warning: 'var(--yellow)',
        error: 'var(--red)',
    };

    function formatTime(timestamp: string): string {
        const d = new Date(timestamp);
        return d.toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' });
    }
</script>

{#if visible}
    <div class="notifications-panel">
        <div class="panel-header">
            <span>Notifications ({$unreadCount})</span>
            <button on:click={clearAll}>Clear all</button>
        </div>

        <div class="notification-list">
            {#each $notifications as notif (notif.id)}
                <div
                    class="notification"
                    class:unread={!notif.read}
                    on:click={() => markRead(notif.id)}
                    on:keypress={() => markRead(notif.id)}
                    role="button"
                    tabindex="0"
                >
                    <div class="notif-dot" style="background: {typeColors[notif.type] || 'var(--comment)'}"></div>
                    <div class="notif-content">
                        <div class="notif-title">{notif.title}</div>
                        <div class="notif-message">{notif.message}</div>
                    </div>
                    <div class="notif-time">{formatTime(notif.timestamp)}</div>
                </div>
            {/each}

            {#if $notifications.length === 0}
                <div class="empty">No notifications</div>
            {/if}
        </div>
    </div>
{/if}

<style>
    .notifications-panel {
        position: absolute;
        top: 38px;
        right: 16px;
        width: 320px;
        max-height: 400px;
        background: var(--bg-dark);
        border: 1px solid var(--border);
        border-radius: 8px;
        overflow: hidden;
        z-index: 100;
        box-shadow: 0 8px 32px rgba(0, 0, 0, 0.4);
    }

    .panel-header {
        display: flex;
        align-items: center;
        justify-content: space-between;
        padding: 10px 14px;
        border-bottom: 1px solid var(--border);
        font-size: 12px;
        font-weight: 600;
        color: var(--fg-dark);
    }
    .panel-header button {
        background: none;
        border: none;
        color: var(--comment);
        cursor: pointer;
        font-size: 11px;
    }
    .panel-header button:hover {
        color: var(--fg);
    }

    .notification-list {
        max-height: 350px;
        overflow-y: auto;
    }

    .notification {
        display: flex;
        align-items: flex-start;
        gap: 8px;
        padding: 10px 14px;
        cursor: pointer;
        border-bottom: 1px solid var(--border);
        transition: background 0.1s;
    }
    .notification:hover {
        background: var(--bg-highlight);
    }
    .notification.unread {
        background: rgba(122, 162, 247, 0.05);
    }

    .notif-dot {
        width: 6px;
        height: 6px;
        border-radius: 50%;
        flex-shrink: 0;
        margin-top: 5px;
    }

    .notif-content {
        flex: 1;
        min-width: 0;
    }
    .notif-title {
        font-size: 12px;
        font-weight: 500;
    }
    .notif-message {
        font-size: 11px;
        color: var(--comment);
        margin-top: 2px;
        white-space: nowrap;
        overflow: hidden;
        text-overflow: ellipsis;
    }

    .notif-time {
        font-size: 10px;
        color: var(--comment);
        flex-shrink: 0;
    }

    .empty {
        padding: 24px;
        text-align: center;
        color: var(--comment);
        font-size: 12px;
    }
</style>
