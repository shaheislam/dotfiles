import { writable, derived } from 'svelte/store';
import type { Notification } from '../types';

export const notifications = writable<Notification[]>([]);

export const unreadCount = derived(notifications, $n => $n.filter(n => !n.read).length);

export function addNotification(title: string, message: string, type: Notification['type'] = 'info') {
    const notification: Notification = {
        id: crypto.randomUUID(),
        title,
        message,
        type,
        timestamp: new Date().toISOString(),
        read: false,
    };
    notifications.update(n => [notification, ...n]);
}

export function markRead(id: string) {
    notifications.update(n => n.map(x => x.id === id ? { ...x, read: true } : x));
}

export function clearAll() {
    notifications.set([]);
}
