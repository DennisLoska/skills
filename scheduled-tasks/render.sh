#!/usr/bin/env bash
# Render a scheduled-task prompt: preamble + job body, placeholders filled from projects.tsv.
# Usage: scheduled-tasks/render.sh <job-id> <project> [projects.tsv]
set -euo pipefail

dir="$(cd "$(dirname "$0")" && pwd)"
job="${1:?usage: render.sh <job-id> <project> [projects.tsv]}"
project="${2:?usage: render.sh <job-id> <project> [projects.tsv]}"
registry="${3:-$dir/projects.tsv}"
job_file="$dir/jobs/$job.md"

[ -f "$job_file" ] || { echo "render.sh: unknown job: $job" >&2; exit 2; }
[ -f "$registry" ] || { echo "render.sh: registry not found: $registry (copy projects.example.tsv)" >&2; exit 2; }

row="$(awk -F '\t' -v p="$project" '$1 == p { print; exit }' "$registry")"
[ -n "$row" ] || { echo "render.sh: project not in registry: $project" >&2; exit 2; }
IFS=$'\t' read -r _ repo team linear_project <<<"$row"

front() { awk -v k="$1" -F ': ' '/^---$/ { n++; next } n == 1 && $1 == k { print $2; exit }' "$job_file"; }
title="$(front title)"
version="$(front version)"

{
  cat "$dir/preamble.md"
  awk '/^---$/ && n < 2 { n++; next } n >= 2' "$job_file"
} | sed \
  -e "s|{{JOB_ID}}|$job|g" \
  -e "s|{{JOB_TITLE}}|$title|g" \
  -e "s|{{TEMPLATE_VERSION}}|$version|g" \
  -e "s|{{PROJECT}}|$project|g" \
  -e "s|{{REPO}}|$repo|g" \
  -e "s|{{LINEAR_TEAM}}|$team|g" \
  -e "s|{{LINEAR_PROJECT}}|$linear_project|g"
