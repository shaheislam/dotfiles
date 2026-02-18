function sysinfo --description "Show system information summary"
    echo "System Information"
    echo "===================="
    fastfetch --logo none --structure "OS:Kernel:Uptime:CPU:Memory:Disk"
    echo ""
    echo "Process Summary"
    echo "=================="
    procs --tree | head -20
    echo ""
    echo "Network Activity"
    echo "=================="
    if test -x /opt/homebrew/bin/bandwhich
        echo "Run 'net' (sudo bandwhich) for detailed network monitoring"
    end
    echo ""
    echo "Listening Ports:"
    ports | head -10
end
