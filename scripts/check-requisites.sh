#!/usr/bin/env bash

# Check every prerequisite this sandbox needs, and install whatever is missing.
#   ./scripts/check-requisites.sh           check, then install what is missing
#   ./scripts/check-requisites.sh --check    report only, change nothing
#
# Two tiers of dependency, and they are not interchangeable:
#   system   docker, mise      installed once per machine, via Homebrew
#   project  kind, kubectl…    installed by mise, pinned in ./mise.toml

# The project tool list is read from ./requisites.txt — edit that, not this.
#
# Note we test whether a tool RUNS, not whether it is on PATH. mise puts shims
# on PATH that exist even when no version is selected, so `command -v kind` can
# succeed while `kind` still fails with "No version is set for shim".

set -euo pipefail

# Written for macOS's bash 3.2 — no associative arrays, no `mapfile`.

# ---------------------------------------------------------------- config ----

CHECK_ONLY=0
[ "${1:-}" = "--check" ] && CHECK_ONLY=1

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$REPO_ROOT"   # so `mise use` writes to this project's mise.toml

# The tool list lives in requisites.txt, not in here — add a tool by editing
# that file. Format is "<name> <version>", # comments and blanks ignored.
# The trailing per-line comment falls into $_rest and is discarded.
REQUISITES="$REPO_ROOT/requisites.txt"
MISE_TOOLS=""
if [ -f "$REQUISITES" ]; then
  while read -r name version _rest; do
    case "$name" in ''|'#'*) continue ;; esac
    [ -z "$version" ] && continue
    MISE_TOOLS="$MISE_TOOLS $name:$version"
  done < "$REQUISITES"
fi

# Fallback so the script still works if requisites.txt is missing or empty.
# The versions here are only used when a tool is not already pinned in
# mise.toml — an existing pin always wins.
if [ -z "$MISE_TOOLS" ]; then
  MISE_TOOLS="kind:0.32.0 kubectl:1.36.4 helm:4.2.4 k9s:0.51.0 stern:1.34.0"
fi

# ---------------------------------------------------------------- output ----

if [ -t 1 ]; then
  R=$'\033[31m'; G=$'\033[32m'; Y=$'\033[33m'; B=$'\033[1m'; Z=$'\033[0m'
else
  R=''; G=''; Y=''; B=''; Z=''
fi

ok()   { printf '  %s✓%s %s\n'  "$G" "$Z" "$*"; }
bad()  { printf '  %s✗%s %s\n'  "$R" "$Z" "$*"; }
warn() { printf '  %s!%s %s\n'  "$Y" "$Z" "$*"; }
section() { printf '\n%s%s%s\n' "$B" "$*" "$Z"; }

MISSING=""     # tools we could not resolve and could not fix
INSTALLED=""   # tools this run installed

# ------------------------------------------------------------ system tier ----

section "System dependencies"

# Homebrew — the installer for the other two. Bootstrapping it non-interactively
# is a bad idea (it wants sudo and a licence prompt), so we stop and instruct.
if command -v brew >/dev/null 2>&1; then
  ok "homebrew    $(brew --version | head -1 | awk '{print $2}')"
  HAVE_BREW=1
else
  bad "homebrew    not found"
  warn "install it first: https://brew.sh — it installs docker and mise"
  HAVE_BREW=0
  MISSING="$MISSING homebrew"
fi

# Docker. Two distinct failure modes: not installed, versus installed but the
# daemon is not running. Only the first is fixable by installing something.
if command -v docker >/dev/null 2>&1; then
  if docker info >/dev/null 2>&1; then
    ok "docker      $(docker info --format '{{.ServerVersion}}' 2>/dev/null) (daemon up)"
  else
    bad "docker      installed, but the daemon is not responding"
    warn "start Docker Desktop and re-run — kind cannot create nodes without it"
    MISSING="$MISSING docker-daemon"
  fi
elif [ "$CHECK_ONLY" = 1 ]; then
  bad "docker      not installed"
  MISSING="$MISSING docker"
elif [ "$HAVE_BREW" = 1 ]; then
  bad "docker      not installed"
  printf '    installing Docker Desktop…\n'
  if brew install --cask docker; then
    INSTALLED="$INSTALLED docker"
    warn "Docker Desktop installed — LAUNCH IT ONCE to start the daemon, then re-run"
    MISSING="$MISSING docker-daemon"
  else
    bad "docker      install failed"
    MISSING="$MISSING docker"
  fi
else
  bad "docker      not installed (and no brew to install it with)"
  MISSING="$MISSING docker"
fi

# mise — provides every tool in the project tier, so it must come before them.
if command -v mise >/dev/null 2>&1; then
  ok "mise        $(mise --version 2>/dev/null | awk '{print $1}')"
elif [ "$CHECK_ONLY" = 1 ]; then
  bad "mise        not installed"
  MISSING="$MISSING mise"
elif [ "$HAVE_BREW" = 1 ]; then
  bad "mise        not installed"
  printf '    installing…\n'
  if brew install mise; then
    INSTALLED="$INSTALLED mise"
    ok "mise        $(mise --version 2>/dev/null | awk '{print $1}')"
  else
    bad "mise        install failed"
    MISSING="$MISSING mise"
  fi
else
  bad "mise        not installed (and no brew to install it with)"
  MISSING="$MISSING mise"
fi

# ----------------------------------------------------------- project tier ----

# Each tool spells "tell me your version" differently; --version is wrong for
# most of them and prints a usage error. Report the real thing, not "installed".
tool_version() {
  case "$1" in
    kubectl) mise exec -- kubectl version --client 2>/dev/null | head -1 ;;
    helm)    mise exec -- helm version --short     2>/dev/null | head -1 ;;
    k9s)     mise exec -- k9s version -s           2>/dev/null | head -1 | awk '{print $NF}' ;;
    *)       mise exec -- "$1" --version           2>/dev/null | head -1 ;;
  esac
}

section "Project tools (mise, pinned in ./mise.toml)"

if ! command -v mise >/dev/null 2>&1; then
  warn "skipped — mise itself is missing"
  for entry in $MISE_TOOLS; do MISSING="$MISSING ${entry%%:*}"; done
else
  for entry in $MISE_TOOLS; do
    tool="${entry%%:*}"
    want="${entry##*:}"

    # `mise which` succeeds only when a version is BOTH pinned and installed —
    # exactly the condition the shims fail on. This is the check that matters.
    if mise which "$tool" >/dev/null 2>&1; then
      ok "$(printf '%-8s' "$tool")    $(tool_version "$tool")"
      continue
    fi

    if [ "$CHECK_ONLY" = 1 ]; then
      bad "$(printf '%-8s' "$tool")    not pinned in this project"
      MISSING="$MISSING $tool"
      continue
    fi

    bad "$(printf '%-8s' "$tool")    not pinned — installing $want"
    # `mise use` both installs the version and writes the pin to ./mise.toml.
    # It merges, so tools already pinned there keep whatever version they have.
    if mise use "$tool@$want" >/dev/null 2>&1 && mise which "$tool" >/dev/null 2>&1; then
      ok "$(printf '%-8s' "$tool")    installed and pinned at $want"
      INSTALLED="$INSTALLED $tool"
    else
      bad "$(printf '%-8s' "$tool")    install failed"
      MISSING="$MISSING $tool"
    fi
  done
fi

# --------------------------------------------------------------- summary ----

section "Summary"

[ -n "$INSTALLED" ] && printf '  installed this run:%s\n' "$INSTALLED"

if [ -n "$MISSING" ]; then
  printf '  %sstill missing:%s%s\n\n' "$R" "$Z" "$MISSING"
  if [ "$CHECK_ONLY" = 1 ]; then
    printf '  re-run without --check to install them\n'
  fi
  exit 1
fi

printf '  %sall prerequisites present%s\n' "$G" "$Z"

# Only worth saying when it is actually true. mise activation puts the shims
# directory on PATH, so its absence is exactly the case where a bare `kind`
# fails despite everything above being green.
case ":$PATH:" in
  *":$HOME/.local/share/mise/shims:"*) ;;
  *)
    printf '\n'
    warn "mise is not activated in this shell — a bare \`kind\` will still fail"
    warn "add  eval \"\$(mise activate zsh)\"  to ~/.zshrc, or use \`mise exec --\`"
    ;;
esac
