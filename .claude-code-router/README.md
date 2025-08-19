# Claude Code Router Configuration

Claude Code Router enables using Claude Code's interface with alternative AI providers like OpenRouter, DeepSeek, Gemini, and Ollama.

## Installation

The router is automatically installed via the setup script:
```bash
cd ~/dotfiles
./scripts/setup-script.sh
```

Or install manually:
```bash
npm install -g @musistudio/claude-code-router
./scripts/setup-claude-code-router.sh
```

## Configuration

Edit `config.json` and add your API keys:

### OpenRouter
1. Get API key from https://openrouter.ai/keys
2. Replace `YOUR_OPENROUTER_API_KEY` in config.json
3. Supports multiple models including Claude, GPT-4o, Gemini, DeepSeek

### DeepSeek
1. Get API key from https://platform.deepseek.com/api_keys
2. Replace `YOUR_DEEPSEEK_API_KEY` in config.json
3. Includes DeepSeek Chat and Reasoner models

### Gemini
1. Get API key from https://aistudio.google.com/app/apikey
2. Replace `YOUR_GEMINI_API_KEY` in config.json
3. Includes Gemini 2.0 Flash and Thinking models

### Ollama (Local)
1. Install Ollama: `brew install ollama`
2. Start Ollama service: `ollama serve`
3. Pull models: `ollama pull llama3.2`
4. No API key needed (uses "not-needed" placeholder)

## Usage

### Start Claude Code with Router
```bash
ccr code
# or
claude-router
```

### Switch Models Mid-Session
Use the `/model` command:
```
/model openrouter,anthropic/claude-3.5-sonnet
/model deepseek,deepseek-chat
/model ollama,llama3.2
/model gemini,gemini-2.0-flash-exp
```

### Context-Based Routing
Enable automatic model selection based on task type:
1. Set `contextRouting.enabled` to `true` in config.json
2. Define rules for different patterns (debug, code, explain)
3. Router will automatically switch models based on context

## Available Models

### OpenRouter
- anthropic/claude-3.5-sonnet (Best for general tasks)
- anthropic/claude-3-opus (Advanced reasoning)
- google/gemini-2.0-flash-exp (Fast responses)
- google/gemini-2.0-flash-thinking-exp (Deep thinking)
- deepseek/deepseek-chat (Code generation)
- openai/gpt-4o (Latest GPT-4)
- openai/o1-preview (Advanced reasoning)
- meta-llama/llama-3.2-90b-vision-instruct (Vision + Text)

### DeepSeek
- deepseek-chat (General purpose)
- deepseek-reasoner (Complex reasoning)

### Gemini
- gemini-2.0-flash-exp (Fast, efficient)
- gemini-2.0-flash-thinking-exp-1219 (Deep analysis)
- gemini-1.5-pro (Balanced performance)
- gemini-1.5-flash (Quick responses)

### Ollama (Local)
- llama3.2 (General purpose)
- qwen2.5-coder (Code-focused)
- deepseek-r1 (Reasoning model)

## Troubleshooting

### Router not found
```bash
npm install -g @musistudio/claude-code-router
```

### Config not loading
Ensure config is linked:
```bash
ln -s ~/dotfiles/.config/claude-code-router/config.json ~/.claude-code-router/config.json
```

### Model switching not working
Check that the provider and model names match exactly as shown in config.json

### API errors
- Verify API keys are correct
- Check provider API limits and quotas
- Ensure network connectivity

## Cost Optimization

1. Use Gemini Flash models for simple tasks (cheaper)
2. Use DeepSeek for code generation (cost-effective)
3. Use Claude/GPT-4 for complex reasoning tasks
4. Use Ollama for privacy-sensitive or offline work (free)

## Privacy Note

- Ollama runs locally - no data leaves your machine
- Other providers process data on their servers
- Review each provider's privacy policy
- Consider using Ollama for sensitive code
