#!/usr/bin/env bash
# Self-check for the seeded-defect corpus: the graders must accept a correct answer and reject wrong,
# noisy and empty ones, before any model is run. Run directly: bash scripts/review-eval-graders.test.sh

set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)

if ! command -v node >/dev/null 2>&1; then
  echo "skip - node is not installed; this suite did not run"
  exit 0
fi

node "$SCRIPT_DIR/../plugins/fabric-review/evals/check-graders.mjs"
