# SonarQube management wrapper
# Runs SonarQube Community Edition via Colima + Docker for local code quality analysis
#
# Usage:
#   sonarqube start      - Start SonarQube server
#   sonarqube stop       - Stop SonarQube server
#   sonarqube status     - Show status
#   sonarqube scan       - Scan current directory
#   sonarqube scan ~/dir - Scan specific project
#   sonarqube logs       - Tail logs
#   sonarqube token      - Generate API token
#   sonarqube update     - Pull latest image
#   sonarqube restart    - Restart server
#   sonarqube uninstall  - Remove everything

function sonarqube --description "Manage SonarQube code quality server (Colima + Docker)"
    set -l dotfiles_root ~/dotfiles
    set -l sonarqube_script "$dotfiles_root/scripts/sonarqube/setup-sonarqube.sh"

    if not test -f "$sonarqube_script"
        echo "SonarQube script not found at $sonarqube_script"
        return 1
    end

    if test (count $argv) -eq 0
        bash "$sonarqube_script" status
    else
        bash "$sonarqube_script" $argv
    end
end
