# Convenience alias for sonarqube init
#
# Usage:
#   sonar-init                 # Create sonar-project.properties in current dir
#   sonar-init ~/my-project    # Create in specific project

function sonar-init --description "Initialize project for SonarQube (alias for sonarqube init)"
    sonarqube init $argv
end
