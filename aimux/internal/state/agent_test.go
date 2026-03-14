package state

import "testing"

func TestTransitionValidPaths(t *testing.T) {
	tests := []struct {
		from, to AgentState
	}{
		{AgentIdle, AgentWorking},
		{AgentIdle, AgentDone},
		{AgentIdle, AgentFailed},
		{AgentWorking, AgentIdle},
		{AgentWorking, AgentDone},
		{AgentWorking, AgentStuck},
		{AgentWorking, AgentFailed},
		{AgentDone, AgentIdle},
		{AgentDone, AgentFailed},
		{AgentStuck, AgentIdle},
		{AgentStuck, AgentWorking},
		{AgentStuck, AgentDone},
		{AgentStuck, AgentFailed},
		{AgentFailed, AgentIdle},
	}

	for _, tt := range tests {
		t.Run(string(tt.from)+"->"+string(tt.to), func(t *testing.T) {
			if !Transition(tt.from, tt.to) {
				t.Errorf("Transition(%q, %q) = false, want true", tt.from, tt.to)
			}
		})
	}
}

func TestTransitionInvalidPaths(t *testing.T) {
	tests := []struct {
		from, to AgentState
	}{
		{AgentIdle, AgentStuck},       // can't go directly to stuck
		{AgentIdle, AgentIdle},        // no self-transition
		{AgentDone, AgentWorking},     // done can only go to idle or failed
		{AgentDone, AgentStuck},       // done can't go to stuck
		{AgentFailed, AgentWorking},   // failed can only restart to idle
		{AgentFailed, AgentDone},      // failed can't go to done
		{AgentFailed, AgentStuck},     // failed can't go to stuck
		{AgentWorking, AgentWorking},  // no self-transition
	}

	for _, tt := range tests {
		t.Run(string(tt.from)+"->"+string(tt.to), func(t *testing.T) {
			if Transition(tt.from, tt.to) {
				t.Errorf("Transition(%q, %q) = true, want false", tt.from, tt.to)
			}
		})
	}
}

func TestIsTerminal(t *testing.T) {
	tests := []struct {
		state    AgentState
		terminal bool
	}{
		{AgentIdle, false},
		{AgentWorking, false},
		{AgentDone, true},
		{AgentStuck, false},
		{AgentFailed, true},
	}

	for _, tt := range tests {
		t.Run(string(tt.state), func(t *testing.T) {
			if got := IsTerminal(tt.state); got != tt.terminal {
				t.Errorf("IsTerminal(%q) = %v, want %v", tt.state, got, tt.terminal)
			}
		})
	}
}

func TestAgentStateString(t *testing.T) {
	tests := []struct {
		state AgentState
		want  string
	}{
		{AgentIdle, "idle"},
		{AgentWorking, "working"},
		{AgentDone, "done"},
		{AgentStuck, "stuck"},
		{AgentFailed, "failed"},
	}

	for _, tt := range tests {
		t.Run(tt.want, func(t *testing.T) {
			if got := tt.state.String(); got != tt.want {
				t.Errorf("String() = %q, want %q", got, tt.want)
			}
		})
	}
}

func TestParseAgentState(t *testing.T) {
	tests := []struct {
		input string
		want  AgentState
	}{
		{"idle", AgentIdle},
		{"working", AgentWorking},
		{"done", AgentDone},
		{"stuck", AgentStuck},
		{"failed", AgentFailed},
		{"unknown", AgentIdle},       // defaults to idle
		{"", AgentIdle},              // empty defaults to idle
		{"WORKING", AgentIdle},       // case-sensitive, uppercase not recognized
	}

	for _, tt := range tests {
		t.Run(tt.input, func(t *testing.T) {
			if got := ParseAgentState(tt.input); got != tt.want {
				t.Errorf("ParseAgentState(%q) = %q, want %q", tt.input, got, tt.want)
			}
		})
	}
}

func TestTransitionFromUnknownState(t *testing.T) {
	unknown := AgentState("phantom")
	if Transition(unknown, AgentIdle) {
		t.Error("Transition from unknown state should return false")
	}
}
