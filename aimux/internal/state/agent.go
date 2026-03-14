// Package state manages workspace and agent state persistence.
//
// Agent states follow a simple state machine:
//
//	idle -> working -> done
//	idle -> working -> stuck
//	idle -> working -> idle (agent paused/restarted)
//	idle -> done (agent finished instantly)
//	any  -> failed (process crashed or disappeared)
package state

// AgentState represents the current state of an AI agent in a workspace.
type AgentState string

const (
	// AgentIdle means the agent process is present but not actively generating output.
	AgentIdle AgentState = "idle"
	// AgentWorking means the agent is actively generating output (e.g., thinking spinner).
	AgentWorking AgentState = "working"
	// AgentDone means the agent has completed its task.
	AgentDone AgentState = "done"
	// AgentStuck means the agent has had no output change for longer than the stuck timeout.
	AgentStuck AgentState = "stuck"
	// AgentFailed means the agent process has crashed or is no longer running.
	AgentFailed AgentState = "failed"
)

// validTransitions defines allowed state transitions.
// The key is the source state; the value is the set of valid target states.
var validTransitions = map[AgentState]map[AgentState]bool{
	AgentIdle: {
		AgentWorking: true,
		AgentDone:    true,
		AgentFailed:  true,
	},
	AgentWorking: {
		AgentIdle:   true,
		AgentDone:   true,
		AgentStuck:  true,
		AgentFailed: true,
	},
	AgentDone: {
		AgentIdle:   true, // agent restarted
		AgentFailed: true,
	},
	AgentStuck: {
		AgentIdle:    true, // agent unstuck / resumed
		AgentWorking: true, // agent resumed
		AgentDone:    true,
		AgentFailed:  true,
	},
	AgentFailed: {
		AgentIdle: true, // process restarted
	},
}

// Transition returns true if the state transition from -> to is valid.
func Transition(from, to AgentState) bool {
	targets, ok := validTransitions[from]
	if !ok {
		return false
	}
	return targets[to]
}

// IsTerminal returns true if the state is a terminal state (done or failed).
func IsTerminal(s AgentState) bool {
	return s == AgentDone || s == AgentFailed
}

// String returns the string representation of the agent state.
func (s AgentState) String() string {
	return string(s)
}

// ParseAgentState converts a string to an AgentState, defaulting to AgentIdle
// for unrecognized values.
func ParseAgentState(s string) AgentState {
	switch AgentState(s) {
	case AgentIdle, AgentWorking, AgentDone, AgentStuck, AgentFailed:
		return AgentState(s)
	default:
		return AgentIdle
	}
}
