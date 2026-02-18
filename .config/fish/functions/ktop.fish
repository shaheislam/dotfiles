function ktop --description "Show resource usage for nodes and pods"
    echo "=== Node Resources ==="
    kubectl top nodes 2>/dev/null || echo "Metrics server not installed"
    echo ""
    echo "=== Pod Resources ==="
    kubectl top pods 2>/dev/null || echo "Metrics server not installed"
end
