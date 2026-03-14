package provider

import (
	"os/exec"
	"regexp"
	"strings"

	"github.com/shaheislam/aimux/internal/state"
)

// detectProcessByPatterns checks if any of the given patterns match a process
// running on the specified TTY using ps.
func detectProcessByPatterns(tty string, patterns []string) bool {
	if tty == "" || len(patterns) == 0 {
		return false
	}

	// Strip /dev/ prefix if present; ps -t expects the short form on some systems
	tty = strings.TrimPrefix(tty, "/dev/")

	out, err := exec.Command("ps", "-t", tty, "-o", "comm=").Output()
	if err != nil {
		return false
	}

	output := string(out)
	for _, pattern := range patterns {
		if strings.Contains(output, pattern) {
			return true
		}
	}
	return false
}

// detectStateFromContent checks pane content against working and done patterns.
// Returns the detected AgentState.
func detectStateFromContent(content, workingPattern string, donePatterns []string) state.AgentState {
	// Check done patterns first (higher priority — if done marker is present, agent is done)
	for _, dp := range donePatterns {
		if dp == "" {
			continue
		}
		if strings.Contains(content, dp) {
			return state.AgentDone
		}
	}

	// Check working pattern
	if workingPattern != "" {
		re, err := regexp.Compile(workingPattern)
		if err == nil && re.MatchString(content) {
			return state.AgentWorking
		}
	}

	return state.AgentIdle
}
