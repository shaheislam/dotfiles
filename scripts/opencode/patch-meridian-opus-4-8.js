#!/usr/bin/env node

import { existsSync, readdirSync, readFileSync, writeFileSync } from "node:fs"
import { join } from "node:path"

const home = process.env.HOME
if (!home) {
  console.error("HOME is required")
  process.exit(1)
}

const meridianDir = process.env.MERIDIAN_MODULE_DIR || join(home, ".bun", "install", "global", "node_modules", "@rynfar", "meridian")
const distDir = join(meridianDir, "dist")

if (!existsSync(distDir)) {
  console.error(`Meridian dist directory not found: ${distDir}`)
  process.exit(1)
}

let patchedCanonical = false
let patchedModelList = false

for (const entry of readdirSync(distDir)) {
  if (!entry.endsWith(".js")) continue

  const file = join(distDir, entry)
  let source = readFileSync(file, "utf8")
  const original = source

  source = source.replaceAll('CANONICAL_OPUS_MODEL = "claude-opus-4-7"', 'CANONICAL_OPUS_MODEL = "claude-opus-4-8"')
  if (source !== original) patchedCanonical = true

  if (!source.includes('id: "claude-opus-4-8"') && source.includes('id: "claude-opus-4-7"')) {
    source = source.replace(
      /(\{\n\s+id: "claude-opus-4-7",\n\s+object: "model",\n\s+created: now,\n\s+owned_by: "anthropic",\n\s+display_name: "Claude Opus 4\.7",\n\s+context_window: isMaxSubscription \? 1e6 : 200000\n\s+\})/,
      `$1,
    {
      id: "claude-opus-4-8",
      object: "model",
      created: now,
      owned_by: "anthropic",
      display_name: "Claude Opus 4.8",
      context_window: isMaxSubscription ? 1e6 : 200000
    }`,
    )
    if (source !== original) patchedModelList = true
  }

  if (source !== original) writeFileSync(file, source)
}

if (!patchedCanonical) {
  const alreadyCanonical = readdirSync(distDir)
    .filter((entry) => entry.endsWith(".js"))
    .some((entry) => readFileSync(join(distDir, entry), "utf8").includes('CANONICAL_OPUS_MODEL = "claude-opus-4-8"'))
  if (!alreadyCanonical) {
    console.error("Could not find Meridian canonical Opus model pin to patch")
    process.exit(1)
  }
}

console.log(
  [
    "Meridian Opus 4.8 patch applied",
    patchedCanonical ? "canonical=patched" : "canonical=already-present",
    patchedModelList ? "model-list=patched" : "model-list=already-present-or-unneeded",
  ].join("; "),
)
