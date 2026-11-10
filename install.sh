#!/usr/bin/env bash
# install.sh - install agents/, skills/, and HARNESS.md into target host config directories
# Collision-safe: preflights every target path and refuses to overwrite without --force.
# Prune is manifest-scoped: it only removes files this installer recorded writing,
# so personal agents and skills sharing the destination are never touched.
set -euo pipefail

SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

available_profiles() {
  local file name
  for file in "$SRC"/providers/*.md; do
    [ -f "$file" ] || continue
    name="${file##*/}"
    name="${name%.md}"
    case "$name" in
      ''|[!a-z0-9]*|*[!a-z0-9-]*) continue ;;
    esac
    printf '%s\n' "$name"
  done | LC_ALL=C sort | paste -sd ' ' -
}

usage() {
  cat <<'EOF'
usage: install.sh [--force] [--prune] [--verify | --doctor] [--profile NAME | --profile-file PATH] [--target TARGETS]

Installs agents/, skills/, AGENTS.md (as HARNESS.md), PROVIDERS.md, NOTICE, and LICENSE into
the selected host target(s) (default: opencode at ${OPENCODE_CONFIG:-$HOME/.config/opencode}),
and records every installed path in <dest>/.harness-manifest.

options:
  --profile NAME       bind providers/NAME.md (also --profile=NAME; default: previous binding, else tri)
  --profile-file PATH  bind an external profile file (also --profile-file=PATH; mutually exclusive with --profile)
  --target TARGETS     comma-separated host targets: opencode, codex, antigravity, claude, or all
                       (also --target=TARGETS; default: opencode; antigravity installs standalone
                       ${ANTIGRAVITY_CONFIG:-$HOME/.gemini/config} plus any T3 Code instances under
                       ${T3_USERDATA_DIR:-$HOME/.t3/userdata}/providers/antigravity/*/config, sharing
                       the standalone root's profile binding on refresh)
  --verify             check installed target health (manifest, required files, instruction wiring,
                       and shared state) without modifying the destination
  --doctor             alias for --verify
  --force              overwrite files that already exist in the destination
  --prune              remove files recorded in a previous .harness-manifest that
                       this run no longer produces; files the installer never wrote
                       are never touched
  -h, --help           show this help and exit

Without --force, any existing target file aborts the install with exit 1
before anything is copied.
EOF
  printf '\navailable profiles: %s\n' "$(available_profiles)"
}

unknown_target() {
  printf 'install.sh: unknown target: %s (available: opencode codex antigravity claude all)\n' "$1" >&2
  exit 2
}

force=0
prune=0
verify_mode=0
pf_token_file=""
sr_token_file=""
preflight_only=0
if [ -n "${HARNESS_PREFLIGHT_TOKEN_FILE:-}" ] && [ -n "${HARNESS_PREFLIGHT_TOKEN:-}" ] &&
   [ -f "$HARNESS_PREFLIGHT_TOKEN_FILE" ] && [ ! -L "$HARNESS_PREFLIGHT_TOKEN_FILE" ] &&
   [ "$(cat "$HARNESS_PREFLIGHT_TOKEN_FILE" 2>/dev/null || true)" = "$HARNESS_PREFLIGHT_TOKEN" ]; then
  preflight_only=1
fi
unset HARNESS_PREFLIGHT_TOKEN_FILE HARNESS_PREFLIGHT_TOKEN HARNESS_INTERNAL_PREFLIGHT
agy_single_root=0
if [ -n "${HARNESS_AGY_SINGLE_ROOT_FILE:-}" ] && [ -n "${HARNESS_AGY_SINGLE_ROOT:-}" ] &&
   [ -f "$HARNESS_AGY_SINGLE_ROOT_FILE" ] && [ ! -L "$HARNESS_AGY_SINGLE_ROOT_FILE" ] &&
   [ "$(cat "$HARNESS_AGY_SINGLE_ROOT_FILE" 2>/dev/null || true)" = "$HARNESS_AGY_SINGLE_ROOT" ]; then
  agy_single_root=1
fi
unset HARNESS_AGY_SINGLE_ROOT_FILE HARNESS_AGY_SINGLE_ROOT
profile=tri
profile_given=0
profile_file_arg=""
profile_file_given=0
target_arg="opencode"
target_given=0
while [ "$#" -gt 0 ]; do
  case "$1" in
    --force) force=1 ;;
    --prune) prune=1 ;;
    --verify|--doctor) verify_mode=1 ;;
    --profile)
      if [ "$#" -lt 2 ] || [ -z "$2" ]; then usage >&2; exit 2; fi
      profile_given=1
      profile="$2"
      shift
      ;;
    --profile=*)
      profile="${1#--profile=}"
      [ -n "$profile" ] || { usage >&2; exit 2; }
      profile_given=1
      ;;
    --profile-file)
      if [ "$#" -lt 2 ] || [ -z "$2" ]; then usage >&2; exit 2; fi
      profile_file_given=1
      profile_file_arg="$2"
      shift
      ;;
    --profile-file=*)
      profile_file_arg="${1#--profile-file=}"
      [ -n "$profile_file_arg" ] || { usage >&2; exit 2; }
      profile_file_given=1
      ;;
    --target)
      if [ "$#" -lt 2 ] || [ -z "$2" ]; then unknown_target ""; fi
      case "$2" in
        ''|,*|*,|*,,*) unknown_target "$2" ;;
      esac
      if [ "$target_given" -eq 1 ]; then
        target_arg="$target_arg,$2"
      else
        target_arg="$2"
      fi
      target_given=1
      shift
      ;;
    --target=*)
      t_val="${1#--target=}"
      case "$t_val" in
        ''|,*|*,|*,,*) unknown_target "$t_val" ;;
      esac
      if [ "$target_given" -eq 1 ]; then
        target_arg="$target_arg,$t_val"
      else
        target_arg="$t_val"
      fi
      target_given=1
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      usage >&2
      exit 2
      ;;
  esac
  shift
done

if [ "$profile_given" -eq 1 ] && [ "$profile_file_given" -eq 1 ]; then
  usage >&2
  exit 2
fi

if [ "$verify_mode" -eq 1 ] && [ "$target_given" -eq 0 ]; then
  discovered_targets=""
  for cand in opencode codex antigravity claude; do
    cand_has=0
    case "$cand" in
      opencode)    cand_dir="${OPENCODE_CONFIG-${HOME:-}/.config/opencode}" ;;
      codex)       cand_dir="${CODEX_HOME-${HOME:-}/.codex}" ;;
      antigravity) cand_dir="${ANTIGRAVITY_CONFIG-${HOME:-}/.gemini/config}" ;;
      claude)      cand_dir="${CLAUDE_CONFIG_DIR-${HOME:-}/.claude}" ;;
    esac
    if [ -n "$cand_dir" ] && { [ -f "$cand_dir/.harness-manifest" ] || [ -f "$cand_dir/HARNESS.md" ] || [ -f "$cand_dir/skills/oneshot/SKILL.md" ]; }; then
      cand_has=1
    elif [ "$cand" = "antigravity" ]; then
      cand_t3="${T3_USERDATA_DIR:-${HOME:-}/.t3/userdata}"
      if [ -n "$cand_t3" ] && [ -d "$cand_t3/providers/antigravity" ]; then
        for cand_inst in "$cand_t3/providers/antigravity"/[!.]*; do
          [ -d "$cand_inst" ] || continue
          if [ -f "$cand_inst/config/.harness-manifest" ] || [ -f "$cand_inst/config/HARNESS.md" ] || [ -f "$cand_inst/config/skills/oneshot/SKILL.md" ]; then
            cand_has=1
            break
          fi
        done
      fi
    fi
    if [ "$cand_has" -eq 1 ]; then
      if [ -n "$discovered_targets" ]; then
        discovered_targets="$discovered_targets,$cand"
      else
        discovered_targets="$cand"
      fi
    fi
  done
  if [ -n "$discovered_targets" ]; then
    target_arg="$discovered_targets"
  fi
fi

# Parse and validate --target before touching anything.
case "$target_arg" in
  ''|,*|*,|*,,*) unknown_target "$target_arg" ;;
esac
selected_targets=()
add_target() {
  local t="$1" existing
  if [ "${#selected_targets[@]}" -gt 0 ]; then
    for existing in "${selected_targets[@]}"; do
      [ "$existing" = "$t" ] && return 0
    done
  fi
  selected_targets+=("$t")
}
OLD_IFS="$IFS"
IFS=','
set -f
for tok in $target_arg; do
  case "$tok" in
    opencode|codex|antigravity|claude)
      add_target "$tok"
      ;;
    all)
      add_target "opencode"
      add_target "codex"
      add_target "antigravity"
      add_target "claude"
      ;;
    *)
      IFS="$OLD_IFS"
      set +f
      unknown_target "$tok"
      ;;
  esac
done
IFS="$OLD_IFS"
set +f
if [ "${#selected_targets[@]}" -eq 0 ]; then
  unknown_target "$target_arg"
fi

SRC_PHYS="$(cd "$SRC" && pwd -P)"
HOME_PHYS="${HOME:-}"
if [ -n "$HOME_PHYS" ] && [ -d "$HOME_PHYS" ]; then
  HOME_PHYS="$(cd "$HOME_PHYS" && pwd -P)"
fi

# canonical_dest <path>: physical form of the path. An existing directory is
# resolved with pwd -P so every symlink is followed; a path that does not exist
# yet is resolved through its deepest existing ancestor with the remaining
# components appended, so "$PWD/agents" and a relative "../skills" compare
# against $SRC_PHYS before they exist. Interior "." segments are stripped while
# walking up; a ".." component is returned as-is and handled by the literal
# checks above.
canonical_dest() {
  local p="$1"
  local suffix=""
  local base
  local out
  while [ ! -d "$p" ]; do
    base="$(basename -- "$p")"
    case "$base" in
      .) p="$(dirname -- "$p")"; continue ;;
      ''|..|/) printf '%s%s' "$p" "$suffix"; return 0 ;;
    esac
    suffix="/$base$suffix"
    p="$(dirname -- "$p")"
  done
  out="$(cd "$p" && pwd -P)$suffix"
  case "$out" in
    //*) out="/${out#//}" ;;
  esac
  printf '%s' "$out"
}

refuse_t3_userdata() {
  if [ "$#" -ge 2 ] && [ -n "$2" ]; then
    printf 'install.sh: refusing unsafe T3 userdata directory: %s (%s)\n' "$1" "$2" >&2
  else
    printf 'install.sh: refusing unsafe T3 userdata directory: %s\n' "$1" >&2
  fi
  exit 1
}

validate_t3_userdata_dir() {
  local t3_raw="$1"
  local t3_compact t3_stripped
  t3_compact="${t3_raw//[[:space:]]/}"
  t3_compact="${t3_compact//\//}"
  if [ -z "$t3_compact" ]; then
    refuse_t3_userdata "$t3_raw"
  fi
  t3_stripped="$t3_raw"
  while [ "${t3_stripped%/}" != "$t3_stripped" ]; do
    t3_stripped="${t3_stripped%/}"
  done
  [ -n "$t3_stripped" ] || t3_stripped="/"
  case "$t3_stripped" in
    .|..|../*|*/..|*/../*) refuse_t3_userdata "$t3_raw" "a relative self or parent reference" ;;
  esac
  if [ -L "$t3_stripped" ] && [ ! -e "$t3_stripped" ]; then
    refuse_t3_userdata "$t3_raw" "dangling symlink"
  fi
  if [ -e "$t3_stripped" ] && [ ! -d "$t3_stripped" ]; then
    refuse_t3_userdata "$t3_raw" "not a directory"
  fi
  T3_CANON="$(canonical_dest "$t3_stripped")"
  if [ -z "$T3_CANON" ]; then
    refuse_t3_userdata "$t3_raw" "an unresolvable path"
  fi
  if [ "$T3_CANON" = "/" ]; then
    refuse_t3_userdata "$t3_raw" "the filesystem root"
  fi
  if [ "$T3_CANON" = "$SRC_PHYS" ] || [ "$T3_CANON" = "$SRC" ] ||
     [ "$t3_stripped" = "$SRC" ] || [ "$t3_stripped" = "$SRC_PHYS" ]; then
    refuse_t3_userdata "$t3_raw" "the source checkout"
  fi
  case "$T3_CANON" in
    "$SRC_PHYS"/*|"$SRC"/*) refuse_t3_userdata "$t3_raw" "inside the source checkout" ;;
  esac
  if { [ -n "$HOME_PHYS" ] && [ "$T3_CANON" = "$HOME_PHYS" ]; } ||
     { [ -n "${HOME:-}" ] && { [ "$t3_raw" = "$HOME" ] || [ "$t3_stripped" = "$HOME" ]; }; }; then
    refuse_t3_userdata "$t3_raw" "the HOME directory"
  fi
}

agy_has_artifacts() {
  local dir="$1"
  if [ -z "$dir" ] || [ ! -d "$dir" ]; then
    return 1
  fi
  if [ -f "$dir/.harness-manifest" ] ||
     [ -f "$dir/HARNESS.md" ] ||
     [ -f "$dir/PROVIDERS.md" ] ||
     [ -f "$dir/rules/HARNESS.md" ] ||
     [ -f "$dir/rules/PROVIDERS.md" ] ||
     [ -f "$dir/skills/oneshot/SKILL.md" ] ||
     [ -d "$dir/skills/_harness" ] ||
     [ -f "$dir/agents/implementer.md" ] ||
     [ -f "$dir/plugins/oneshot-harness/.harness-manifest" ]; then
    return 0
  fi
  return 1
}

agy_seen_canons=()
agy_canon_seen() {
  local want="$1" c
  if [ "${#agy_seen_canons[@]}" -gt 0 ]; then
    for c in "${agy_seen_canons[@]}"; do
      [ "$c" = "$want" ] && return 0
    done
  fi
  return 1
}

job_targets=()
job_override_agy=()
job_agy_configs=()
for tok in "${selected_targets[@]}"; do
  if [ "$tok" != "antigravity" ] || [ "$agy_single_root" -eq 1 ]; then
    job_targets+=("$tok")
    job_override_agy+=(0)
    job_agy_configs+=("")
    continue
  fi

  agy_jobs_before="${#job_targets[@]}"
  agy_primary_raw="${ANTIGRAVITY_CONFIG-${HOME:-}/.gemini/config}"
  agy_probe_dir="$agy_primary_raw"
  while [ "${agy_probe_dir%/}" != "$agy_probe_dir" ]; do
    agy_probe_dir="${agy_probe_dir%/}"
  done

  # Install mode always claims the standalone root. Verify only claims it when
  # harness artifacts already live there, so a machine with nothing but T3 Code
  # instances does not fail on an empty standalone destination.
  agy_standalone_added=0
  if [ "$verify_mode" -eq 0 ] || agy_has_artifacts "$agy_probe_dir"; then
    job_targets+=("antigravity")
    job_override_agy+=(0)
    job_agy_configs+=("")
    agy_standalone_added=1
  fi

  agy_seen_canons=()
  agy_primary_compact="${agy_primary_raw//[[:space:]]/}"
  agy_primary_compact="${agy_primary_compact//\//}"
  if [ -n "$agy_primary_compact" ]; then
    agy_primary_stripped="$agy_primary_raw"
    while [ "${agy_primary_stripped%/}" != "$agy_primary_stripped" ]; do
      agy_primary_stripped="${agy_primary_stripped%/}"
    done
    case "$agy_primary_stripped" in
      ''|.|..|../*|*/..|*/../*) ;;
      *)
        if { [ ! -L "$agy_primary_stripped" ] || [ -e "$agy_primary_stripped" ]; } &&
           { [ ! -e "$agy_primary_stripped" ] || [ -d "$agy_primary_stripped" ]; }; then
          agy_primary_canon="$(canonical_dest "$agy_primary_stripped")"
          if [ -n "$agy_primary_canon" ]; then
            agy_seen_canons+=("$agy_primary_canon")
          fi
        fi
        ;;
    esac
  fi

  if [ -z "${ANTIGRAVITY_CONFIG+x}" ] || [ -n "${T3_USERDATA_DIR+x}" ]; then
    T3_CANON=""
    if [ -n "${T3_USERDATA_DIR+x}" ]; then
      validate_t3_userdata_dir "$T3_USERDATA_DIR"
    else
      T3_RAW="${HOME:-}/.t3/userdata"
      if [ -n "${HOME:-}" ] && [ -d "$T3_RAW" ]; then
        validate_t3_userdata_dir "$T3_RAW"
      fi
    fi
    if [ -n "$T3_CANON" ]; then
      for p in "$T3_CANON/providers" "$T3_CANON/providers/antigravity"; do
        if [ -L "$p" ] || { [ -e "$p" ] && [ ! -d "$p" ]; }; then
          printf 'install.sh: refusing unsafe T3 provider path: %s\n' "$p" >&2
          exit 1
        fi
      done
      if [ -d "$T3_CANON/providers/antigravity" ]; then
        had_lc_all=0
        saved_lc_all=""
        if [ -n "${LC_ALL+x}" ]; then
          had_lc_all=1
          saved_lc_all="$LC_ALL"
        fi
        LC_ALL=C
        shopt -s nullglob
        t3_entries=("$T3_CANON/providers/antigravity"/[!.]*)
        shopt -u nullglob
        if [ "$had_lc_all" -eq 1 ]; then
          LC_ALL="$saved_lc_all"
        else
          unset LC_ALL
        fi
        if [ "${#t3_entries[@]}" -gt 0 ]; then
          for inst in "${t3_entries[@]}"; do
            if [ -L "$inst" ]; then
              printf 'install.sh: refusing symlinked T3 provider instance: %s\n' "$inst" >&2
              exit 1
            fi
            [ -d "$inst" ] || continue
            inst_cfg="$inst/config"
            if [ -L "$inst_cfg" ] || { [ -e "$inst_cfg" ] && [ ! -d "$inst_cfg" ]; }; then
              printf 'install.sh: refusing symlinked T3 provider instance: %s\n' "$inst_cfg" >&2
              exit 1
            fi
            inst_canon="$(canonical_dest "$inst_cfg")"
            if ! agy_canon_seen "$inst_canon"; then
              agy_seen_canons+=("$inst_canon")
              job_targets+=("antigravity")
              job_override_agy+=(1)
              job_agy_configs+=("$inst_cfg")
            fi
          done
        fi
      fi
    fi
  fi

  # No root at all was claimed: fall back to the standalone destination so the
  # job list is never empty (verify then reports the missing install itself).
  if [ "$agy_standalone_added" -eq 0 ] && [ "${#job_targets[@]}" -eq "$agy_jobs_before" ]; then
    job_targets+=("antigravity")
    job_override_agy+=(0)
    job_agy_configs+=("")
  fi
done

read_prev_binding() {
  local dest_canon="$1" target_host="$2"
  local manifest_path="$dest_canon/.harness-manifest"
  local legacy_dir="$dest_canon/plugins/oneshot-harness"
  local legacy_manifest="$legacy_dir/.harness-manifest"
  local mline entry
  PREV_MANIFEST_SOURCE=""
  prev_bad_manifest=0
  prev_profile=""
  prev_profile_present=0
  prev_profile_file=""
  prev_profile_file_present=0
  prev_entry_present=0
  prev_profile_legacy=0
  if [ -L "$manifest_path" ] || { [ -e "$manifest_path" ] && [ ! -f "$manifest_path" ]; }; then
    prev_bad_manifest=1
    return 0
  fi
  if [ -f "$manifest_path" ]; then
    PREV_MANIFEST_SOURCE="$manifest_path"
  elif [ "$target_host" = "antigravity" ] &&
       [ ! -L "$dest_canon/plugins" ] && [ -d "$dest_canon/plugins" ] &&
       [ ! -L "$legacy_dir" ] && [ -d "$legacy_dir" ] &&
       [ ! -L "$legacy_manifest" ] && [ -f "$legacy_manifest" ]; then
    PREV_MANIFEST_SOURCE="$legacy_manifest"
  fi
  if [ -n "$PREV_MANIFEST_SOURCE" ]; then
    while IFS= read -r mline || [ -n "$mline" ]; do
      case "$mline" in
        '# profile '*) prev_profile="${mline#'# profile '}"; prev_profile_present=1; break ;;
        '# profile-file '*) prev_profile_file="${mline#'# profile-file '}"; prev_profile_file_present=1; break ;;
        *)
          entry="${mline#"${mline%%[![:space:]]*}"}"
          case "$entry" in ''|\#*) ;; *) prev_entry_present=1 ;; esac
          ;;
      esac
    done <"$PREV_MANIFEST_SOURCE"
  fi
  if [ "$prev_profile_present" -eq 0 ] && [ "$prev_profile_file_present" -eq 0 ] &&
     { [ "$prev_entry_present" -eq 1 ] || { [ -z "$PREV_MANIFEST_SOURCE" ] && [ -f "$dest_canon/HARNESS.md" ]; }; }; then
    prev_profile=opencode-go
    prev_profile_present=1
    prev_profile_legacy=1
  fi
  return 0
}

# When multiple jobs are scheduled (multiple targets or standalone + T3 instances),
# run each job in its own clean invocation so per-root destination validation,
# manifest tracking, and temp cleanup stay isolated. A nonce-guarded atomic
# preflight pass runs across all jobs first so any invalid destination or
# collision aborts before any root is mutated.
if [ "${#job_targets[@]}" -gt 1 ]; then
  if [ "$verify_mode" -eq 1 ]; then
    trap 'rm -f -- ${sr_token_file:+"$sr_token_file"}' EXIT
    sr_token_file="$(mktemp "${TMPDIR:-/tmp}/harness-sr.XXXXXXXX")"
    chmod 0600 "$sr_token_file"
    sr_token="$$-$(date +%s)-${RANDOM:-0}-sr"
    printf '%s' "$sr_token" >"$sr_token_file"
    verify_rc=0
    for idx in "${!job_targets[@]}"; do
      jt="${job_targets[$idx]}"
      if [ "${job_override_agy[$idx]}" -eq 1 ]; then
        ANTIGRAVITY_CONFIG="${job_agy_configs[$idx]}" \
          HARNESS_AGY_SINGLE_ROOT_FILE="$sr_token_file" HARNESS_AGY_SINGLE_ROOT="$sr_token" \
          "$SRC/install.sh" --verify --target "$jt" || verify_rc=1
      else
        HARNESS_AGY_SINGLE_ROOT_FILE="$sr_token_file" HARNESS_AGY_SINGLE_ROOT="$sr_token" \
          "$SRC/install.sh" --verify --target "$jt" || verify_rc=1
      fi
    done
    rm -f -- "$sr_token_file"
    sr_token_file=""
    exit "$verify_rc"
  fi
  sub_args=()
  [ "$force" -eq 1 ] && sub_args+=("--force")
  [ "$prune" -eq 1 ] && sub_args+=("--prune")
  if [ "$profile_given" -eq 1 ]; then
    sub_args+=("--profile" "$profile")
  elif [ "$profile_file_given" -eq 1 ]; then
    sub_args+=("--profile-file" "$profile_file_arg")
  fi
  agy_standalone_args=()
  agy_t3_args=()
  if [ "${#sub_args[@]}" -gt 0 ]; then
    agy_standalone_args=("${sub_args[@]}")
    agy_t3_args=("${sub_args[@]}")
  fi
  has_agy_override=0
  for idx in "${!job_override_agy[@]}"; do
    if [ "${job_override_agy[$idx]}" -eq 1 ]; then
      has_agy_override=1
      break
    fi
  done
  if [ "$has_agy_override" -eq 1 ] && [ "$profile_given" -eq 0 ] && [ "$profile_file_given" -eq 0 ]; then
    agy_standalone_bad=0
    agy_standalone_bound=0
    agy_primary_raw="${ANTIGRAVITY_CONFIG-${HOME:-}/.gemini/config}"
    agy_primary_compact="${agy_primary_raw//[[:space:]]/}"
    agy_primary_compact="${agy_primary_compact//\//}"
    if [ -z "$agy_primary_compact" ]; then
      agy_standalone_bad=1
    else
      agy_primary_stripped="$agy_primary_raw"
      while [ "${agy_primary_stripped%/}" != "$agy_primary_stripped" ]; do
        agy_primary_stripped="${agy_primary_stripped%/}"
      done
      [ -n "$agy_primary_stripped" ] || agy_primary_stripped="/"
      case "$agy_primary_stripped" in
        ''|.|..|../*|*/..|*/../*) agy_standalone_bad=1 ;;
        *)
          if [ -L "$agy_primary_stripped" ] && [ ! -e "$agy_primary_stripped" ]; then
            agy_standalone_bad=1
          elif [ -e "$agy_primary_stripped" ] && [ ! -d "$agy_primary_stripped" ]; then
            agy_standalone_bad=1
          else
            agy_primary_canon="$(canonical_dest "$agy_primary_stripped")"
            if [ -z "$agy_primary_canon" ] || [ "$agy_primary_canon" = "/" ] ||
               [ "$agy_primary_canon" = "$SRC_PHYS" ] || [ "$agy_primary_canon" = "$SRC" ] ||
               [ "$agy_primary_stripped" = "$SRC" ] || [ "$agy_primary_stripped" = "$SRC_PHYS" ]; then
              agy_standalone_bad=1
            else
              case "$agy_primary_canon" in
                "$SRC_PHYS"/*|"$SRC"/*) agy_standalone_bad=1 ;;
              esac
              if { [ -n "$HOME_PHYS" ] && [ "$agy_primary_canon" = "$HOME_PHYS" ]; } ||
                 { [ -n "${HOME:-}" ] && { [ "$agy_primary_raw" = "$HOME" ] || [ "$agy_primary_stripped" = "$HOME" ]; }; }; then
                agy_standalone_bad=1
              fi
            fi
            if [ "$agy_standalone_bad" -eq 0 ] && [ -d "$agy_primary_stripped" ]; then
              read_prev_binding "$agy_primary_canon" "antigravity"
              if [ "$prev_bad_manifest" -eq 1 ]; then
                agy_standalone_bad=1
              elif [ "$prev_profile_file_present" -eq 1 ] && [ -n "$prev_profile_file" ]; then
                agy_t3_args+=("--profile-file" "$prev_profile_file")
                agy_standalone_bound=1
              elif [ "$prev_profile_present" -eq 1 ] && [ -n "$prev_profile" ]; then
                agy_t3_args+=("--profile" "$prev_profile")
                agy_standalone_bound=1
              elif [ "$prev_profile_file_present" -eq 1 ] || [ "$prev_profile_present" -eq 1 ]; then
                agy_standalone_bound=1
              fi
            fi
          fi
          ;;
      esac
    fi
    if [ "$agy_standalone_bad" -eq 0 ] && [ "$agy_standalone_bound" -eq 0 ]; then
      for idx in "${!job_override_agy[@]}"; do
        [ "${job_override_agy[$idx]}" -eq 1 ] || continue
        t3_cfg="${job_agy_configs[$idx]}"
        [ ! -L "$t3_cfg" ] && [ -d "$t3_cfg" ] || continue
        t3_canon="$(canonical_dest "$t3_cfg")"
        [ -n "$t3_canon" ] || continue
        read_prev_binding "$t3_canon" "antigravity"
        if [ "$prev_bad_manifest" -eq 1 ]; then
          break
        elif [ "$prev_profile_file_present" -eq 1 ] && [ -n "$prev_profile_file" ]; then
          agy_standalone_args+=("--profile-file" "$prev_profile_file")
          agy_t3_args+=("--profile-file" "$prev_profile_file")
          break
        elif [ "$prev_profile_present" -eq 1 ] && [ -n "$prev_profile" ]; then
          agy_standalone_args+=("--profile" "$prev_profile")
          agy_t3_args+=("--profile" "$prev_profile")
          break
        elif [ "$prev_profile_file_present" -eq 1 ] || [ "$prev_profile_present" -eq 1 ]; then
          break
        fi
      done
    fi
  fi
  invoke_subjob() {
    local idx="$1" is_pf="$2"
    local jt="${job_targets[$idx]}"
    local jargs=()
    if [ "${job_override_agy[$idx]}" -eq 1 ]; then
      [ "${#agy_t3_args[@]}" -gt 0 ] && jargs=("${agy_t3_args[@]}")
      if [ "$is_pf" -eq 1 ]; then
        if [ "${#jargs[@]}" -gt 0 ]; then
          ANTIGRAVITY_CONFIG="${job_agy_configs[$idx]}" \
            HARNESS_PREFLIGHT_TOKEN_FILE="$pf_token_file" HARNESS_PREFLIGHT_TOKEN="$pf_token" \
            HARNESS_AGY_SINGLE_ROOT_FILE="$sr_token_file" HARNESS_AGY_SINGLE_ROOT="$sr_token" \
            "$SRC/install.sh" "${jargs[@]}" --target "$jt"
        else
          ANTIGRAVITY_CONFIG="${job_agy_configs[$idx]}" \
            HARNESS_PREFLIGHT_TOKEN_FILE="$pf_token_file" HARNESS_PREFLIGHT_TOKEN="$pf_token" \
            HARNESS_AGY_SINGLE_ROOT_FILE="$sr_token_file" HARNESS_AGY_SINGLE_ROOT="$sr_token" \
            "$SRC/install.sh" --target "$jt"
        fi
      else
        if [ "${#jargs[@]}" -gt 0 ]; then
          ANTIGRAVITY_CONFIG="${job_agy_configs[$idx]}" \
            HARNESS_AGY_SINGLE_ROOT_FILE="$sr_token_file" HARNESS_AGY_SINGLE_ROOT="$sr_token" \
            "$SRC/install.sh" "${jargs[@]}" --target "$jt"
        else
          ANTIGRAVITY_CONFIG="${job_agy_configs[$idx]}" \
            HARNESS_AGY_SINGLE_ROOT_FILE="$sr_token_file" HARNESS_AGY_SINGLE_ROOT="$sr_token" \
            "$SRC/install.sh" --target "$jt"
        fi
      fi
    else
      if [ "$jt" = "antigravity" ]; then
        [ "${#agy_standalone_args[@]}" -gt 0 ] && jargs=("${agy_standalone_args[@]}")
      else
        [ "${#sub_args[@]}" -gt 0 ] && jargs=("${sub_args[@]}")
      fi
      if [ "$is_pf" -eq 1 ]; then
        if [ "${#jargs[@]}" -gt 0 ]; then
          HARNESS_PREFLIGHT_TOKEN_FILE="$pf_token_file" HARNESS_PREFLIGHT_TOKEN="$pf_token" \
            HARNESS_AGY_SINGLE_ROOT_FILE="$sr_token_file" HARNESS_AGY_SINGLE_ROOT="$sr_token" \
            "$SRC/install.sh" "${jargs[@]}" --target "$jt"
        else
          HARNESS_PREFLIGHT_TOKEN_FILE="$pf_token_file" HARNESS_PREFLIGHT_TOKEN="$pf_token" \
            HARNESS_AGY_SINGLE_ROOT_FILE="$sr_token_file" HARNESS_AGY_SINGLE_ROOT="$sr_token" \
            "$SRC/install.sh" --target "$jt"
        fi
      else
        if [ "${#jargs[@]}" -gt 0 ]; then
          HARNESS_AGY_SINGLE_ROOT_FILE="$sr_token_file" HARNESS_AGY_SINGLE_ROOT="$sr_token" \
            "$SRC/install.sh" "${jargs[@]}" --target "$jt"
        else
          HARNESS_AGY_SINGLE_ROOT_FILE="$sr_token_file" HARNESS_AGY_SINGLE_ROOT="$sr_token" \
            "$SRC/install.sh" --target "$jt"
        fi
      fi
    fi
  }
  trap 'rm -f -- ${pf_token_file:+"$pf_token_file"} ${sr_token_file:+"$sr_token_file"}' EXIT
  pf_token_file="$(mktemp "${TMPDIR:-/tmp}/harness-pf.XXXXXXXX")"
  chmod 0600 "$pf_token_file"
  pf_token="$$-$(date +%s)-${RANDOM:-0}"
  printf '%s' "$pf_token" >"$pf_token_file"
  sr_token_file="$(mktemp "${TMPDIR:-/tmp}/harness-sr.XXXXXXXX")"
  chmod 0600 "$sr_token_file"
  sr_token="$$-$(date +%s)-${RANDOM:-0}-sr"
  printf '%s' "$sr_token" >"$sr_token_file"
  for idx in "${!job_targets[@]}"; do
    invoke_subjob "$idx" 1
  done
  rm -f -- "$pf_token_file"
  pf_token_file=""
  if [ "$preflight_only" -eq 1 ]; then
    rm -f -- "$sr_token_file"
    sr_token_file=""
    exit 0
  fi
  for idx in "${!job_targets[@]}"; do
    invoke_subjob "$idx" 0
  done
  rm -f -- "$sr_token_file"
  sr_token_file=""
  if [ "$target_given" -eq 0 ] && { { [ -n "${T3_USERDATA_DIR:-}" ] && [ -d "$T3_USERDATA_DIR" ]; } || [ -d "${HOME:-}/.t3/userdata" ]; }; then
    printf "tip: T3 Code detected; pass '--target all' to install across all T3-connected providers (Antigravity, Codex, OpenCode, Claude).\n"
  fi
  exit 0
fi

TARGET_HOST="${job_targets[0]}"
if [ "${job_override_agy[0]}" -eq 1 ]; then
  ANTIGRAVITY_CONFIG="${job_agy_configs[0]}"
fi

# Destination validation. Runs before any path is created or removed, and
# before the trailing slash is stripped, so a hostile or degenerate
# config variable never reaches the install or prune loops: a value made only
# of whitespace and slashes names no directory at all, "/" and "//" are the
# filesystem root, "." under --force can unlink files out of the source tree,
# a destination inside the source checkout can overwrite it, and a whitespace
# value silently installs into a relative directory. Only an unset variable
# falls back to the default, so an explicitly empty value is caught instead of
# being replaced.
case "$TARGET_HOST" in
  opencode)    DEST_RAW="${OPENCODE_CONFIG-$HOME/.config/opencode}" ;;
  codex)       DEST_RAW="${CODEX_HOME-$HOME/.codex}" ;;
  antigravity) DEST_RAW="${ANTIGRAVITY_CONFIG-$HOME/.gemini/config}" ;;
  claude)      DEST_RAW="${CLAUDE_CONFIG_DIR-$HOME/.claude}" ;;
esac

# Degenerate values: strip whitespace and slashes; nothing left means there is
# no directory component to install into (empty, " ", "/", "//", "/ /").
DEST_COMPACT="${DEST_RAW//[[:space:]]/}"
DEST_COMPACT="${DEST_COMPACT//\//}"
if [ -z "$DEST_COMPACT" ]; then
  printf 'install.sh: refusing unsafe destination: %s\n' "$DEST_RAW" >&2
  exit 1
fi

# One refusal message per unsafe case; the reason is named on the same line.
refuse_dest() {
  printf 'install.sh: refusing unsafe destination: %s (%s)\n' "$DEST_RAW" "$1" >&2
  exit 1
}

DEST_STRIPPED="$DEST_RAW"
while [ "${DEST_STRIPPED%/}" != "$DEST_STRIPPED" ]; do
  DEST_STRIPPED="${DEST_STRIPPED%/}"
done
[ -n "$DEST_STRIPPED" ] || DEST_STRIPPED="/"

# A bare self reference or any parent-traversal component is refused before
# resolution, so relative paths such as nonexistent/../evil cannot slip past
# canonical_dest when the leading component does not exist yet.
case "$DEST_STRIPPED" in
  .|..|../*|*/..|*/../*) refuse_dest "a relative self or parent reference" ;;
esac

# A dangling destination symlink cannot hold anything: mkdir -p follows it and
# creates the link target, so refuse before any directory is made.
if [ -L "$DEST_STRIPPED" ] && [ ! -e "$DEST_STRIPPED" ]; then
  printf 'install.sh: destination symlink is dangling: %s\n' "$DEST_RAW" >&2
  exit 1
fi

if [ -e "$DEST_STRIPPED" ] && [ ! -d "$DEST_STRIPPED" ]; then
  printf 'install.sh: destination is not a directory: %s\n' "$DEST_RAW" >&2
  exit 1
fi

DEST_CANON="$(canonical_dest "$DEST_STRIPPED")"
if [ -z "$DEST_CANON" ]; then
  refuse_dest "an unresolvable path"
fi

# The filesystem root, reached directly ("/", already refused above) or
# through an alias such as "/." or "/./".
if [ "$DEST_CANON" = "/" ]; then
  refuse_dest "the filesystem root"
fi

# The source checkout itself, or anything nested inside it: --force would
# rewrite the harness sources in place.
if [ "$DEST_CANON" = "$SRC_PHYS" ] || [ "$DEST_CANON" = "$SRC" ] ||
   [ "$DEST_STRIPPED" = "$SRC" ] || [ "$DEST_STRIPPED" = "$SRC_PHYS" ]; then
  refuse_dest "the source checkout"
fi
case "$DEST_CANON" in
  "$SRC_PHYS"/*|"$SRC"/*) refuse_dest "inside the source checkout" ;;
esac

# HOME itself would scatter HARNESS.md and agents over the home directory.
if [ "$DEST_CANON" = "$HOME_PHYS" ] ||
   { [ -n "${HOME:-}" ] && { [ "$DEST_RAW" = "$HOME" ] || [ "$DEST_STRIPPED" = "$HOME" ]; }; }; then
  refuse_dest "the HOME directory"
fi

DEST="$DEST_CANON"

SHARED_OC_CANON=""
SHARED_STATE=""
if [ "$TARGET_HOST" != "opencode" ]; then
  SHARED_OC_RAW="${OPENCODE_CONFIG-$HOME/.config/opencode}"
  SHARED_OC_COMPACT="${SHARED_OC_RAW//[[:space:]]/}"
  SHARED_OC_COMPACT="${SHARED_OC_COMPACT//\//}"
  if [ -z "$SHARED_OC_COMPACT" ]; then
    printf 'install.sh: refusing unsafe shared state root: %s\n' "$SHARED_OC_RAW" >&2
    exit 1
  fi
  refuse_shared_oc() {
    printf 'install.sh: refusing unsafe shared state root: %s (%s)\n' "$SHARED_OC_RAW" "$1" >&2
    exit 1
  }
  SHARED_OC_STRIPPED="$SHARED_OC_RAW"
  while [ "${SHARED_OC_STRIPPED%/}" != "$SHARED_OC_STRIPPED" ]; do
    SHARED_OC_STRIPPED="${SHARED_OC_STRIPPED%/}"
  done
  [ -n "$SHARED_OC_STRIPPED" ] || SHARED_OC_STRIPPED="/"
  case "$SHARED_OC_STRIPPED" in
    .|..|../*|*/..|*/../*) refuse_shared_oc "a relative self or parent reference" ;;
  esac
  if [ -L "$SHARED_OC_STRIPPED" ] && [ ! -e "$SHARED_OC_STRIPPED" ]; then
    printf 'install.sh: shared state root symlink is dangling: %s\n' "$SHARED_OC_RAW" >&2
    exit 1
  fi
  if [ -e "$SHARED_OC_STRIPPED" ] && [ ! -d "$SHARED_OC_STRIPPED" ]; then
    printf 'install.sh: shared state root is not a directory: %s\n' "$SHARED_OC_RAW" >&2
    exit 1
  fi
  SHARED_OC_CANON="$(canonical_dest "$SHARED_OC_STRIPPED")"
  if [ -z "$SHARED_OC_CANON" ]; then
    refuse_shared_oc "an unresolvable path"
  fi
  if [ "$SHARED_OC_CANON" = "/" ]; then
    refuse_shared_oc "the filesystem root"
  fi
  if [ "$SHARED_OC_CANON" = "$SRC_PHYS" ] || [ "$SHARED_OC_CANON" = "$SRC" ] ||
     [ "$SHARED_OC_STRIPPED" = "$SRC" ] || [ "$SHARED_OC_STRIPPED" = "$SRC_PHYS" ]; then
    refuse_shared_oc "the source checkout"
  fi
  case "$SHARED_OC_CANON" in
    "$SRC_PHYS"/*|"$SRC"/*) refuse_shared_oc "inside the source checkout" ;;
  esac
  if [ "$SHARED_OC_CANON" = "$HOME_PHYS" ] ||
     { [ -n "${HOME:-}" ] && { [ "$SHARED_OC_RAW" = "$HOME" ] || [ "$SHARED_OC_STRIPPED" = "$HOME" ]; }; }; then
    refuse_shared_oc "the HOME directory"
  fi
  SHARED_STATE="$SHARED_OC_CANON/state"
fi

MANIFEST="$DEST/.harness-manifest"
if [ -L "$MANIFEST" ] || { [ -e "$MANIFEST" ] && [ ! -f "$MANIFEST" ]; }; then
  printf 'install.sh: manifest path is not a regular file: %s\n' "$MANIFEST" >&2
  exit 1
fi

verify_opencode_json() {
  JSON_FILE="$1" TARGET_DEST="$DEST" TARGET_RAW="$DEST_STRIPPED" HOME_RAW="${HOME:-}" HOME_CANON="${HOME_PHYS:-}" awk '
    function skip_ws(    c) {
      while (pos <= len) {
        c = substr(data, pos, 1)
        if (c == " " || c == "\t" || c == "\n" || c == "\r") pos++
        else break
      }
    }
    function parse_string(    c, esc, hex, s) {
      if (substr(data, pos, 1) != "\"") return ""
      pos++
      s = ""
      while (pos <= len) {
        c = substr(data, pos, 1)
        if (c == "\\") {
          pos++
          if (pos > len) { bad = 1; return "" }
          esc = substr(data, pos, 1)
          if (esc == "u") {
            hex = substr(data, pos + 1, 4)
            if (length(hex) != 4 || hex !~ /^[0-9a-fA-F]+$/) { bad = 1; return "" }
          } else if (esc != "\"" && esc != "\\" && esc != "/" &&
                     esc != "b" && esc != "f" && esc != "n" && esc != "r" && esc != "t") {
            bad = 1
            return ""
          }
          s = s esc
          pos++
        } else if (c == "\"") {
          pos++
          return s
        } else if (c == "\n" || c == "\r") {
          bad = 1
          return ""
        } else {
          s = s c
          pos++
        }
      }
      bad = 1
      return ""
    }
    function match_inst(s, name,    s_raw, s_canon) {
      while (substr(s, 1, 2) == "./") s = substr(s, 3)
      if (s == name) return 1
      if (s == target_dest "/" name || s == target_raw "/" name) return 1
      if (substr(s, 1, 2) == "~/") {
        if (home_raw != "") {
          s_raw = home_raw substr(s, 2)
          if (s_raw == target_dest "/" name || s_raw == target_raw "/" name) return 1
        }
        if (home_canon != "") {
          s_canon = home_canon substr(s, 2)
          if (s_canon == target_dest "/" name || s_canon == target_raw "/" name) return 1
        }
      }
      return 0
    }
    function parse_value(in_inst,    c, s, rest) {
      skip_ws()
      if (pos > len) { bad = 1; return }
      c = substr(data, pos, 1)
      if (c == "{") {
        if (in_inst) { bad = 1; return }
        parse_object(0)
      } else if (c == "[") {
        if (in_inst) { bad = 1; return }
        parse_array(0)
      } else if (c == "\"") {
        s = parse_string()
        if (in_inst) {
          if (match_inst(s, "HARNESS.md")) has_harness = 1
          if (match_inst(s, "PROVIDERS.md")) has_providers = 1
        }
      } else if (substr(data, pos, 4) == "true") {
        if (in_inst) bad = 1
        pos += 4
      } else if (substr(data, pos, 5) == "false") {
        if (in_inst) bad = 1
        pos += 5
      } else if (substr(data, pos, 4) == "null") {
        if (in_inst) bad = 1
        pos += 4
      } else if (c ~ /[-0-9]/) {
        rest = substr(data, pos)
        if (in_inst || !match(rest, /^-?(0|[1-9][0-9]*)(\.[0-9]+)?([eE][+-]?[0-9]+)?/)) {
          bad = 1
          return
        }
        pos += RLENGTH
      } else {
        bad = 1
      }
    }
    function parse_array(in_inst,    c) {
      pos++
      skip_ws()
      if (pos <= len && substr(data, pos, 1) == "]") {
        pos++
        return
      }
      while (pos <= len && !bad) {
        parse_value(in_inst ? 1 : 0)
        if (bad) return
        skip_ws()
        c = substr(data, pos, 1)
        if (c == ",") {
          pos++
        } else if (c == "]") {
          pos++
          return
        } else {
          bad = 1
          return
        }
      }
      bad = 1
    }
    function parse_object(is_top,    c, k) {
      pos++
      skip_ws()
      if (pos <= len && substr(data, pos, 1) == "}") {
        pos++
        return
      }
      while (pos <= len && !bad) {
        skip_ws()
        if (substr(data, pos, 1) != "\"") { bad = 1; return }
        k = parse_string()
        if (bad) return
        skip_ws()
        if (substr(data, pos, 1) != ":") { bad = 1; return }
        pos++
        skip_ws()
        if (is_top && k == "instructions") {
          if (substr(data, pos, 1) == "[") {
            found_inst = 1
            has_harness = 0
            has_providers = 0
            parse_array(1)
          } else {
            found_inst = 0
            parse_value(0)
          }
        } else {
          parse_value(0)
        }
        if (bad) return
        skip_ws()
        c = substr(data, pos, 1)
        if (c == ",") {
          pos++
        } else if (c == "}") {
          pos++
          return
        } else {
          bad = 1
          return
        }
      }
      bad = 1
    }
    BEGIN {
      jf = ENVIRON["JSON_FILE"]
      target_dest = ENVIRON["TARGET_DEST"]
      target_raw = ENVIRON["TARGET_RAW"]
      home_raw = ENVIRON["HOME_RAW"]
      home_canon = ENVIRON["HOME_CANON"]
      sub(/\/+$/, "", home_raw)
      sub(/\/+$/, "", home_canon)
      data = ""
      while ((getline line < jf) > 0) {
        data = data line "\n"
      }
      close(jf)
      pos = 1
      len = length(data)
      found_inst = 0
      has_harness = 0
      has_providers = 0
      skip_ws()
      if (pos > len || substr(data, pos, 1) != "{") {
        exit 1
      }
      parse_object(1)
      skip_ws()
      if (bad || pos <= len || !found_inst || !has_harness || !has_providers) {
        exit 1
      }
      exit 0
    }
  ' </dev/null
}

verify_combined_instructions() {
  local doc="$1"
  grep -qF '# Cybernetic SDLC Harness' "$doc" &&
    grep -qF '## Dispatch Adapter' "$doc" &&
    grep -qE '^\|[[:space:]]*implementer[[:space:]]*\|[[:space:]]*primary[[:space:]]*\|' "$doc"
}

verify_agy_rule() {
  local rule_file="$1"
  awk '
    NR == 1 {
      if ($0 != "---") exit 1
      in_fm = 1
      next
    }
    in_fm && $0 == "---" {
      in_fm = 0
      closed = 1
      exit (has_trigger ? 0 : 1)
    }
    in_fm && /^[[:space:]]*trigger:[[:space:]]*always_on[[:space:]]*$/ {
      has_trigger = 1
    }
    END {
      if (!closed || !has_trigger) exit 1
    }
  ' "$rule_file"
}

REQUIRED_ROLES='scout implementer implementer-deep patch tester reviewer-a reviewer-b reviewer-c reviewer-esc task-reviewer'

validate_profile() {
  PROFILE_NAME="$2" REQUIRED_ROLES="$REQUIRED_ROLES" awk -F '|' '
    BEGIN {
      profile = ENVIRON["PROFILE_NAME"]
      n = split(ENVIRON["REQUIRED_ROLES"], ordered, " ")
      for (i = 1; i <= n; i++) {
        known[ordered[i]] = 1
        dispatched[ordered[i]] = 1
      }
      known["driver"] = known["compaction"] = 1
      section = "roles"
    }
    function invalid(reason) {
      printf "install.sh: profile %s invalid row: %s %s: %s\n", profile, $2, $3, reason > "/dev/stderr"
      failed = 1
      exit 1
    }
    function invalid_pool(reason) {
      printf "install.sh: profile %s invalid pool row: %s: %s\n", profile, $2, reason > "/dev/stderr"
      failed = 1
      exit 1
    }
    function invalid_backup(reason) {
      printf "install.sh: profile %s invalid backup row: %s: %s\n", profile, $2, reason > "/dev/stderr"
      failed = 1
      exit 1
    }
    /^[[:space:]]*```/ { fenced = !fenced; next }
    fenced { next }
    /^##[[:space:]]+Quota pools([[:space:]]|$)/ { section = "pools"; next }
    /^##[[:space:]]+Backup ladder([[:space:]]|$)/ { section = "backups"; next }
    /^##[[:space:]]+/ { section = "roles"; next }
    /^[[:space:]]*[|]/ {
      for (i = 1; i <= NF; i++) gsub(/^[[:space:]]+|[[:space:]]+$/, "", $i)
      if (section == "pools") {
        if (NF != 8 || $NF != "") invalid_pool("expected 6 cells")
        if ($2 == "pool" && $3 == "provider" && $4 == "models" && $5 == "window" && $6 == "soft-cap" && $7 == "reserve") next
        if ($2 ~ /^:?-+:?$/ && $3 ~ /^:?-+:?$/ && $4 ~ /^:?-+:?$/ && $5 ~ /^:?-+:?$/ && $6 ~ /^:?-+:?$/ && $7 ~ /^:?-+:?$/) next
        for (i = 2; i <= 7; i++) if ($i == "") invalid_pool("empty cell")
        if ($2 !~ /^[a-z0-9][a-z0-9-]*$/) invalid_pool("invalid pool")
        if ($2 in seen_pool) invalid_pool("duplicate pool")
        seen_pool[$2] = 1
        if ($3 !~ /^[A-Za-z0-9][A-Za-z0-9-]*$/) invalid_pool("invalid provider")
        if ($4 !~ /^[A-Za-z0-9*][A-Za-z0-9._\/*-]*$/) invalid_pool("invalid models")
        if ($5 !~ /^[1-9][0-9]*(h|d|w|mo)$/) invalid_pool("invalid window")
        if ($6 != "-" && $6 !~ /^[1-9][0-9]*$/) invalid_pool("invalid soft-cap")
        if ($7 != "-") {
          m = split($7, rlist, ",")
          if (m < 1) invalid_pool("invalid reserve")
          for (j = 1; j <= m; j++) {
            if (rlist[j] == "" || !(rlist[j] in known)) invalid_pool("invalid reserve")
          }
        }
        next
      }
      if (section == "backups") {
        if (NF != 9 || $NF != "") invalid_backup("expected 7 cells")
        if ($2 == "order" && $3 == "roles" && $4 == "provider" && $5 == "model" && $6 == "effort" && $7 == "family" && $8 == "privacy") next
        if ($2 ~ /^:?-+:?$/ && $3 ~ /^:?-+:?$/ && $4 ~ /^:?-+:?$/ && $5 ~ /^:?-+:?$/ && $6 ~ /^:?-+:?$/ && $7 ~ /^:?-+:?$/ && $8 ~ /^:?-+:?$/) next
        for (i = 2; i <= 8; i++) if ($i == "") invalid_backup("empty cell")
        if ($2 !~ /^[1-9][0-9]*$/) invalid_backup("invalid order")
        if ($2 in seen_order) invalid_backup("duplicate order")
        seen_order[$2] = 1
        if ($3 != "*") {
          m = split($3, blist, ",")
          if (m < 1) invalid_backup("invalid roles")
          for (j = 1; j <= m; j++) {
            if (blist[j] == "" || !(blist[j] in dispatched)) invalid_backup("invalid roles")
          }
        }
        if ($4 !~ /^[A-Za-z0-9][A-Za-z0-9-]*$/) invalid_backup("invalid provider")
        if ($5 !~ /^[A-Za-z0-9][A-Za-z0-9._\/-]*$/) invalid_backup("invalid model")
        if ($6 !~ /^(-|[A-Za-z_]+=[A-Za-z0-9][A-Za-z0-9._-]*)$/) invalid_backup("invalid effort")
        if ($7 !~ /^[a-z0-9][a-z0-9-]*$/) invalid_backup("invalid family")
        if ($8 != "ok" && $8 != "trains") invalid_backup("invalid privacy")
        next
      }
      role = $2
      if (!(role in known)) next
      if (NF != 9 || $NF != "") invalid("expected 7 cells")
      for (i = 2; i <= 8; i++) if ($i == "") invalid("empty cell")
      if ($3 != "primary" && $3 != "fallback" && $3 != "last-resort") invalid("invalid rung")
      if ($8 != "ok" && $8 != "trains") invalid("invalid privacy")
      advisory = (role == "driver" || role == "compaction")
      if (!(advisory && $4 == "-") && $4 !~ /^[A-Za-z0-9][A-Za-z0-9-]*$/) invalid("invalid provider")
      if (!(advisory && $5 == "-") && $5 !~ /^[A-Za-z0-9][A-Za-z0-9._\/-]*$/) invalid("invalid model")
      if ($6 !~ /^(-|[A-Za-z_]+=[A-Za-z0-9][A-Za-z0-9._-]*)$/) invalid("invalid effort")
      if (!(advisory && $7 == "-") && $7 !~ /^[a-z0-9][a-z0-9-]*$/) invalid("invalid family")
      key = role SUBSEP $3
      if (key in seen) invalid("duplicate rung")
      seen[key] = 1
      if ($3 == "primary") primary[role] = 1
      print $2 "|" $3 "|" $4 "|" $5 "|" $6 "|" $7 "|" $8
    }
    END {
      if (failed) exit 1
      for (i = 1; i <= n; i++) {
        role = ordered[i]
        if (!(role in primary)) {
          printf "install.sh: profile %s incomplete: %s\n", profile, role > "/dev/stderr"
          exit 1
        }
      }
    }
  ' "$1"
}

verify_target() {
  local v_errors=0
  local req file m_count=0 m_missing=0
  local mline v_prof_type="" v_prof_val="" v_prof_path=""
  printf 'verifying %s (%s):\n' "$TARGET_HOST" "$DEST"
  if [ ! -d "$DEST" ]; then
    printf '  [FAIL] destination directory missing: %s\n' "$DEST"
    return 1
  fi
  if [ ! -f "$MANIFEST" ] || [ -L "$MANIFEST" ]; then
    printf '  [FAIL] manifest missing: %s\n' "$MANIFEST"
    v_errors=$((v_errors + 1))
  else
    printf '  [OK] manifest: %s\n' "$MANIFEST"
    while IFS= read -r file || [ -n "$file" ]; do
      case "$file" in
        '# profile '*)
          if [ -z "$v_prof_type" ]; then
            v_prof_type="profile"
            v_prof_val="${file#'# profile '}"
          fi
          continue
          ;;
        '# profile-file '*)
          if [ -z "$v_prof_type" ]; then
            v_prof_type="profile-file"
            v_prof_val="${file#'# profile-file '}"
          fi
          continue
          ;;
        ''|'#'*) continue ;;
      esac
      m_count=$((m_count + 1))
      if [ ! -f "$DEST/$file" ]; then
        printf '  [FAIL] manifest file missing: %s\n' "$file"
        v_errors=$((v_errors + 1))
        m_missing=$((m_missing + 1))
      fi
    done <"$MANIFEST"
    if [ "$m_missing" -eq 0 ]; then
      printf '  [OK] manifest files: all %d files verified\n' "$m_count"
    fi
    if [ -z "$v_prof_type" ] && [ "$m_count" -gt 0 ]; then
      v_prof_type="profile"
      v_prof_val="opencode-go"
    fi
    if [ -z "$v_prof_type" ] || [ -z "$v_prof_val" ]; then
      printf '  [FAIL] profile binding missing or unreadable: %s\n' "${v_prof_val:-<none>}"
      v_errors=$((v_errors + 1))
    else
      if [ "$v_prof_type" = "profile" ]; then
        case "$v_prof_val" in
          ''|[!a-z0-9]*|*[!a-z0-9-]*)
            v_prof_path=""
            ;;
          *)
            v_prof_path="$SRC/providers/$v_prof_val.md"
            ;;
        esac
      else
        v_prof_path="$v_prof_val"
      fi
      if [ -z "$v_prof_path" ] || [ ! -f "$v_prof_path" ] || [ ! -r "$v_prof_path" ]; then
        printf '  [FAIL] profile binding missing or unreadable: %s\n' "$v_prof_val"
        v_errors=$((v_errors + 1))
      elif ! validate_profile "$v_prof_path" "$v_prof_val" >/dev/null 2>&1; then
        printf '  [FAIL] profile binding invalid: %s\n' "$v_prof_val"
        v_errors=$((v_errors + 1))
      else
        printf '  [OK] profile binding: %s\n' "$v_prof_val"
      fi
    fi
  fi
  for req in HARNESS.md PROVIDERS.md skills/oneshot/SKILL.md skills/council/SKILL.md; do
    if [ ! -f "$DEST/$req" ]; then
      printf '  [FAIL] required file missing: %s\n' "$req"
      v_errors=$((v_errors + 1))
    else
      printf '  [OK] required file: %s\n' "$req"
    fi
  done
  case "$TARGET_HOST" in
    opencode)
      if [ -f "$DEST/opencode.json" ]; then
        if verify_opencode_json "$DEST/opencode.json"; then
          printf '  [OK] opencode.json includes HARNESS.md and PROVIDERS.md\n'
        else
          printf '  [WARN] opencode.json is missing HARNESS.md or PROVIDERS.md in instructions; add ["%s/HARNESS.md", "%s/PROVIDERS.md"] to instructions in %s/opencode.json\n' "$DEST" "$DEST" "$DEST"
        fi
      else
        printf '  [WARN] opencode.json not found at %s/opencode.json; create it with {"instructions": ["%s/HARNESS.md", "%s/PROVIDERS.md"]} so OpenCode loads the harness\n' "$DEST" "$DEST" "$DEST"
      fi
      ;;
    codex)
      if [ ! -f "$DEST/AGENTS.md" ]; then
        printf '  [FAIL] required instruction file missing: AGENTS.md\n'
        v_errors=$((v_errors + 1))
      elif ! verify_combined_instructions "$DEST/AGENTS.md"; then
        printf '  [FAIL] instruction file missing harness or provider instructions: AGENTS.md\n'
        v_errors=$((v_errors + 1))
      else
        printf '  [OK] instruction wiring: AGENTS.md\n'
      fi
      ;;
    antigravity)
      for ag_rule in rules/HARNESS.md rules/PROVIDERS.md; do
        if [ ! -f "$DEST/$ag_rule" ]; then
          printf '  [FAIL] required instruction rule missing: %s\n' "$ag_rule"
          v_errors=$((v_errors + 1))
        elif [ "$(wc -c <"$DEST/$ag_rule")" -ge 24000 ]; then
          printf '  [FAIL] instruction rule exceeds 24000 bytes: %s\n' "$ag_rule"
          v_errors=$((v_errors + 1))
        elif ! verify_agy_rule "$DEST/$ag_rule"; then
          printf '  [FAIL] instruction rule missing trigger: always_on frontmatter: %s\n' "$ag_rule"
          v_errors=$((v_errors + 1))
        else
          printf '  [OK] instruction wiring: %s\n' "$ag_rule"
        fi
      done
      ;;
    claude)
      if [ ! -f "$DEST/CLAUDE.md" ]; then
        printf '  [FAIL] required instruction file missing: CLAUDE.md\n'
        v_errors=$((v_errors + 1))
      elif ! verify_combined_instructions "$DEST/CLAUDE.md"; then
        printf '  [FAIL] instruction file missing harness or provider instructions: CLAUDE.md\n'
        v_errors=$((v_errors + 1))
      else
        printf '  [OK] instruction wiring: CLAUDE.md\n'
      fi
      ;;
  esac
  if [ ! -d "$DEST/state" ]; then
    printf '  [FAIL] shared state directory missing: %s/state\n' "$DEST"
    v_errors=$((v_errors + 1))
  elif [ "$TARGET_HOST" != "opencode" ] && [ "$DEST" != "$SHARED_OC_CANON" ] &&
       { [ ! -d "$SHARED_STATE" ] || [ "$(canonical_dest "$DEST/state")" != "$(canonical_dest "$SHARED_STATE")" ]; }; then
    printf '  [FAIL] state directory does not resolve to shared state (%s): %s/state\n' "$SHARED_STATE" "$DEST"
    v_errors=$((v_errors + 1))
  elif [ -L "$DEST/state/quota-ledger.tsv" ]; then
    printf '  [FAIL] quota-ledger.tsv cannot be a symlink: %s\n' "$DEST/state/quota-ledger.tsv"
    v_errors=$((v_errors + 1))
  elif [ -e "$DEST/state/quota-ledger.tsv" ] && { [ ! -f "$DEST/state/quota-ledger.tsv" ] || [ ! -r "$DEST/state/quota-ledger.tsv" ]; }; then
    printf '  [FAIL] quota-ledger.tsv is not a readable regular file: %s/state/quota-ledger.tsv\n' "$DEST"
    v_errors=$((v_errors + 1))
  elif [ ! -w "$DEST/state" ]; then
    printf '  [FAIL] shared state directory is not writable for quota-ledger.tsv: %s/state\n' "$DEST"
    v_errors=$((v_errors + 1))
  else
    printf '  [OK] shared state: %s/state (quota-ledger.tsv accessible)\n' "$DEST"
  fi
  [ "$v_errors" -eq 0 ]
}

if [ "$verify_mode" -eq 1 ]; then
  if verify_target; then
    exit 0
  else
    exit 1
  fi
fi

LEGACY_AGY_DIR=""
LEGACY_AGY_MANIFEST=""
if [ "$TARGET_HOST" = "antigravity" ]; then
  LEGACY_AGY_DIR="$DEST/plugins/oneshot-harness"
  LEGACY_AGY_MANIFEST="$LEGACY_AGY_DIR/.harness-manifest"
fi
read_prev_binding "$DEST" "$TARGET_HOST"
use_profile_file=0
if [ "$profile_file_given" -eq 1 ]; then
  use_profile_file=1
elif [ "$profile_given" -eq 0 ]; then
  if [ "$prev_profile_file_present" -eq 1 ]; then
    use_profile_file=1
    profile_file_arg="$prev_profile_file"
  elif [ "$prev_profile_present" -eq 1 ]; then
    profile="$prev_profile"
  fi
fi

# Validate the binding before creating anything, including temporary files.
unknown_profile() {
  printf 'install.sh: unknown profile: %s (available: %s)\n' "$profile" "$(available_profiles)" >&2
  exit 2
}
if [ "$use_profile_file" -eq 1 ]; then
  case "$profile_file_arg" in
    *[[:cntrl:]]*)
      printf 'install.sh: invalid profile file path: %s\n' "$profile_file_arg" >&2
      exit 2
      ;;
  esac
  if [ ! -f "$profile_file_arg" ]; then
    printf 'install.sh: profile file not found: %s\n' "$profile_file_arg" >&2
    exit 2
  fi
  PROFILE_FILE="$(cd "$(dirname -- "$profile_file_arg")" && pwd -P)/$(basename -- "$profile_file_arg")"
  case "$PROFILE_FILE" in
    *[[:cntrl:]]*)
      printf 'install.sh: invalid profile file path: %s\n' "$PROFILE_FILE" >&2
      exit 2
      ;;
  esac
  PROFILE_LABEL="$PROFILE_FILE"
else
  case "$profile" in
    ''|[!a-z0-9]*|*[!a-z0-9-]*) unknown_profile ;;
  esac
  PROFILE_FILE="$SRC/providers/$profile.md"
  [ -f "$PROFILE_FILE" ] || unknown_profile
  PROFILE_LABEL="$profile"
fi
# Recognized required and advisory rows are validated; fenced examples are prose.
PROFILE_ROWS="$(validate_profile "$PROFILE_FILE" "$PROFILE_LABEL")" || exit 1

# Select by ladder order, even if the table rows were written out of order.
native_pin() {
  awk -F '|' -v seat="$1" '
    BEGIN { rank["primary"] = 1; rank["fallback"] = 2; rank["last-resort"] = 3 }
    $1 == seat && $3 == "opencode" {
      if (!best || rank[$2] < best) {
        best = rank[$2]
        pin = $4
        if ($5 ~ /^variant=/) pin = pin "#" substr($5, 9)
      }
    }
    END { if (best) print pin }
  ' <<<"$PROFILE_ROWS"
}

TMP_MANIFEST="$DEST/.harness-manifest.$$.tmp"
staged_profile=""
ledger_tmp=""
state_migrating=""
state_migrating_orig=""
rendered_files=()
owned_locks=()
cleanup() {
  local lk
  rm -f -- "$TMP_MANIFEST" ${pf_token_file:+"$pf_token_file"} ${sr_token_file:+"$sr_token_file"} ${staged_profile:+"$staged_profile"} ${ledger_tmp:+"$ledger_tmp"}
  if [ "${#rendered_files[@]}" -gt 0 ]; then
    rm -f -- "${rendered_files[@]}"
  fi
  if [ -n "$state_migrating" ] && [ -d "$state_migrating" ] && [ ! -L "$state_migrating" ]; then
    if [ -n "$state_migrating_orig" ] && [ ! -e "$state_migrating_orig" ] && [ ! -L "$state_migrating_orig" ]; then
      mv -- "$state_migrating" "$state_migrating_orig" 2>/dev/null || true
    elif [ -n "$state_migrating_orig" ] && [ -L "$state_migrating_orig" ] &&
         { [ -e "$state_migrating/quota-ledger.tsv" ] || [ -L "$state_migrating/quota-ledger.tsv" ]; }; then
      rm -f -- "$state_migrating_orig" 2>/dev/null || true
      mv -- "$state_migrating" "$state_migrating_orig" 2>/dev/null || true
    fi
  fi
  if [ "${#owned_locks[@]}" -gt 0 ]; then
    for lk in "${owned_locks[@]}"; do
      if [ -n "$lk" ] && [ -d "$lk" ] && [ ! -L "$lk" ]; then
        rmdir "$lk" 2>/dev/null || true
      fi
    done
  fi
  if [ -n "$state_migrating_orig" ] && [ ! -L "$state_migrating_orig" ] &&
     [ -d "$state_migrating_orig/quota-ledger.lock" ] && [ ! -L "$state_migrating_orig/quota-ledger.lock" ]; then
    rmdir "$state_migrating_orig/quota-ledger.lock" 2>/dev/null || true
  fi
  if [ -n "$state_migrating" ] && [ -d "$state_migrating" ] && [ ! -L "$state_migrating" ]; then
    if [ -d "$state_migrating/quota-ledger.lock" ] && [ ! -L "$state_migrating/quota-ledger.lock" ]; then
      rmdir "$state_migrating/quota-ledger.lock" 2>/dev/null || true
    fi
    rmdir "$state_migrating" 2>/dev/null || true
  fi
}
trap cleanup EXIT

lock_age_seconds() {
  local d="$1" mtime="" now
  now="$(date +%s)"
  mtime="$(stat -c %Y "$d" 2>/dev/null || stat -f %m "$d" 2>/dev/null || printf '%s' "$now")"
  case "${mtime#-}" in
    ''|*[!0-9]*) mtime="$now" ;;
  esac
  printf '%d' "$((now - mtime))"
}

check_lock_path_struct() {
  local lockpath="$1"
  local lk_entries=()
  if [ ! -e "$lockpath" ] && [ ! -L "$lockpath" ]; then
    return 0
  fi
  if [ -L "$lockpath" ] || [ ! -d "$lockpath" ]; then
    printf 'install.sh: ledger lock path is not a directory: %s\n' "$lockpath" >&2
    exit 1
  fi
  shopt -s nullglob dotglob
  lk_entries=("$lockpath"/*)
  shopt -u nullglob dotglob
  if [ "${#lk_entries[@]}" -gt 0 ]; then
    printf 'install.sh: ledger lock directory is not empty: %s\n' "$lockpath" >&2
    exit 1
  fi
}

check_lock_path_preflight() {
  local lockpath="$1" _w
  if [ ! -e "$lockpath" ] && [ ! -L "$lockpath" ]; then
    return 0
  fi
  check_lock_path_struct "$lockpath"
  if [ "$(lock_age_seconds "$lockpath")" -le 60 ]; then
    for _w in 1 2 3; do
      sleep 0.1
      if [ ! -e "$lockpath" ] && [ ! -L "$lockpath" ]; then
        return 0
      fi
    done
    check_lock_path_struct "$lockpath"
    if { [ -e "$lockpath" ] || [ -L "$lockpath" ]; } && [ "$(lock_age_seconds "$lockpath")" -le 60 ]; then
      printf 'install.sh: quota ledger lock is active: %s\n' "$lockpath" >&2
      exit 1
    fi
  fi
}

acquire_ledger_lock() {
  local lockdir="$1" acquired=0 _w
  if mkdir "$lockdir" 2>/dev/null; then
    acquired=1
  else
    check_lock_path_struct "$lockdir"
    if [ -d "$lockdir" ] && [ "$(lock_age_seconds "$lockdir")" -gt 60 ]; then
      if ! rmdir "$lockdir" 2>/dev/null; then
        if [ -e "$lockdir" ] || [ -L "$lockdir" ]; then
          printf 'install.sh: ledger lock directory is not empty: %s\n' "$lockdir" >&2
          exit 1
        fi
      fi
      if mkdir "$lockdir" 2>/dev/null; then
        acquired=1
      fi
    fi
    if [ "$acquired" -eq 0 ]; then
      for _w in 1 2 3 4 5; do
        sleep 0.1
        if mkdir "$lockdir" 2>/dev/null; then
          acquired=1
          break
        fi
        check_lock_path_struct "$lockdir"
      done
    fi
  fi
  if [ "$acquired" -eq 0 ]; then
    printf 'install.sh: quota ledger lock is active: %s\n' "$lockdir" >&2
    exit 1
  fi
  owned_locks+=("$lockdir")
}

release_ledger_lock() {
  local lockdir="$1" idx
  rmdir "$lockdir"
  if [ "${#owned_locks[@]}" -gt 0 ]; then
    for idx in "${!owned_locks[@]}"; do
      if [ "${owned_locks[$idx]}" = "$lockdir" ]; then
        owned_locks[$idx]=""
      fi
    done
  fi
}

if [ ! -d "$SRC/agents" ] || [ ! -d "$SRC/skills" ] || [ ! -f "$SRC/AGENTS.md" ] ||
   [ ! -f "$SRC/NOTICE" ] || [ ! -f "$SRC/LICENSE" ]; then
  printf 'install.sh: expected agents/, skills/, AGENTS.md, NOTICE, and LICENSE under %s\n' "$SRC" >&2
  exit 1
fi

staged_profile="$(mktemp "${TMPDIR:-/tmp}/harness-profile.XXXXXXXX")"
cp -p "$PROFILE_FILE" "$staged_profile"

srcs=()
rels=()
while IFS= read -r -d '' f; do
  srcs+=("$f")
  rels+=("${f#"$SRC"/}")
done < <(find "$SRC/agents" "$SRC/skills" -type f -print0)
srcs+=("$SRC/AGENTS.md")
rels+=("HARNESS.md")
srcs+=("$SRC/NOTICE")
rels+=("NOTICE")
srcs+=("$SRC/LICENSE")
rels+=("LICENSE")
srcs+=("$staged_profile")
rels+=("PROVIDERS.md")

if [ "$TARGET_HOST" = "codex" ]; then
  combined_doc="$(mktemp "${TMPDIR:-/tmp}/harness-codex-agents.XXXXXXXX")"
  chmod 0644 "$combined_doc"
  rendered_files+=("$combined_doc")
  { cat "$SRC/AGENTS.md"; printf '\n\n'; cat "$PROFILE_FILE"; } >"$combined_doc"
  if [ "$(wc -c <"$combined_doc")" -ge 32768 ]; then
    if [ "$preflight_only" -eq 0 ]; then
      printf 'note: compacting %s profile prose to fit 32768-byte host instruction limit\n' "$TARGET_HOST"
    fi
    { cat "$SRC/AGENTS.md"; printf '\n\n'; awk '/^[[:space:]]*```/ { f=!f; next } !f && (/^#/ || /^[[:space:]]*\|/)' "$PROFILE_FILE"; } >"$combined_doc"
    if [ "$(wc -c <"$combined_doc")" -ge 32768 ]; then
      printf 'install.sh: %s combined instruction file exceeds 32768 bytes\n' "$TARGET_HOST" >&2
      exit 2
    fi
  fi
  srcs+=("$combined_doc")
  rels+=("AGENTS.md")
elif [ "$TARGET_HOST" = "claude" ]; then
  combined_doc="$(mktemp "${TMPDIR:-/tmp}/harness-claude-md.XXXXXXXX")"
  chmod 0644 "$combined_doc"
  rendered_files+=("$combined_doc")
  { cat "$SRC/AGENTS.md"; printf '\n\n'; cat "$PROFILE_FILE"; } >"$combined_doc"
  if [ "$(wc -c <"$combined_doc")" -ge 32768 ]; then
    if [ "$preflight_only" -eq 0 ]; then
      printf 'note: compacting %s profile prose to fit 32768-byte host instruction limit\n' "$TARGET_HOST"
    fi
    { cat "$SRC/AGENTS.md"; printf '\n\n'; awk '/^[[:space:]]*```/ { f=!f; next } !f && (/^#/ || /^[[:space:]]*\|/)' "$PROFILE_FILE"; } >"$combined_doc"
    if [ "$(wc -c <"$combined_doc")" -ge 32768 ]; then
      printf 'install.sh: %s combined instruction file exceeds 32768 bytes\n' "$TARGET_HOST" >&2
      exit 2
    fi
  fi
  srcs+=("$combined_doc")
  rels+=("CLAUDE.md")
elif [ "$TARGET_HOST" = "antigravity" ]; then
  rule_harness="$(mktemp "${TMPDIR:-/tmp}/harness-agy-rule-h.XXXXXXXX")"
  chmod 0644 "$rule_harness"
  rendered_files+=("$rule_harness")
  { printf -- '---\ntrigger: always_on\n---\n\n'; cat "$SRC/AGENTS.md"; } >"$rule_harness"
  srcs+=("$rule_harness")
  rels+=("rules/HARNESS.md")

  rule_providers="$(mktemp "${TMPDIR:-/tmp}/harness-agy-rule-p.XXXXXXXX")"
  chmod 0644 "$rule_providers"
  rendered_files+=("$rule_providers")
  { printf -- '---\ntrigger: always_on\n---\n\n'; cat "$PROFILE_FILE"; } >"$rule_providers"
  if [ "$(wc -c <"$rule_harness")" -ge 24000 ] || [ "$(wc -c <"$rule_providers")" -ge 24000 ]; then
    printf 'install.sh: antigravity rule file exceeds 24000 bytes\n' >&2
    exit 2
  fi
  srcs+=("$rule_providers")
  rels+=("rules/PROVIDERS.md")

  srcs+=("$SRC/AGENTS.md")
  rels+=("skills/_harness/HARNESS.md")
  srcs+=("$staged_profile")
  rels+=("skills/_harness/PROVIDERS.md")
  srcs+=("$SRC/NOTICE")
  rels+=("skills/_harness/NOTICE")
  srcs+=("$SRC/LICENSE")
  rels+=("skills/_harness/LICENSE")
fi

# Render every agent before any destination mutation, including --force repairs.
for i in "${!rels[@]}"; do
  case "${rels[$i]}" in
    agents/*.md)
      seat="${rels[$i]#agents/}"
      seat="${seat%.md}"
      if [ "$TARGET_HOST" = "opencode" ]; then
        pin="$(native_pin "$seat")"
        if [ -z "$pin" ] && [ "$preflight_only" -eq 0 ]; then
          printf 'note: %s has no opencode rung; dispatch it through delegate_task only\n' "$seat"
        fi
        rendered="$(mktemp "${TMPDIR:-/tmp}/harness-agent.XXXXXXXX")"
        rendered_files+=("$rendered")
        cp -p "${srcs[$i]}" "$rendered"
        if ! NATIVE_PIN="$pin" awk '
          BEGIN { pin = ENVIRON["NATIVE_PIN"] }
          NR == 1 { frontmatter = ($0 == "---") }
          NR > 1 && frontmatter && $0 == "---" { frontmatter = 0 }
          { print }
          frontmatter && !inserted && /^mode: subagent$/ && pin != "" {
            print "model: " pin
            inserted = 1
          }
          END { if (pin != "" && !inserted) exit 1 }
        ' "${srcs[$i]}" >"$rendered"; then
          printf 'install.sh: cannot insert native pin: %s\n' "$seat" >&2
          exit 1
        fi
        srcs[$i]="$rendered"
      elif [ "$TARGET_HOST" = "antigravity" ]; then
        is_readonly=0
        case "$seat" in
          scout|reviewer-a|reviewer-b|reviewer-c|reviewer-esc)
            agy_tools="[read_file, run_command]"
            is_readonly=1
            ;;
          patch)
            agy_tools="[read_file, edit_file, write_file]"
            ;;
          implementer|implementer-deep|tester)
            agy_tools="[read_file, edit_file, write_file, run_command, manage_task, search_web]"
            ;;
          *)
            agy_tools="[read_file]"
            ;;
        esac
        rendered="$(mktemp "${TMPDIR:-/tmp}/harness-agent.XXXXXXXX")"
        rendered_files+=("$rendered")
        cp -p "${srcs[$i]}" "$rendered"
        SEAT_NAME="$seat" AGY_TOOLS="$agy_tools" IS_READONLY="$is_readonly" awk '
          NR == 1 && $0 == "---" { in_fm = 1; in_perm = 0; perm_block = ""; next }
          in_fm && /^description:[[:space:]]*/ {
            desc = $0
            sub(/^description:[[:space:]]*/, "", desc)
            in_perm = 0
            next
          }
          in_fm && /^permissions:[[:space:]]*$/ {
            in_perm = 1
            perm_block = $0 "\n"
            next
          }
          in_fm && $0 == "---" {
            in_fm = 0
            in_perm = 0
            print "---"
            print "name: " ENVIRON["SEAT_NAME"]
            print "description: " desc
            print "subagent: true"
            print "mainAgent: false"
            print "tools: " ENVIRON["AGY_TOOLS"]
            print "---"
            if (perm_block != "") {
              print ""
              print "## Permissions policy (self-enforced)"
              print ""
              if (ENVIRON["IS_READONLY"] == "1") {
                print "Antigravity cannot narrow run_command in frontmatter; this seat is strictly read-only and MUST only run read-only inspection commands permitted by the policy below."
                print ""
              }
              print "```yaml"
              printf "%s", perm_block
              print "```"
            }
            next
          }
          in_fm {
            if (in_perm) perm_block = perm_block $0 "\n"
            next
          }
          { print }
        ' "${srcs[$i]}" >"$rendered"
        srcs[$i]="$rendered"
      elif [ "$TARGET_HOST" = "claude" ]; then
        case "$seat" in
          scout|reviewer-a|reviewer-b|reviewer-c|reviewer-esc)
            cc_tools="Read, Glob, Grep, Bash"
            ;;
          patch)
            cc_tools="Read, Edit, Write, Glob, Grep"
            ;;
          implementer|implementer-deep|tester)
            cc_tools="Read, Edit, Write, Glob, Grep, Bash"
            ;;
          *)
            cc_tools="Read, Glob, Grep"
            ;;
        esac
        rendered="$(mktemp "${TMPDIR:-/tmp}/harness-agent.XXXXXXXX")"
        rendered_files+=("$rendered")
        cp -p "${srcs[$i]}" "$rendered"
        SEAT_NAME="$seat" CC_TOOLS="$cc_tools" awk '
          NR == 1 && $0 == "---" { in_fm = 1; in_perm = 0; perm_block = ""; next }
          in_fm && /^description:[[:space:]]*/ {
            desc = $0
            sub(/^description:[[:space:]]*/, "", desc)
            in_perm = 0
            next
          }
          in_fm && /^permissions:[[:space:]]*$/ {
            in_perm = 1
            perm_block = $0 "\n"
            next
          }
          in_fm && $0 == "---" {
            in_fm = 0
            in_perm = 0
            print "---"
            print "name: " ENVIRON["SEAT_NAME"]
            print "description: " desc
            print "tools: " ENVIRON["CC_TOOLS"]
            print "---"
            if (perm_block != "") {
              print ""
              print "## Permissions policy (self-enforced)"
              print ""
              print "```yaml"
              printf "%s", perm_block
              print "```"
            }
            next
          }
          in_fm {
            if (in_perm) perm_block = perm_block $0 "\n"
            next
          }
          { print }
        ' "${srcs[$i]}" >"$rendered"
        srcs[$i]="$rendered"
      fi
      ;;
  esac
done

if [ "$TARGET_HOST" = "antigravity" ]; then
  orig_count="${#rels[@]}"
  for ((i = 0; i < orig_count; i++)); do
    case "${rels[$i]}" in
      skills/_harness/SKILL.md|skills/_harness/*/SKILL.md)
        printf 'install.sh: unexpected SKILL.md under skills/_harness: %s\n' "${rels[$i]}" >&2
        exit 1
        ;;
      agents/*.md)
        srcs+=("${srcs[$i]}")
        rels+=("skills/_harness/${rels[$i]}")
        ;;
    esac
  done
fi

# Preflight: collect every target that already exists, before any mkdir or copy.
collisions=()
for i in "${!rels[@]}"; do
  target="$DEST/${rels[$i]}"
  if [ -e "$target" ] || [ -L "$target" ]; then
    collisions+=("$target")
  fi
done

# Preflight: walk every parent component of each target between $DEST_CANON and the
# file. mkdir -p follows a symlinked parent under $DEST, so a copy could land
# outside $DEST. Refuse (or repair under --force) before anything is copied.
# A parent component that exists as a regular file (not a directory, not a
# symlink) can never contain a target; refuse before anything is copied.
parent_links=()
parent_blocks=()
for i in "${!rels[@]}"; do
  target="$DEST/${rels[$i]}"
  parent="$(dirname "$target")"
  walk=0
  while [ "$parent" != "$DEST_CANON" ]; do
    walk=$((walk + 1))
    if [ "$walk" -gt 64 ]; then
      printf 'install.sh: parent walk did not converge: %s\n' "$parent" >&2
      exit 1
    fi
    case "$parent" in
      "$DEST_CANON"/*) ;;
      *) break ;;
    esac
    if [ -L "$parent" ]; then
      dup=0
      if [ "${#parent_links[@]}" -gt 0 ]; then
        for p in "${parent_links[@]}"; do
          if [ "$p" = "$parent" ]; then
            dup=1
            break
          fi
        done
      fi
      if [ "$dup" -eq 0 ]; then
        parent_links+=("$parent")
      fi
    elif [ -e "$parent" ] && [ ! -d "$parent" ]; then
      dup=0
      if [ "${#parent_blocks[@]}" -gt 0 ]; then
        for p in "${parent_blocks[@]}"; do
          if [ "$p" = "$parent" ]; then
            dup=1
            break
          fi
        done
      fi
      if [ "$dup" -eq 0 ]; then
        parent_blocks+=("$parent")
      fi
    fi
    parent="$(dirname "$parent")"
  done
done

if [ "$TARGET_HOST" = "opencode" ] || [ "$DEST" = "$SHARED_OC_CANON" ]; then
  if [ -L "$DEST/state" ]; then
    parent_links+=("$DEST/state")
  elif [ -e "$DEST/state" ] && [ ! -d "$DEST/state" ]; then
    parent_blocks+=("$DEST/state")
  fi
else
  if [ -L "$SHARED_STATE" ] || { [ -e "$SHARED_STATE" ] && [ ! -d "$SHARED_STATE" ]; }; then
    parent_blocks+=("$SHARED_STATE")
  elif [ -d "$SHARED_STATE" ]; then
    if [ -L "$SHARED_STATE/quota-ledger.tsv" ] || { [ -e "$SHARED_STATE/quota-ledger.tsv" ] && [ ! -f "$SHARED_STATE/quota-ledger.tsv" ]; }; then
      printf 'install.sh: ledger path is not a regular file: %s\n' "$SHARED_STATE/quota-ledger.tsv" >&2
      exit 1
    fi
    check_lock_path_struct "$SHARED_STATE/quota-ledger.lock"
  fi
  if [ -L "$DEST/state" ]; then
    if [ "$(readlink "$DEST/state")" != "$SHARED_STATE" ] && [ "$(canonical_dest "$DEST/state")" != "$SHARED_STATE" ]; then
      collisions+=("$DEST/state")
    fi
  elif [ -d "$DEST/state" ]; then
    shopt -s nullglob dotglob
    state_entries=("$DEST/state"/*)
    shopt -u nullglob dotglob
    if [ "${#state_entries[@]}" -gt 0 ]; then
      for se in "${state_entries[@]}"; do
        se_base="$(basename -- "$se")"
        case "$se_base" in
          quota-ledger.tsv)
            if [ -L "$se" ] || [ ! -f "$se" ]; then
              printf 'install.sh: ledger path is not a regular file: %s\n' "$se" >&2
              exit 1
            fi
            ;;
          quota-ledger.lock)
            check_lock_path_struct "$se"
            ;;
          *)
            printf 'install.sh: refusing to replace state directory containing non-ledger files: %s\n' "$DEST/state" >&2
            exit 1
            ;;
        esac
      done
      if [ "$force" -eq 0 ]; then
        collisions+=("$DEST/state")
      fi
    fi
  elif [ -e "$DEST/state" ]; then
    parent_blocks+=("$DEST/state")
  fi
fi

if [ "$TARGET_HOST" = "antigravity" ] && [ "$prune" -eq 1 ]; then
  if [ -L "$DEST/plugins" ]; then
    printf 'install.sh: refusing to prune through symlink: %s\n' "$DEST/plugins" >&2
    exit 1
  fi
  if [ -L "$LEGACY_AGY_DIR" ]; then
    printf 'install.sh: refusing to prune through symlink: %s\n' "$LEGACY_AGY_DIR" >&2
    exit 1
  fi
  if [ -d "$LEGACY_AGY_DIR" ]; then
    if [ -L "$LEGACY_AGY_MANIFEST" ] || { [ -e "$LEGACY_AGY_MANIFEST" ] && [ ! -f "$LEGACY_AGY_MANIFEST" ]; }; then
      printf 'install.sh: manifest path is not a regular file: %s\n' "$LEGACY_AGY_MANIFEST" >&2
      exit 1
    fi
    if [ -f "$LEGACY_AGY_MANIFEST" ]; then
      if [ -d "$LEGACY_AGY_DIR/state" ] && [ ! -L "$LEGACY_AGY_DIR/state" ]; then
        if [ -d "$SHARED_STATE" ] && [ ! -L "$SHARED_STATE" ]; then
          if [ -L "$SHARED_STATE/quota-ledger.tsv" ] || { [ -e "$SHARED_STATE/quota-ledger.tsv" ] && [ ! -f "$SHARED_STATE/quota-ledger.tsv" ]; }; then
            printf 'install.sh: ledger path is not a regular file: %s\n' "$SHARED_STATE/quota-ledger.tsv" >&2
            exit 1
          fi
          check_lock_path_struct "$SHARED_STATE/quota-ledger.lock"
        fi
        shopt -s nullglob dotglob
        legacy_state_entries=("$LEGACY_AGY_DIR/state"/*)
        shopt -u nullglob dotglob
        if [ "${#legacy_state_entries[@]}" -gt 0 ]; then
          for se in "${legacy_state_entries[@]}"; do
            se_base="$(basename -- "$se")"
            case "$se_base" in
              quota-ledger.tsv)
                if [ -L "$se" ] || [ ! -f "$se" ]; then
                  printf 'install.sh: ledger path is not a regular file: %s\n' "$se" >&2
                  exit 1
                fi
                ;;
              quota-ledger.lock)
                check_lock_path_struct "$se"
                ;;
              *)
                printf 'install.sh: refusing to replace state directory containing non-ledger files: %s\n' "$LEGACY_AGY_DIR/state" >&2
                exit 1
                ;;
            esac
          done
        fi
      elif [ ! -L "$LEGACY_AGY_DIR/state" ] && [ -e "$LEGACY_AGY_DIR/state" ]; then
        printf 'install.sh: parent path is not a directory: %s\n' "$LEGACY_AGY_DIR/state" >&2
        exit 1
      fi
    fi
  fi
fi

if [ "${#parent_blocks[@]}" -gt 0 ]; then
  for pb in "${parent_blocks[@]}"; do
    printf 'install.sh: parent path is not a directory: %s\n' "$pb" >&2
  done
  exit 1
fi

if [ "${#parent_links[@]}" -gt 0 ] && [ "$force" -eq 0 ]; then
  for pl in "${parent_links[@]}"; do
    printf 'install.sh: parent symlink under destination: %s\n' "$pl" >&2
  done
  exit 1
fi

if [ "${#collisions[@]}" -gt 0 ] && [ "$force" -eq 0 ]; then
  for c in "${collisions[@]}"; do
    printf 'collision: %s\n' "$c"
  done
  printf 'refusing to overwrite; rerun with --force\n'
  exit 1
fi

# Preflight: a target blocked by a directory can never be replaced by a file.
# Without --force this already aborts as a collision above; with --force
# refuse before anything is copied, leaving the manifest intact.
dir_targets=()
for i in "${!rels[@]}"; do
  target="$DEST/${rels[$i]}"
  if [ -d "$target" ] && [ ! -L "$target" ]; then
    dir_targets+=("$target")
  fi
done
if [ "${#dir_targets[@]}" -gt 0 ] && [ "$force" -eq 1 ]; then
  for dt in "${dir_targets[@]}"; do
    printf 'install.sh: directory at target cannot be replaced: %s\n' "$dt" >&2
  done
  exit 1
fi

if [ "$TARGET_HOST" != "opencode" ] && [ "$DEST" != "$SHARED_OC_CANON" ] &&
   [ -d "$DEST/state" ] && [ ! -L "$DEST/state" ]; then
  check_lock_path_preflight "$DEST/state/quota-ledger.lock"
  check_lock_path_preflight "$SHARED_STATE/quota-ledger.lock"
fi

if [ "$TARGET_HOST" = "antigravity" ] && [ "$prune" -eq 1 ] &&
   [ ! -L "$DEST/plugins" ] && [ ! -L "$LEGACY_AGY_DIR" ] && [ -d "$LEGACY_AGY_DIR" ] &&
   [ ! -L "$LEGACY_AGY_MANIFEST" ] && [ -f "$LEGACY_AGY_MANIFEST" ] &&
   [ -d "$LEGACY_AGY_DIR/state" ] && [ ! -L "$LEGACY_AGY_DIR/state" ]; then
  if [ "$LEGACY_AGY_DIR/state" != "$SHARED_STATE" ]; then
    check_lock_path_preflight "$LEGACY_AGY_DIR/state/quota-ledger.lock"
  fi
  check_lock_path_preflight "$SHARED_STATE/quota-ledger.lock"
fi

if [ "$preflight_only" -eq 1 ]; then
  exit 0
fi

# normalize_rel <entry>: canonical relative form used for both the ownership
# comparison and the unsafe-entry check. Strips a leading "./", collapses
# repeated slashes, and strips trailing slashes so that a manifest entry such
# as "./skills/oneshot/SKILL.md" is recognised as the file this run writes.
normalize_rel() {
  local r="$1"
  while case "$r" in ./*) true ;; *) false ;; esac; do
    r="${r#./}"
  done
  while case "$r" in *//*) true ;; *) false ;; esac; do
    r="${r//\/\//\/}"
  done
  while case "$r" in */) true ;; *) false ;; esac; do
    r="${r%/}"
  done
  printf '%s' "$r"
}

# owned <rel>: true when this run installs <rel>. Comparison uses normalized
# relative paths (./ and // stripped) and exact case matching so case-variant
# stale files are still pruned on case-sensitive filesystems.
norm_rels=()
for r in "${rels[@]}"; do
  norm_rels+=("$(normalize_rel "$r")")
done
owned() {
  local want r
  want="$(normalize_rel "$1")"
  for r in "${norm_rels[@]}"; do
    if [ "$r" = "$want" ]; then
      return 0
    fi
  done
  return 1
}

merge_ledgers() {
  awk -F'\t' '
    BEGIN { n = 0; want_header = 0 }
    $0 == "" { next }
    $1 == "pool" && $2 == "provider" && $3 == "exhausted_at" {
      want_header = 1
      next
    }
    $1 == "pool" && $2 == "window_start" { next }
    NF >= 6 && $1 != "" {
      k = $1
      e = $3 ""
      r = $4 ""
      if (!(k in seen)) {
        order[++n] = k
        seen[k] = 1
        best_r[k] = r
        best_e[k] = e
        best_line[k] = $0
      } else if (r > best_r[k] || (r == best_r[k] && e > best_e[k])) {
        best_r[k] = r
        best_e[k] = e
        best_line[k] = $0
      }
    }
    END {
      if (want_header) {
        print "pool\tprovider\texhausted_at\tretry_after\tsource_role\tnote"
      }
      for (i = 1; i <= n; i++) {
        print best_line[order[i]]
      }
    }
  ' "$@"
}

prune_manifest_entries() {
  local manifest_path="$1" base_dir="$2" check_owned="$3"
  local rel target prune_parent prune_unsafe
  while IFS= read -r rel || [ -n "$rel" ]; do
    [ -n "$rel" ] || continue
    case "$rel" in
      '#'*) continue ;;
    esac
    rel="$(normalize_rel "$rel")"
    [ -n "$rel" ] || continue
    case "$rel" in
      /*|..|../*|*/..|*/../*)
        printf 'install.sh: ignoring unsafe manifest entry: %s\n' "$rel" >&2
        continue
        ;;
    esac
    case "$rel" in
      state|state/*) continue ;;
    esac
    if [ "$check_owned" -eq 1 ] && owned "$rel"; then
      continue
    fi
    target="$base_dir/$rel"
    # Prune confinement: refuse to unlink through a symlinked parent, which
    # would delete a file outside $base_dir. Skip the entry instead.
    prune_parent="$(dirname "$target")"
    prune_unsafe=""
    while [ "$prune_parent" != "$base_dir" ]; do
      case "$prune_parent" in
        "$base_dir"/*) ;;
        *) prune_unsafe="$prune_parent"; break ;;
      esac
      if [ -L "$prune_parent" ]; then
        prune_unsafe="$prune_parent"
        break
      fi
      prune_parent="$(dirname "$prune_parent")"
    done
    if [ -n "$prune_unsafe" ]; then
      printf 'install.sh: refusing to prune through symlink: %s\n' "$target" >&2
      continue
    fi
    if [ -e "$target" ] || [ -L "$target" ]; then
      if [ ! -f "$target" ] && [ ! -L "$target" ]; then
        printf 'install.sh: skipping non-file prune target: %s\n' "$target" >&2
        continue
      fi
      rm -f -- "$target"
      pruned=$((pruned + 1))
    fi
  done <"$manifest_path"
}

installed=0
if [ "${#parent_links[@]}" -gt 0 ]; then
  # Repair shallowest-first: discovery order can list a nested parent before
  # its outer parent, and repairing the inner path first would act through
  # the outer symlink onto the outside tree. Sorting by depth ascending
  # repairs each outer parent first; the inner check then re-tests the
  # repaired tree and skips paths that no longer resolve to a symlink.
  sorted_parents="$(printf '%s\n' "${parent_links[@]}" | awk -F/ '{ print NF " " $0 }' | sort -n | cut -d' ' -f2-)"
  while IFS= read -r pl || [ -n "$pl" ]; do
    [ -n "$pl" ] || continue
    if [ -L "$pl" ]; then
      rm -f -- "$pl"
      mkdir -p "$pl"
    fi
  done <<<"$sorted_parents"
fi
mkdir -p "$DEST"
if [ "$TARGET_HOST" = "opencode" ] || [ "$DEST" = "$SHARED_OC_CANON" ]; then
  mkdir -p "$DEST/state"
else
  mkdir -p "$SHARED_STATE"
  if [ -d "$DEST/state" ] && [ ! -L "$DEST/state" ]; then
    acquire_ledger_lock "$SHARED_STATE/quota-ledger.lock"
    acquire_ledger_lock "$DEST/state/quota-ledger.lock"
    migrating_dir="$DEST/.state-migrating.$$"
    if [ -e "$migrating_dir" ] || [ -L "$migrating_dir" ]; then
      printf 'install.sh: migration staging path already exists: %s\n' "$migrating_dir" >&2
      exit 1
    fi
    state_migrating="$migrating_dir"
    state_migrating_orig="$DEST/state"
    mv -- "$DEST/state" "$state_migrating"
    if [ "${#owned_locks[@]}" -gt 0 ]; then
      for lk_idx in "${!owned_locks[@]}"; do
        if [ "${owned_locks[$lk_idx]}" = "$DEST/state/quota-ledger.lock" ]; then
          owned_locks[$lk_idx]="$state_migrating/quota-ledger.lock"
        fi
      done
    fi
    ln -snf "$SHARED_STATE" "$DEST/state"
    if [ -L "$state_migrating/quota-ledger.tsv" ] ||
       { [ -e "$state_migrating/quota-ledger.tsv" ] && [ ! -f "$state_migrating/quota-ledger.tsv" ]; }; then
      printf 'install.sh: ledger path is not a regular file: %s\n' "$DEST/state/quota-ledger.tsv" >&2
      exit 1
    fi
    if [ -f "$state_migrating/quota-ledger.tsv" ]; then
      merge_inputs=()
      if [ -f "$SHARED_STATE/quota-ledger.tsv" ]; then
        merge_inputs+=("$SHARED_STATE/quota-ledger.tsv")
      fi
      merge_inputs+=("$state_migrating/quota-ledger.tsv")
      ledger_tmp="$SHARED_STATE/.quota-ledger.$$.tmp"
      rm -f -- "$ledger_tmp"
      merge_ledgers "${merge_inputs[@]}" >"$ledger_tmp"
      chmod 0644 "$ledger_tmp"
      mv -f -- "$ledger_tmp" "$SHARED_STATE/quota-ledger.tsv"
      ledger_tmp=""
      rm -f -- "$state_migrating/quota-ledger.tsv"
    fi
    release_ledger_lock "$state_migrating/quota-ledger.lock"
    rmdir "$state_migrating"
    state_migrating=""
    state_migrating_orig=""
    release_ledger_lock "$SHARED_STATE/quota-ledger.lock"
  elif [ -L "$DEST/state" ]; then
    if [ "$(readlink "$DEST/state")" != "$SHARED_STATE" ]; then
      rm -f -- "$DEST/state"
      ln -snf "$SHARED_STATE" "$DEST/state"
    fi
  else
    ln -snf "$SHARED_STATE" "$DEST/state"
  fi
fi
for i in "${!rels[@]}"; do
  target="$DEST/${rels[$i]}"
  mkdir -p "$(dirname "$target")"
  # cp -p follows a destination symlink and would write outside DEST; unlink first.
  if [ -e "$target" ] || [ -L "$target" ]; then
    rm -f -- "$target"
  fi
  cp -p "${srcs[$i]}" "$target"
  installed=$((installed + 1))
done

if harness_sha="$(git -C "$SRC" rev-parse --short HEAD 2>/dev/null)"; then
  :
else
  harness_sha="unknown"
fi
prev_sha=""
prev_manifest_present=0
if [ -n "$PREV_MANIFEST_SOURCE" ] && [ -f "$PREV_MANIFEST_SOURCE" ]; then
  prev_manifest_present=1
  while IFS= read -r mline || [ -n "$mline" ]; do
    case "$mline" in
      '# harness '*) prev_sha="${mline#'# harness '}"; break ;;
    esac
  done <"$PREV_MANIFEST_SOURCE"
  if [ -z "$prev_sha" ]; then
    prev_sha="unknown"
  fi
fi

if [ "$prune" -eq 1 ]; then
  had_any_manifest=0
  if [ -f "$MANIFEST" ]; then
    had_any_manifest=1
  elif [ "$TARGET_HOST" = "antigravity" ] &&
       [ ! -L "$DEST/plugins" ] && [ ! -L "$LEGACY_AGY_DIR" ] && [ -d "$LEGACY_AGY_DIR" ] &&
       [ ! -L "$LEGACY_AGY_MANIFEST" ] && [ -f "$LEGACY_AGY_MANIFEST" ]; then
    had_any_manifest=1
  fi
  if [ "$had_any_manifest" -eq 0 ]; then
    printf 'no previous manifest; prune skipped\n'
  else
    pruned=0
    if [ -f "$MANIFEST" ]; then
      prune_manifest_entries "$MANIFEST" "$DEST" 1
    fi
    if [ "$TARGET_HOST" = "antigravity" ] &&
       [ ! -L "$DEST/plugins" ] && [ ! -L "$LEGACY_AGY_DIR" ] && [ -d "$LEGACY_AGY_DIR" ] &&
       [ ! -L "$LEGACY_AGY_MANIFEST" ] && [ -f "$LEGACY_AGY_MANIFEST" ]; then
      if [ -L "$LEGACY_AGY_DIR/state" ]; then
        rm -f -- "$LEGACY_AGY_DIR/state"
      elif [ -d "$LEGACY_AGY_DIR/state" ] && [ "$LEGACY_AGY_DIR/state" != "$SHARED_STATE" ]; then
        acquire_ledger_lock "$SHARED_STATE/quota-ledger.lock"
        acquire_ledger_lock "$LEGACY_AGY_DIR/state/quota-ledger.lock"
        if [ -L "$LEGACY_AGY_DIR/state/quota-ledger.tsv" ] ||
           { [ -e "$LEGACY_AGY_DIR/state/quota-ledger.tsv" ] && [ ! -f "$LEGACY_AGY_DIR/state/quota-ledger.tsv" ]; }; then
          printf 'install.sh: ledger path is not a regular file: %s\n' "$LEGACY_AGY_DIR/state/quota-ledger.tsv" >&2
          exit 1
        fi
        if [ -f "$LEGACY_AGY_DIR/state/quota-ledger.tsv" ]; then
          merge_inputs=()
          if [ -f "$SHARED_STATE/quota-ledger.tsv" ]; then
            merge_inputs+=("$SHARED_STATE/quota-ledger.tsv")
          fi
          merge_inputs+=("$LEGACY_AGY_DIR/state/quota-ledger.tsv")
          ledger_tmp="$SHARED_STATE/.quota-ledger.$$.tmp"
          rm -f -- "$ledger_tmp"
          merge_ledgers "${merge_inputs[@]}" >"$ledger_tmp"
          chmod 0644 "$ledger_tmp"
          mv -f -- "$ledger_tmp" "$SHARED_STATE/quota-ledger.tsv"
          ledger_tmp=""
          rm -f -- "$LEGACY_AGY_DIR/state/quota-ledger.tsv"
        fi
        release_ledger_lock "$LEGACY_AGY_DIR/state/quota-ledger.lock"
        release_ledger_lock "$SHARED_STATE/quota-ledger.lock"
        rmdir "$LEGACY_AGY_DIR/state" 2>/dev/null || true
      fi
      prune_manifest_entries "$LEGACY_AGY_MANIFEST" "$LEGACY_AGY_DIR" 0
      rm -f -- "$LEGACY_AGY_MANIFEST"
      find -P "$LEGACY_AGY_DIR" -depth -type d -exec rmdir {} \; 2>/dev/null || true
      rmdir "$DEST/plugins" 2>/dev/null || true
    fi
    printf 'pruned %d stale file(s)\n' "$pruned"
  fi
fi

: >"$TMP_MANIFEST"
printf '# harness %s\n' "$harness_sha" >>"$TMP_MANIFEST"
if [ "$use_profile_file" -eq 1 ]; then
  printf '# profile-file %s\n' "$PROFILE_FILE" >>"$TMP_MANIFEST"
else
  printf '# profile %s\n' "$profile" >>"$TMP_MANIFEST"
fi
for rel in "${rels[@]}"; do
  printf '%s\n' "$rel" >>"$TMP_MANIFEST"
done
mv -f -- "$TMP_MANIFEST" "$MANIFEST"

if [ "$prev_manifest_present" -eq 1 ] && [ "$prev_sha" != "$harness_sha" ]; then
  printf 'harness updated: %s -> %s\n' "$prev_sha" "$harness_sha"
fi

if [ "$profile_given" -eq 0 ] && [ "$profile_file_given" -eq 0 ] && [ "$prev_profile_legacy" -eq 1 ]; then
  printf 'profile: opencode-go (previous install predates profiles)\n'
fi

prev_binding="${prev_profile:-$prev_profile_file}"
if [ "$use_profile_file" -eq 1 ]; then
  cur_binding="$PROFILE_FILE"
else
  cur_binding="$profile"
fi
if { [ "$profile_given" -eq 1 ] || [ "$profile_file_given" -eq 1 ]; } &&
   [ -n "$prev_binding" ] && [ "$prev_binding" != "$cur_binding" ]; then
  printf 'profile changed: %s -> %s\n' "$prev_binding" "$cur_binding"
fi

printf 'installed %d files into %s (harness instructions at %s)\n' "$installed" "$DEST" "$DEST/HARNESS.md"
if [ "$target_given" -eq 0 ] && { { [ -n "${T3_USERDATA_DIR:-}" ] && [ -d "$T3_USERDATA_DIR" ]; } || [ -d "${HOME:-}/.t3/userdata" ]; }; then
  printf "tip: T3 Code detected; pass '--target all' to install across all T3-connected providers (Antigravity, Codex, OpenCode, Claude).\n"
fi
