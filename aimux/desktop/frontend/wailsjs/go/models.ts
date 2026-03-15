export namespace main {
	
	export class QueueEntry {
	    ticket: string;
	    prompt: string;
	    provider: string;
	    priority: number;
	    status: string;
	    added_at: string;
	    started_at?: string;
	    completed_at?: string;
	
	    static createFrom(source: any = {}) {
	        return new QueueEntry(source);
	    }
	
	    constructor(source: any = {}) {
	        if ('string' === typeof source) source = JSON.parse(source);
	        this.ticket = source["ticket"];
	        this.prompt = source["prompt"];
	        this.provider = source["provider"];
	        this.priority = source["priority"];
	        this.status = source["status"];
	        this.added_at = source["added_at"];
	        this.started_at = source["started_at"];
	        this.completed_at = source["completed_at"];
	    }
	}
	export class WorkspaceInfo {
	    name: string;
	    branch: string;
	    status: string;
	    provider: string;
	    ticket: string;
	    worktree: string;
	    agent_state: string;
	    created_at: string;
	    terminal_id: string;
	
	    static createFrom(source: any = {}) {
	        return new WorkspaceInfo(source);
	    }
	
	    constructor(source: any = {}) {
	        if ('string' === typeof source) source = JSON.parse(source);
	        this.name = source["name"];
	        this.branch = source["branch"];
	        this.status = source["status"];
	        this.provider = source["provider"];
	        this.ticket = source["ticket"];
	        this.worktree = source["worktree"];
	        this.agent_state = source["agent_state"];
	        this.created_at = source["created_at"];
	        this.terminal_id = source["terminal_id"];
	    }
	}

}

