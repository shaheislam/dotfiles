function kcluster --description "Manage local Kubernetes clusters with k3d on Colima"
    if test (count $argv) -eq 0
        echo "Usage: kcluster <action> [name]"
        echo "Actions: start, stop, delete, list"
        echo "Note: Using k3d with Colima as the container runtime"
        return 1
    end

    set -l action $argv[1]
    set -l name $argv[2]

    # Ensure Colima is running
    if not colima status &>/dev/null
        echo "Starting Colima..."
        colima start --runtime docker --cpu 4 --memory 8 --disk 60
    end

    switch $action
        case start create
            if test -n "$name"
                k3d cluster create $name
            else
                k3d cluster create dev
            end
        case stop
            if test -n "$name"
                k3d cluster stop $name
            else
                echo "Name required for stop"
            end
        case delete del
            if test -n "$name"
                k3d cluster delete $name
            else
                echo "Name required for delete"
            end
        case list ls
            k3d cluster list
        case '*'
            echo "Unknown action: $action"
            echo "Supported actions: start, stop, delete, list"
    end
end
