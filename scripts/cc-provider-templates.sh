#!/usr/bin/env bash
# cc-provider-templates.sh - Write provider profile templates
# Called by cc-provider.fish: _cc_provider_write_template
# Usage: cc-provider-templates.sh <provider_type> <output_file>

set -euo pipefail

PROVIDER_TYPE="${1:-}"
OUTPUT_FILE="${2:-}"

if [[ -z "$PROVIDER_TYPE" || -z "$OUTPUT_FILE" ]]; then
    echo "Usage: cc-provider-templates.sh <provider_type> <output_file>" >&2
    exit 1
fi

case "$PROVIDER_TYPE" in
bedrock)
    cat >"$OUTPUT_FILE" <<'EOF'
# provider: bedrock
# description: Amazon Bedrock deployment
#
# Prerequisites:
#   - AWS account with Bedrock access enabled
#   - Claude models enabled in Bedrock console
#   - AWS credentials configured (aws configure / SSO / env vars)
#
# See: docs/third-party-integrations.md#amazon-bedrock

# Required: Enable Bedrock integration
CLAUDE_CODE_USE_BEDROCK=1

# Required: AWS region (not read from .aws/config)
AWS_REGION=us-east-1

# Pin model versions to prevent breakage on new releases
# Get IDs: aws bedrock list-inference-profiles --region $AWS_REGION
ANTHROPIC_DEFAULT_OPUS_MODEL=us.anthropic.claude-opus-4-6-v1
ANTHROPIC_DEFAULT_SONNET_MODEL=us.anthropic.claude-sonnet-4-6
ANTHROPIC_DEFAULT_HAIKU_MODEL=us.anthropic.claude-haiku-4-5-20251001-v1:0

# Optional: Override region for small/fast model
# ANTHROPIC_SMALL_FAST_MODEL_AWS_REGION=us-west-2

# Optional: AWS SSO profile (alternative to env-based credentials)
# AWS_PROFILE=your-sso-profile

# Optional: Bedrock API key (simpler than full AWS credentials)
# AWS_BEARER_TOKEN_BEDROCK=your-bedrock-api-key

# Optional: Bedrock Guardrails
# ANTHROPIC_CUSTOM_HEADERS=X-Amzn-Bedrock-GuardrailIdentifier: your-id\nX-Amzn-Bedrock-GuardrailVersion: 1

# Optional: LLM gateway for Bedrock
# ANTHROPIC_BEDROCK_BASE_URL=https://your-gateway.com/bedrock
# CLAUDE_CODE_SKIP_BEDROCK_AUTH=1
EOF
    ;;

vertex)
    cat >"$OUTPUT_FILE" <<'EOF'
# provider: vertex
# description: Google Vertex AI deployment
#
# Prerequisites:
#   - GCP account with billing enabled
#   - Vertex AI API enabled (gcloud services enable aiplatform.googleapis.com)
#   - Claude models enabled in Model Garden
#   - GCP credentials configured (gcloud auth application-default login)
#
# See: docs/third-party-integrations.md#google-vertex-ai

# Required: Enable Vertex AI integration
CLAUDE_CODE_USE_VERTEX=1

# Required: GCP region (use 'global' for global endpoint)
CLOUD_ML_REGION=global

# Required: GCP project ID
ANTHROPIC_VERTEX_PROJECT_ID=your-project-id

# Pin model versions to prevent breakage on new releases
ANTHROPIC_DEFAULT_OPUS_MODEL=claude-opus-4-6
ANTHROPIC_DEFAULT_SONNET_MODEL=claude-sonnet-4-6
ANTHROPIC_DEFAULT_HAIKU_MODEL=claude-haiku-4-5@20251001

# Optional: Override regions for specific models (when using global endpoint)
# VERTEX_REGION_CLAUDE_3_5_HAIKU=us-east5
# VERTEX_REGION_CLAUDE_4_0_OPUS=europe-west1

# Optional: LLM gateway for Vertex
# ANTHROPIC_VERTEX_BASE_URL=https://your-gateway.com/vertex_ai/v1
# CLAUDE_CODE_SKIP_VERTEX_AUTH=1
EOF
    ;;

foundry)
    cat >"$OUTPUT_FILE" <<'EOF'
# provider: foundry
# description: Microsoft Foundry (Azure) deployment
#
# Prerequisites:
#   - Azure subscription with Foundry access
#   - Claude model deployments created in Foundry portal
#   - Azure credentials (API key or Entra ID via az login)
#
# See: docs/third-party-integrations.md#microsoft-foundry

# Required: Enable Microsoft Foundry integration
CLAUDE_CODE_USE_FOUNDRY=1

# Required: Azure resource name
ANTHROPIC_FOUNDRY_RESOURCE=your-resource-name

# Authentication: API key (comment out for Entra ID)
# ANTHROPIC_FOUNDRY_API_KEY=your-api-key

# Pin model versions to match your Azure deployment names
ANTHROPIC_DEFAULT_OPUS_MODEL=claude-opus-4-6
ANTHROPIC_DEFAULT_SONNET_MODEL=claude-sonnet-4-6
ANTHROPIC_DEFAULT_HAIKU_MODEL=claude-haiku-4-5

# Optional: Full base URL (alternative to ANTHROPIC_FOUNDRY_RESOURCE)
# ANTHROPIC_FOUNDRY_BASE_URL=https://your-resource.services.ai.azure.com/anthropic

# Optional: LLM gateway for Foundry
# ANTHROPIC_FOUNDRY_BASE_URL=https://your-gateway.com
# CLAUDE_CODE_SKIP_FOUNDRY_AUTH=1
EOF
    ;;

gateway)
    cat >"$OUTPUT_FILE" <<'EOF'
# provider: gateway
# description: LLM Gateway (LiteLLM or custom)
#
# Prerequisites:
#   - LLM gateway server deployed and accessible
#   - API key or auth token configured
#
# See: docs/third-party-integrations.md#llm-gateway

# Required: Gateway base URL
ANTHROPIC_BASE_URL=https://your-litellm-server:4000

# Authentication: static API key or use apiKeyHelper in settings
# ANTHROPIC_AUTH_TOKEN=sk-your-gateway-key

# Optional: Pin model names to match gateway configuration
# ANTHROPIC_MODEL=claude-sonnet-4-6
# ANTHROPIC_SMALL_FAST_MODEL=claude-haiku-4-5

# Optional: Use Bedrock-format endpoint via gateway
# CLAUDE_CODE_USE_BEDROCK=1
# ANTHROPIC_BEDROCK_BASE_URL=https://your-gateway:4000/bedrock
# CLAUDE_CODE_SKIP_BEDROCK_AUTH=1

# Optional: Use Vertex-format endpoint via gateway
# CLAUDE_CODE_USE_VERTEX=1
# ANTHROPIC_VERTEX_BASE_URL=https://your-gateway:4000/vertex_ai/v1
# CLAUDE_CODE_SKIP_VERTEX_AUTH=1
EOF
    ;;

*)
    echo "Unknown provider type: $PROVIDER_TYPE" >&2
    exit 1
    ;;
esac
