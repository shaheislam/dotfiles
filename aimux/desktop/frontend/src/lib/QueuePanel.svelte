<script lang="ts">
    import { queueEntries, addToQueue, removeFromQueue, refreshQueue } from '../stores/queue';
    import { onMount } from 'svelte';

    let showAddForm = false;
    let newTicket = '';
    let newPrompt = '';
    let newProvider = 'claude';
    let newPriority = 2;

    onMount(() => {
        refreshQueue();
        const interval = setInterval(refreshQueue, 5000);
        return () => clearInterval(interval);
    });

    async function handleAdd() {
        if (!newTicket.trim()) return;
        await addToQueue(newTicket.trim(), newPrompt.trim(), newProvider, newPriority);
        newTicket = '';
        newPrompt = '';
        showAddForm = false;
    }

    const statusColors: Record<string, string> = {
        queued: 'var(--yellow)',
        dispatching: 'var(--orange)',
        running: 'var(--red)',
        completed: 'var(--green)',
        failed: 'var(--red)',
    };
</script>

<div class="queue-panel">
    <div class="panel-header">
        <span>Queue</span>
        <button on:click={() => showAddForm = !showAddForm}>+</button>
    </div>

    {#if showAddForm}
        <form class="add-form" on:submit|preventDefault={handleAdd}>
            <input bind:value={newTicket} placeholder="Ticket (e.g. PROJ-123)" />
            <input bind:value={newPrompt} placeholder="Prompt" />
            <div class="form-row">
                <select bind:value={newProvider}>
                    <option value="claude">Claude</option>
                    <option value="codex">Codex</option>
                    <option value="ollama">Ollama</option>
                </select>
                <button type="submit">Add</button>
            </div>
        </form>
    {/if}

    <div class="entries">
        {#each $queueEntries as entry (entry.ticket)}
            <div class="entry">
                <div class="entry-dot" style="background: {statusColors[entry.status] || 'var(--comment)'}"></div>
                <div class="entry-info">
                    <div class="entry-ticket">{entry.ticket}</div>
                    <div class="entry-meta">{entry.status} - {entry.provider}</div>
                </div>
                {#if entry.status === 'queued'}
                    <button class="remove-btn" on:click={() => removeFromQueue(entry.ticket)}>x</button>
                {/if}
            </div>
        {/each}

        {#if $queueEntries.length === 0}
            <div class="empty">Queue empty</div>
        {/if}
    </div>
</div>

<style>
    .queue-panel {
        border-top: 1px solid var(--border);
        background: var(--bg-dark);
    }

    .panel-header {
        display: flex;
        align-items: center;
        justify-content: space-between;
        padding: 8px 16px;
        font-weight: 600;
        font-size: 12px;
        text-transform: uppercase;
        letter-spacing: 0.5px;
        color: var(--comment);
    }
    .panel-header button {
        width: 20px;
        height: 20px;
        border-radius: 4px;
        border: 1px solid var(--border);
        background: transparent;
        color: var(--fg-dark);
        cursor: pointer;
        font-size: 14px;
        display: flex;
        align-items: center;
        justify-content: center;
    }

    .add-form {
        padding: 8px 12px;
        display: flex;
        flex-direction: column;
        gap: 6px;
        border-bottom: 1px solid var(--border);
    }
    .add-form input, .add-form select {
        padding: 6px 8px;
        border-radius: 4px;
        border: 1px solid var(--border);
        background: var(--bg);
        color: var(--fg);
        font-size: 12px;
        outline: none;
    }
    .add-form input:focus {
        border-color: var(--blue);
    }
    .form-row {
        display: flex;
        gap: 6px;
    }
    .form-row select { flex: 1; }
    .form-row button {
        padding: 6px 12px;
        border-radius: 4px;
        border: none;
        background: var(--blue);
        color: var(--bg);
        font-size: 12px;
        cursor: pointer;
        font-weight: 600;
    }

    .entries {
        max-height: 200px;
        overflow-y: auto;
    }

    .entry {
        display: flex;
        align-items: center;
        gap: 8px;
        padding: 6px 12px;
    }
    .entry:hover {
        background: var(--bg-highlight);
    }

    .entry-dot {
        width: 6px;
        height: 6px;
        border-radius: 50%;
        flex-shrink: 0;
    }

    .entry-info { flex: 1; }
    .entry-ticket { font-size: 12px; font-weight: 500; }
    .entry-meta { font-size: 11px; color: var(--comment); }

    .remove-btn {
        background: none;
        border: none;
        color: var(--comment);
        cursor: pointer;
        font-size: 16px;
        padding: 0 4px;
    }
    .remove-btn:hover { color: var(--red); }

    .empty {
        padding: 16px;
        text-align: center;
        color: var(--comment);
        font-size: 12px;
    }
</style>
