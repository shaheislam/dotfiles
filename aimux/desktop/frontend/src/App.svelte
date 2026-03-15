<script lang="ts">
    import { onMount, onDestroy } from 'svelte';
    import Sidebar from './lib/Sidebar.svelte';
    import Terminal from './lib/Terminal.svelte';
    import QueuePanel from './lib/QueuePanel.svelte';
    import StatusBar from './lib/StatusBar.svelte';
    import Notifications from './lib/Notifications.svelte';
    import { workspaces, activeWorkspace, startPolling, stopPolling } from './stores/workspaces';

    let wsPort = 0;
    let terminals: Map<string, string> = new Map();
    let showQueue = false;
    let showNotifications = false;

    onMount(async () => {
        // Get WebSocket port from backend
        try {
            // @ts-ignore - Wails generates this at build time
            wsPort = await window.go.main.App.GetWSPort();
        } catch (e) {
            console.error('Failed to get WS port:', e);
        }

        startPolling();

        // Create a default terminal
        await createDefaultTerminal();
    });

    onDestroy(() => {
        stopPolling();
    });

    async function createDefaultTerminal() {
        try {
            const id = 'default';
            // @ts-ignore
            await window.go.main.App.CreateTerminal(id, '');
            terminals.set(id, id);
            terminals = terminals;
            if (!$activeWorkspace) {
                activeWorkspace.set(id);
            }
        } catch (e) {
            console.error('Failed to create default terminal:', e);
        }
    }

    async function handleCreateWorkspace() {
        const branch = prompt('Branch name:');
        if (!branch) return;

        try {
            // @ts-ignore
            const ws = await window.go.main.App.CreateWorkspace(branch, true);

            // Create terminal for this workspace
            const termId = ws.name || branch;
            // @ts-ignore
            await window.go.main.App.CreateTerminal(termId, ws.worktree || '');
            terminals.set(termId, termId);
            terminals = terminals;

            activeWorkspace.set(termId);
        } catch (e) {
            console.error('Failed to create workspace:', e);
        }
    }

    function handleKeydown(e: KeyboardEvent) {
        // Cmd/Ctrl + Q: Toggle queue panel
        if ((e.metaKey || e.ctrlKey) && e.key === 'q') {
            e.preventDefault();
            showQueue = !showQueue;
        }
        // Cmd/Ctrl + N: Toggle notifications
        if ((e.metaKey || e.ctrlKey) && e.key === 'n') {
            e.preventDefault();
            showNotifications = !showNotifications;
        }
    }
</script>

<svelte:window on:keydown={handleKeydown} />

<div id="app">
    <div class="titlebar">
        <span>aimux</span>
    </div>

    <div class="main">
        <Sidebar onCreateWorkspace={handleCreateWorkspace} />

        <div class="content">
            <div class="terminal-area">
                {#if wsPort > 0}
                    {#each [...terminals.entries()] as [id, _] (id)}
                        <div class="terminal-pane" class:active={$activeWorkspace === id}>
                            <Terminal sessionId={id} {wsPort} />
                        </div>
                    {/each}
                {:else}
                    <div class="loading">Connecting...</div>
                {/if}
            </div>

            {#if showQueue}
                <QueuePanel />
            {/if}
        </div>
    </div>

    <Notifications visible={showNotifications} />

    <StatusBar />
</div>

<style>
    .main {
        flex: 1;
        display: flex;
        overflow: hidden;
    }

    .content {
        flex: 1;
        display: flex;
        flex-direction: column;
        overflow: hidden;
    }

    .terminal-area {
        flex: 1;
        position: relative;
        overflow: hidden;
    }

    .terminal-pane {
        position: absolute;
        inset: 0;
        display: none;
    }
    .terminal-pane.active {
        display: block;
    }

    .loading {
        display: flex;
        align-items: center;
        justify-content: center;
        height: 100%;
        color: var(--comment);
    }
</style>
