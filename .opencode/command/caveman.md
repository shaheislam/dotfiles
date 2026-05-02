---
description: Apply compact Caveman output style to this specific request
agent: build
model: openai/gpt-5.5
---

Apply the local `caveman` skill to this request only:

$ARGUMENTS

Use `.opencode/skills/caveman/SKILL.md` if available. Keep technical accuracy. Drop filler. Prefer compact operational schemas. If the request needs open-ended planning, security nuance, or teaching prose, say Caveman is a poor fit and ask whether to continue compact anyway.
