function _claude_sub_get_info --description "Extract org/plan info from profile directory"
    set -l dir $argv[1]
    set -l config_file "$dir/.claude.json"

    if not test -f "$config_file"
        echo "not authenticated"
        return
    end

    python3 -c "
import json, sys
try:
    with open('$config_file') as f:
        data = json.load(f)
    oauth = data.get('oauthAccount', {})
    name = oauth.get('displayName', '')
    email = oauth.get('emailAddress', '')
    billing = oauth.get('billingType', '')

    # Map billingType to readable label
    billing_labels = {
        'stripe_subscription': 'Pro',
        'api_billing': 'API',
    }
    billing_label = billing_labels.get(billing, billing.replace('_', ' ')) if billing else ''

    parts = []
    if name:
        parts.append(name)
    if billing_label:
        parts.append(billing_label)
    if email:
        parts.append(email)

    if parts:
        print(' | '.join(parts))
    elif oauth:
        print('authenticated')
    else:
        print('no account')
except Exception:
    print('error reading config')
" 2>/dev/null
end
