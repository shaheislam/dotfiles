export interface Workspace {
    name: string;
    branch: string;
    status: string;
    provider: string;
    ticket: string;
    worktree: string;
    agent_state: string;
    created_at: string;
    terminal_id: string;
}

export interface QueueEntry {
    ticket: string;
    prompt: string;
    provider: string;
    priority: number;
    status: string;
    added_at: string;
    started_at: string | null;
    completed_at: string | null;
}

export interface Notification {
    id: string;
    title: string;
    message: string;
    type: 'info' | 'success' | 'warning' | 'error';
    timestamp: string;
    read: boolean;
}
