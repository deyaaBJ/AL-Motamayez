$ErrorActionPreference = "Stop"

$splitDebugInfo = "build\symbols\windows"
New-Item -ItemType Directory -Force $splitDebugInfo | Out-Null

flutter build windows --release `
  --obfuscate `
  --split-debug-info=$splitDebugInfo
