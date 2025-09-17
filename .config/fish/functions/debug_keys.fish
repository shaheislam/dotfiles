function debug_keys --description "Debug key input in Fish"
    echo "Press any key to see what Fish receives (Ctrl-C to exit):"
    while true
        read -n 1 -P "> " key
        echo -n "Raw bytes: "
        echo -n $key | od -An -tx1
        echo "Fish sees: '$key'"
    end
end