#!/usr/bin/env bash
# Chat notices go through shared.notice / shared.reply (off by default: the user, 2026-10-17, "nothing is communicated
# through notices in factorio"). Fails on a print or custom alert elsewhere, but for the dev commands (dev.lua), the
# gate itself (shared.lua) and lines marked "notice-ok" (a command's reply, a gated alert, the first landing). The line
# before may carry the mark for a statement that does not fit on one line.
set -uo pipefail
cd "$(dirname "$0")/../landing-party"
bad=$(grep -rnE '\.print\(|add_custom_alert\(' --include='*.lua' . | grep -v '^\./scripts/dev\.lua:\|^\./shared\.lua:' \
  | grep -v 'shared\.notice(\|notice-ok' | while IFS=: read -r f n rest; do
      sed -n "$((n - 1))p" "$f" | grep -q 'notice-ok' || echo "$f:$n:$rest"; done)
if [ -n "$bad" ]; then echo "LINT FAILED: chat notices outside shared.notice:"; echo "$bad"; exit 1; fi
echo "notices lint ok"
