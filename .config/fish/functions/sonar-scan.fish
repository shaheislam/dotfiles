# Convenience alias for sonarqube scan
# All flags (--ai, --fix) are custom Fish wrapper behavior that pipes
# SonarQube API results through Claude CLI or local Ollama for AI analysis.
# They are NOT sonar-scanner CLI flags.
#
# Usage:
#   sonar-scan                 # Scan current project
#   sonar-scan ~/project       # Scan specific project
#   sonar-scan --ai            # Scan + AI explains findings
#   sonar-scan --fix           # Scan + AI suggests code fixes

function sonar-scan --description "Quick SonarQube scan (alias for sonarqube scan)"
    sonarqube scan $argv
end
