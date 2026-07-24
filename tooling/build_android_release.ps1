$ErrorActionPreference = "Stop"

$splitDebugInfo = "build\symbols\android"
New-Item -ItemType Directory -Force $splitDebugInfo | Out-Null

flutter build apk --release `
  --obfuscate `
  --split-debug-info=$splitDebugInfo `
  --tree-shake-icons
