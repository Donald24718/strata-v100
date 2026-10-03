#!/usr/bin/env bash
# Smoke test: does the engine actually answer, and at what speed?
# Reads the engine's own timing lines — do not compute decode speed by dividing
# generated tokens by total request time, that includes prompt processing.
set -euo pipefail
URL="${URL:-http://127.0.0.1:8080}"
MODEL="${MODEL:-$(curl -s "$URL/v1/models" | sed -n 's/.*"id":"\([^"]*\)".*/\1/p' | head -1)}"
echo "model: $MODEL"
for i in 1 2 3; do
  curl -s "$URL/v1/chat/completions" -H "Content-Type: application/json" \
    -d "{\"model\":\"$MODEL\",\"messages\":[{\"role\":\"user\",\"content\":\"用两句话说明什么是冠状动脉钙化积分。\"}],\"max_tokens\":300,\"temperature\":0}" \
    -o /dev/null -w "run $i: http=%{http_code} total=%{time_total}s\n"
done
echo "now read the engine log for: 'prompt ... tok/s' and '... generated ... tok/s'"
