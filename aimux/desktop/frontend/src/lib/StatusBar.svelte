<script lang="ts">
    import { workspaces } from '../stores/workspaces';
    import { queueEntries } from '../stores/queue';
    import { unreadCount } from '../stores/notifications';
    import { derived } from 'svelte/store';

    const workingCount = derived(workspaces, $w =>
        $w.filter(w => w.agent_state === 'working' || w.status === 'running').length
    );
    const queuedCount = derived(queueEntries, $q =>
        $q.filter(e => e.status === 'queued').length
    );
</script>

<div class="statusbar">
    <div class="left">
        <span class="item">
            <span class="dot" style="background: var(--green)"></span>
            {$workspaces.length} workspace{$workspaces.length !== 1 ? 's' : ''}
        </span>
        {#if $workingCount > 0}
            <span class="item">
                <span class="dot" style="background: var(--red)"></span>
                {$workingCount} active
            </span>
        {/if}
    </div>
    <div class="right">
        {#if $queuedCount > 0}
            <span class="item">{$queuedCount} queued</span>
        {/if}
        {#if $unreadCount > 0}
            <span class="item notifications">{$unreadCount} notification{$unreadCount !== 1 ? 's' : ''}</span>
        {/if}
    </div>
</div>

<style>
    .statusbar {
        height: var(--statusbar-height);
        background: var(--bg-dark);
        border-top: 1px solid var(--border);
        display: flex;
        align-items: center;
        justify-content: space-between;
        padding: 0 12px;
        font-size: 11px;
        color: var(--comment);
        flex-shrink: 0;
    }

    .left, .right {
        display: flex;
        gap: 12px;
        align-items: center;
    }

    .item {
        display: flex;
        align-items: center;
        gap: 4px;
    }

    .dot {
        width: 6px;
        height: 6px;
        border-radius: 50%;
    }

    .notifications {
        color: var(--yellow);
    }
</style>
