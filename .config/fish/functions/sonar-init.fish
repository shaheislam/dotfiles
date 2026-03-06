# Initialize a project for SonarQube scanning
#
# Usage:
#   sonar-init                    # Create sonar-project.properties in current dir
#   sonar-init ~/my-project       # Create in specific project

function sonar-init --description "Initialize project for SonarQube scanning"
    set -l project_dir "."

    if test (count $argv) -gt 0
        switch $argv[1]
            case --help -h
                echo "Usage: sonar-init [directory]"
                echo ""
                echo "Creates a sonar-project.properties file from template."
                echo "Auto-detects project key from directory name."
                return 0
            case "*"
                set project_dir $argv[1]
        end
    end

    set project_dir (realpath "$project_dir")
    set -l props_file "$project_dir/sonar-project.properties"
    set -l template ~/dotfiles/scripts/sonarqube/sonar-project.properties.template

    if test -f "$props_file"
        echo "sonar-project.properties already exists in $project_dir"
        return 1
    end

    if not test -f "$template"
        echo "Template not found at $template"
        return 1
    end

    set -l project_key (basename "$project_dir" | tr '[:upper:]' '[:lower:]' | tr ' ' '-')
    set -l project_name (basename "$project_dir")

    # Copy and customize template
    sed -e "s/sonar.projectKey=my-project/sonar.projectKey=$project_key/" \
        -e "s/sonar.projectName=My Project/sonar.projectName=$project_name/" \
        "$template" >"$props_file"

    echo "Created $props_file"
    echo "  Project key: $project_key"
    echo ""
    echo "Edit the file to customize source paths and exclusions."
    echo "Then scan with: sonar-scan"
end
