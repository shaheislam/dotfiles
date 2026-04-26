function _ai_accounts_canonical_name --description "Derive canonical profile name (email local-part) from any opencode/codex auth shape"
    set -l auth_file $argv[1]
    if not test -f "$auth_file"
        return 1
    end

    python3 -c "
import base64, json, re, sys
def decode_jwt(token):
    if not token: return {}
    try:
        p = token.split('.')[1]
        p += '=' * (-len(p) % 4)
        return json.loads(base64.urlsafe_b64decode(p))
    except Exception:
        return {}
try:
    data = json.load(open('$auth_file'))
except Exception:
    sys.exit(1)
if not isinstance(data, dict):
    sys.exit(1)
# Live opencode auth: {'openai': {...}, 'anthropic': {...}}; profile-saved opencode: {'access': ..., 'refresh': ...}
node = data.get('openai', data) if isinstance(data.get('openai'), dict) else data
token = ''
if 'access' in node:
    token = node.get('access', '')
elif isinstance(node.get('tokens'), dict):
    # codex shape (live or profile)
    token = node['tokens'].get('id_token') or node['tokens'].get('access_token', '')
claims = decode_jwt(token)
profile = claims.get('https://api.openai.com/profile', {})
email = (profile.get('email') or claims.get('email') or '').strip().lower()
if not email or '@' not in email:
    sys.exit(1)
local = email.split('@', 1)[0]
local = re.sub(r'[^a-z0-9._-]', '-', local).strip('.-')
if not local:
    sys.exit(1)
print(local)
" 2>/dev/null
end
