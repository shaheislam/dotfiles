<script lang="ts">
    import { workspaces, activeWorkspace } from '../stores/workspaces';
    import WorkspaceCard from './WorkspaceCard.svelte';

    export let onCreateWorkspace: () => void;

    function selectWorkspace(name: string) {
        activeWorkspace.set(name);
    }
</script>

<div class="sidebar">
    <div class="sidebar-header">
        <span class="logo">aimux</span>
        <button class="new-btn" on:click={onCreateWorkspace} title="New Workspace">+</button>
    </div>

    <div class="workspace-list">
        {#each $workspaces as workspace (workspace.name)}
            <WorkspaceCard
                {workspace}
                active={$activeWorkspace === workspace.name}
                on:click={() => selectWorkspace(workspace.name)}
            />
        {/each}

        {#if $workspaces.length === 0}
            <div class="empty">
                <span>No workspaces</span>
                <button on:click={onCreateWorkspace}>Create one</button>
            </div>
        {/if}
    </div>
</div>

<style>
    .sidebar {
        width: var(--sidebar-width);
        background: var(--bg-dark);
        border-right: 1px solid var(--border);
        display: flex;
        flex-direction: column;
        flex-shrink: 0;
        overflow: hidden;
    }

    .sidebar-header {
        display: flex;
        align-items: center;
        justify-content: space-between;
        padding: 12px 16px;
        border-bottom: 1px solid var(--border);
    }

    .logo {
        font-weight: 700;
        font-size: 15px;
        color: var(--blue);
        letter-spacing: 0.5px;
    }

    .new-btn {
        width: 24px;
        height: 24px;
        border-radius: 6px;
        border: 1px solid var(--border);
        background: transparent;
        color: var(--fg-dark);
        font-size: 16px;
        cursor: pointer;
        display: flex;
        align-items: center;
        justify-content: center;
        transition: all 0.15s;
    }
    .new-btn:hover {
        background: var(--bg-highlight);
        color: var(--fg);
        border-color: var(--comment);
    }

    .workspace-list {
        flex: 1;
        overflow-y: auto;
        padding: 8px;
    }

    .empty {
        display: flex;
        flex-direction: column;
        align-items: center;
        gap: 8px;
        padding: 24px 16px;
        color: var(--comment);
    }
    .empty button {
        padding: 6px 12px;
        border-radius: 6px;
        border: 1px solid var(--border);
        background: transparent;
        color: var(--blue);
        cursor: pointer;
        font-size: 12px;
    }
    .empty button:hover {
        background: var(--bg-highlight);
    }
</style>
