function op-add-api-key --description "Add an API key to 1Password"
    if test (count $argv) -lt 2
        echo "Usage: op-add-api-key <name> <api-key-value>"
        echo "Example: op-add-api-key 'GitHub Token' 'ghp_xxxxxxxxxxxx'"
        return 1
    end
    
    set -l item_name $argv[1]
    set -l api_key $argv[2]
    
    # Create a secure note with the API key in the notes field
    echo "$api_key" | op item create \
        --category="Secure Note" \
        --title="$item_name" \
        --vault="Private" \
        stdin=notesPlain
    
    if test $status -eq 0
        echo "✓ Added $item_name to 1Password"
    else
        echo "✗ Failed to add $item_name"
        return 1
    end
end