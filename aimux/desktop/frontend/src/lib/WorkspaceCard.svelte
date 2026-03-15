<script lang="ts">
    import { createEventDispatcher } from 'svelte';
    import type { Workspace } from '../types';

    export let workspace: Workspace;
    export let active = false;

    const dispatch = createEventDispatcher();

    const stateColors: Record<string, string> = {
        working: 'var(--red)',
        idle: 'var(--yellow)',
        done: 'var(--green)',
        stuck: 'var(--magenta)',
        failed: 'var(--red)',
        active: 'var(--blue)',
        running: 'var(--red)',
        completed: 'var(--green)',
    };

    $: stateColor = stateColors[workspace.agent_state || workspace.status] || 'var(--comment)';
    $: displayName = workspace.branch || workspace.name;
    $: provider = workspace.provider || '';
</script>

<button
    class="card"
    class:active
    on:click
>
    <div class="indicator" style="background: {stateColor}"></div>
    <div class="info">
        <div class="name">{displayName}</div>
        <div class="meta">
            {#if workspace.ticket}
                <span class="ticket">{workspace.ticket}</span>
            {/if}
            {#if provider}
                <span class="provider">{provider}</span>
            {/if}
        </div>
    </div>
    <div class="status-dot" style="background: {stateColor}"></div>
</button>

<style>
    .card {
        display: flex;
        align-items: center;
        gap: 10px;
        width: 100%;
        padding: 10px 12px;
        border-radius: 8px;
        border: 1px solid transparent;
        background: transparent;
        color: var(--fg);
        cursor: pointer;
        text-align: left;
        transition: all 0.15s;
        margin-bottom: 2px;
    }
    .card:hover {
        background: var(--bg-highlight);
    }
    .card.active {
        background: var(--bg-highlight);
        border-color: var(--blue);
    }

    .indicator {
        width: 3px;
        height: 28px;
        border-radius: 2px;
        flex-shrink: 0;
    }

    .info {
        flex: 1;
        min-width: 0;
    }

    .name {
        font-size: 13px;
        font-weight: 500;
        white-space: nowrap;
        overflow: hidden;
        text-overflow: ellipsis;
    }

    .meta {
        display: flex;
        gap: 6px;
        margin-top: 2px;
    }

    .ticket, .provider {
        font-size: 11px;
        color: var(--comment);
    }

    .provider {
        color: var(--cyan);
    }

    .status-dot {
        width: 8px;
        height: 8px;
        border-radius: 50%;
        flex-shrink: 0;
    }
</style>
