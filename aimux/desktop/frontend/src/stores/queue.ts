import { writable } from 'svelte/store';
import type { QueueEntry } from '../types';

export const queueEntries = writable<QueueEntry[]>([]);

export async function refreshQueue() {
    try {
        // @ts-ignore - Wails generates this at build time
        const list = await window.go.main.App.ListQueue();
        queueEntries.set(list || []);
    } catch (e) {
        console.error('Failed to list queue:', e);
    }
}

export async function addToQueue(ticket: string, prompt: string, provider: string, priority: number) {
    try {
        // @ts-ignore
        await window.go.main.App.AddToQueue(ticket, prompt, provider, priority);
        await refreshQueue();
    } catch (e) {
        console.error('Failed to add to queue:', e);
    }
}

export async function removeFromQueue(ticket: string) {
    try {
        // @ts-ignore
        await window.go.main.App.RemoveFromQueue(ticket);
        await refreshQueue();
    } catch (e) {
        console.error('Failed to remove from queue:', e);
    }
}
