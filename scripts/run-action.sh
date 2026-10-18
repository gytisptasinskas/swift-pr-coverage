#!/usr/bin/env bash
# Runs swift-pr-coverage for the composite action (action.yml).
# Inputs arrive as INPUT_* environment variables; GitHub sets the GITHUB_* ones.
set -euo pipefail

bin="${SWIFT_PR_COVERAGE_BIN:?SWIFT_PR_COVERAGE_BIN is not set}"

trim() {
  local value="$1"
  value="${value#"${value%%[![:space:]]*}"}"
  printf '%s' "${value%"${value##*[![:space:]]}"}"
}

args=()
while IFS= read -r line; do
  line="$(trim "$line")"
  if [[ -n "$line" ]]; then args+=(--xcresult "$line"); fi
done <<< "${INPUT_XCRESULT_PATH:-}"
if [[ ${#args[@]} -eq 0 ]]; then
  echo "::error::xcresult-path is empty."
  exit 1
fi

while IFS= read -r line; do
  line="$(trim "$line")"
  if [[ -n "$line" ]]; then args+=(--exclude "$line"); fi
done <<< "${INPUT_EXCLUDE:-}"

base="${INPUT_BASE_REF:-}"
if [[ -z "$base" ]]; then
  base="origin/${INPUT_DEFAULT_BRANCH:-main}"
fi
args+=(--base "$base")

# git diff base...HEAD needs the merge base, which a shallow clone usually lacks.
if [[ "$(git rev-parse --is-shallow-repository)" == "true" ]]; then
  echo "::notice::Shallow clone detected; fetching full history. Use actions/checkout with fetch-depth: 0 to skip this."
  git fetch --quiet --no-tags --unshallow origin
fi
if ! git rev-parse --quiet --verify "${base}^{commit}" > /dev/null; then
  git fetch --quiet --no-tags origin "${base#origin/}"
fi

event="${GITHUB_EVENT_NAME:-}"
if [[ "${INPUT_POST_COMMENT:-true}" == "true" && ( "$event" == "pull_request" || "$event" == "pull_request_target" ) ]]; then
  args+=(--post-comment)
fi

report="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/swift-pr-coverage.md"
"$bin" "${args[@]}" --output markdown > "$report"

if [[ -n "${GITHUB_STEP_SUMMARY:-}" ]]; then
  cat "$report" >> "$GITHUB_STEP_SUMMARY"
fi
if [[ -n "${GITHUB_OUTPUT:-}" ]]; then
  echo "report-path=$report" >> "$GITHUB_OUTPUT"
fi
