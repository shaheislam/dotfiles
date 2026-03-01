# Third-Party Integrations

Claude Code can connect to model providers beyond the default direct API. This guide covers configuring Amazon Bedrock, Google Vertex AI, Microsoft Foundry, LLM gateways, and enterprise network settings.

**Quick Start**: `cc-provider create bedrock && cc-provider use bedrock`

## Provider Switching with `cc-provider`

The `cc-provider` Fish function manages switching Claude Code between API providers. Configs are stored as env-var files in `~/.claude/providers/`.

| Command | Description |
|---------|-------------|
| `cc-provider use <name>` | Activate a provider for the current shell |
| `cc-provider off` | Deactivate provider (revert to direct API) |
| `cc-provider status` | Show active provider and relevant env vars |
| `cc-provider list` | List available provider profiles |
| `cc-provider create <name>` | Create a new provider profile (interactive) |
| `cc-provider edit <name>` | Open provider profile in `$EDITOR` |
| `cc-provider env [name]` | Print env vars (Fish `set -gx` format) |

### Integration with Other Commands

```fish
# Use provider in gwt-ticket (recommended — passes env vars to spawned session)
gwt-ticket ENG-123 "Fix bug" "Details" --provider bedrock
gwt-ticket ENG-123 "Fix bug" "Details" --provider vertex --sub work

# Activate provider for current shell
cc-provider use bedrock && claude

# One-off via env var
CLAUDE_PROVIDER=bedrock claude

# Export for sub-processes
eval (cc-provider env bedrock)
```

### Profile Format

Provider profiles are simple `.conf` files with `KEY=VALUE` lines:

```conf
# provider: bedrock
# description: Production Bedrock (us-east-1)
CLAUDE_CODE_USE_BEDROCK=1
AWS_REGION=us-east-1
ANTHROPIC_DEFAULT_SONNET_MODEL=us.anthropic.claude-sonnet-4-6
```

Lines starting with `#` are comments. Optional `export` prefixes are stripped.

## Amazon Bedrock

### Prerequisites

- AWS account with Bedrock access enabled
- Claude models enabled in [Bedrock console](https://console.aws.amazon.com/bedrock/)
- AWS credentials configured (`aws configure`, SSO, or env vars)

### Setup

```fish
# 1. Create provider profile
cc-provider create bedrock

# 2. Edit with your AWS config
cc-provider edit bedrock

# 3. Activate
cc-provider use bedrock

# 4. Verify
cc-provider status
claude /status
```

### Authentication Methods

| Method | Config |
|--------|--------|
| AWS CLI | `aws configure` |
| SSO Profile | `AWS_PROFILE=your-profile` |
| Environment vars | `AWS_ACCESS_KEY_ID` + `AWS_SECRET_ACCESS_KEY` + `AWS_SESSION_TOKEN` |
| Bedrock API key | `AWS_BEARER_TOKEN_BEDROCK=your-key` |

### Auto-Credential Refresh

Add to Claude Code settings (`~/.claude/settings.json`) for automatic SSO refresh:

```json
{
  "awsAuthRefresh": "aws sso login --profile myprofile",
  "env": {
    "AWS_PROFILE": "myprofile"
  }
}
```

### Model Pinning (Required)

Always pin model versions to prevent breakage when new models are released:

```conf
ANTHROPIC_DEFAULT_OPUS_MODEL=us.anthropic.claude-opus-4-6-v1
ANTHROPIC_DEFAULT_SONNET_MODEL=us.anthropic.claude-sonnet-4-6
ANTHROPIC_DEFAULT_HAIKU_MODEL=us.anthropic.claude-haiku-4-5-20251001-v1:0
```

List available models: `aws bedrock list-inference-profiles --region us-east-1`

### IAM Permissions

Required IAM actions:
- `bedrock:InvokeModel`
- `bedrock:InvokeModelWithResponseStream`
- `bedrock:ListInferenceProfiles`

### AWS Guardrails

Add guardrail headers via `ANTHROPIC_CUSTOM_HEADERS` in the provider config:

```conf
ANTHROPIC_CUSTOM_HEADERS=X-Amzn-Bedrock-GuardrailIdentifier: your-id\nX-Amzn-Bedrock-GuardrailVersion: 1
```

## Google Vertex AI

### Prerequisites

- GCP account with billing enabled
- Vertex AI API enabled: `gcloud services enable aiplatform.googleapis.com`
- Claude models enabled in [Model Garden](https://console.cloud.google.com/vertex-ai/model-garden)
- GCP credentials: `gcloud auth application-default login`

### Setup

```fish
cc-provider create vertex
cc-provider edit vertex    # Set ANTHROPIC_VERTEX_PROJECT_ID
cc-provider use vertex
```

### Model Pinning (Required)

```conf
ANTHROPIC_DEFAULT_OPUS_MODEL=claude-opus-4-6
ANTHROPIC_DEFAULT_SONNET_MODEL=claude-sonnet-4-6
ANTHROPIC_DEFAULT_HAIKU_MODEL=claude-haiku-4-5@20251001
```

### Region Configuration

Use `CLOUD_ML_REGION=global` for the global endpoint. Override specific models that don't support global:

```conf
VERTEX_REGION_CLAUDE_3_5_HAIKU=us-east5
VERTEX_REGION_CLAUDE_4_0_OPUS=europe-west1
```

### IAM Permissions

Required role: `roles/aiplatform.user` (includes `aiplatform.endpoints.predict`).

## Microsoft Foundry

### Prerequisites

- Azure subscription with Foundry access
- Claude model deployments created in [Foundry portal](https://ai.azure.com/)
- Azure credentials (API key or Entra ID via `az login`)

### Setup

```fish
cc-provider create foundry
cc-provider edit foundry    # Set ANTHROPIC_FOUNDRY_RESOURCE
cc-provider use foundry
```

### Authentication

| Method | Config |
|--------|--------|
| API key | `ANTHROPIC_FOUNDRY_API_KEY=your-key` |
| Entra ID | Omit API key; uses Azure SDK default credential chain |

### Model Pinning (Required)

```conf
ANTHROPIC_DEFAULT_OPUS_MODEL=claude-opus-4-6
ANTHROPIC_DEFAULT_SONNET_MODEL=claude-sonnet-4-6
ANTHROPIC_DEFAULT_HAIKU_MODEL=claude-haiku-4-5
```

### RBAC Permissions

Required roles: `Azure AI User` or `Cognitive Services User`.

## LLM Gateway (LiteLLM)

### Prerequisites

- LLM gateway server deployed and accessible
- Authentication configured (API key or token helper)

### Setup

```fish
cc-provider create gateway
cc-provider edit gateway    # Set ANTHROPIC_BASE_URL
cc-provider use gateway
```

### Authentication

**Static API key:**
```conf
ANTHROPIC_AUTH_TOKEN=sk-your-gateway-key
```

**Dynamic key helper** (in `~/.claude/settings.json`):
```json
{
  "apiKeyHelper": "~/bin/get-litellm-key.sh"
}
```

### Endpoint Formats

| Format | Config |
|--------|--------|
| Unified (recommended) | `ANTHROPIC_BASE_URL=https://gateway:4000` |
| Bedrock pass-through | `ANTHROPIC_BEDROCK_BASE_URL=https://gateway:4000/bedrock` |
| Vertex pass-through | `ANTHROPIC_VERTEX_BASE_URL=https://gateway:4000/vertex_ai/v1` |

## Enterprise Network Configuration

### Proxy

```fish
# In Fish config or provider profile
set -gx HTTPS_PROXY https://proxy.example.com:8080
set -gx NO_PROXY "localhost 192.168.1.1"
```

### Custom CA Certificates

```fish
set -gx NODE_EXTRA_CA_CERTS /path/to/ca-cert.pem
```

### mTLS Authentication

```fish
set -gx CLAUDE_CODE_CLIENT_CERT /path/to/client-cert.pem
set -gx CLAUDE_CODE_CLIENT_KEY /path/to/client-key.pem
# Optional: passphrase for encrypted key
set -gx CLAUDE_CODE_CLIENT_KEY_PASSPHRASE "your-passphrase"
```

### Network Access Requirements

Claude Code requires access to:
- `api.anthropic.com` — Claude API endpoints
- `claude.ai` — authentication for claude.ai accounts
- `platform.claude.com` — authentication for Console accounts

Ensure these are allowlisted in proxy and firewall rules.

## Environment Variable Reference

### Provider Selection

| Variable | Description |
|----------|-------------|
| `CLAUDE_CODE_USE_BEDROCK=1` | Enable Bedrock |
| `CLAUDE_CODE_USE_VERTEX=1` | Enable Vertex AI |
| `CLAUDE_CODE_USE_FOUNDRY=1` | Enable Microsoft Foundry |

### Authentication

| Variable | Description |
|----------|-------------|
| `ANTHROPIC_API_KEY` | Direct API key |
| `ANTHROPIC_AUTH_TOKEN` | Gateway auth token |
| `AWS_BEARER_TOKEN_BEDROCK` | Bedrock API key |
| `ANTHROPIC_FOUNDRY_API_KEY` | Foundry API key |

### Endpoints

| Variable | Description |
|----------|-------------|
| `ANTHROPIC_BASE_URL` | Anthropic Messages API endpoint |
| `ANTHROPIC_BEDROCK_BASE_URL` | Bedrock endpoint |
| `ANTHROPIC_VERTEX_BASE_URL` | Vertex AI endpoint |
| `ANTHROPIC_FOUNDRY_BASE_URL` | Foundry endpoint |

### Auth Bypass (for gateways)

| Variable | Description |
|----------|-------------|
| `CLAUDE_CODE_SKIP_BEDROCK_AUTH=1` | Gateway handles AWS auth |
| `CLAUDE_CODE_SKIP_VERTEX_AUTH=1` | Gateway handles GCP auth |
| `CLAUDE_CODE_SKIP_FOUNDRY_AUTH=1` | Gateway handles Azure auth |

### Model Pinning

| Variable | Description |
|----------|-------------|
| `ANTHROPIC_DEFAULT_OPUS_MODEL` | Pin Opus model version |
| `ANTHROPIC_DEFAULT_SONNET_MODEL` | Pin Sonnet model version |
| `ANTHROPIC_DEFAULT_HAIKU_MODEL` | Pin Haiku model version |
| `ANTHROPIC_MODEL` | Override primary model |
| `ANTHROPIC_SMALL_FAST_MODEL` | Override small/fast model |

### Network

| Variable | Description |
|----------|-------------|
| `HTTPS_PROXY` | HTTPS proxy URL |
| `HTTP_PROXY` | HTTP proxy URL |
| `NO_PROXY` | Proxy bypass list |
| `NODE_EXTRA_CA_CERTS` | Custom CA certificate path |
| `CLAUDE_CODE_CLIENT_CERT` | mTLS client certificate |
| `CLAUDE_CODE_CLIENT_KEY` | mTLS client key |

## Troubleshooting

### Bedrock

- **Region issues**: `aws bedrock list-inference-profiles --region your-region`
- **"On-demand throughput isn't supported"**: Use inference profile IDs (with `us.` prefix)
- **Credential expired**: Configure `awsAuthRefresh` in settings

### Vertex AI

- **404 "model not found"**: Confirm model is enabled in Model Garden; check region support
- **429 rate limits**: Switch to `CLOUD_ML_REGION=global` for better availability
- **Quota issues**: Request increase via [Cloud Console](https://cloud.google.com/docs/quotas/view-manage)

### Foundry

- **"Failed to get token"**: Configure Entra ID or set `ANTHROPIC_FOUNDRY_API_KEY`

### General

- **Verify config**: `claude /status` shows active provider configuration
- **Test connection**: `cc-provider status` shows all relevant env vars
- **Model breakage after update**: Pin model versions (see each provider section)

## References

- [Claude Code Third-Party Integrations](https://code.claude.com/docs/en/third-party-integrations)
- [Amazon Bedrock Setup](https://code.claude.com/docs/en/amazon-bedrock)
- [Google Vertex AI Setup](https://code.claude.com/docs/en/google-vertex-ai)
- [Microsoft Foundry Setup](https://code.claude.com/docs/en/microsoft-foundry)
- [LLM Gateway Configuration](https://code.claude.com/docs/en/llm-gateway)
- [Enterprise Network Configuration](https://code.claude.com/docs/en/network-config)
- [Model Configuration](https://code.claude.com/docs/en/model-config)
