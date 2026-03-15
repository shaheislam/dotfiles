import { writable, derived } from 'svelte/store';
import type { Workspace } from '../types';

export const workspaces = writable<Workspace[]>([]);
export const activeWorkspace = writable<string | null>(null);

export const activeWorkspaceData = derived(
    [workspaces, activeWorkspace],
    ([$workspaces, $active]) => $workspaces.find(w => w.name === $active) ?? null
);

let pollInterval: ReturnType<typeof setInterval>;

export async function refreshWorkspaces() {
    try {
        // @ts-ignore - Wails generates this at build time
        const list = await window.go.main.App.ListWorkspaces();
        workspaces.set(list || []);
    } catch (e) {
        console.error('Failed to list workspaces:', e);
    }
}

export function startPolling(ms = 3000) {
    refreshWorkspaces();
    pollInterval = setInterval(refreshWorkspaces, ms);
}

export function stopPolling() {
    if (pollInterval) clearInterval(pollInterval);
}
