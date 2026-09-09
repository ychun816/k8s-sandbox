# mise for tool versions

## index
- [understand mise](#understand-mise)
- [three steps people conflate](#three-steps-people-conflate)
- [important commands](#important-commands)
- [anatomy of mise.toml](#anatomy-of-misetoml)
- [compare : mise.toml vs. requisites.txt vs. shell script](#compare--misetoml-vs-requisitestxt-vs-shell-script)
- [compare : mise vs. brew](#compare--mise-vs-brew)
- [what a shell script is still for](#what-a-shell-script-is-still-for)
- [resource](#resource)

---

## understand mise

- mise is a version manager: it installs many versions of a CLI side by side and
  decides which one is active **based on the directory you are standing in**.
- it does not put tools on `PATH`. It puts **shims** there — stand-ins that look
  up the version you meant, then exec the real binary.
- the lookup table is `mise.toml`. mise walks up from the current directory
  until it finds one.

That last point is the whole design. With no `mise.toml` in scope the shim has
nothing to read, so it refuses to guess:

```sh
$ kind --version
mise ERROR No version is set for shim: kind
```

Nothing is broken and nothing is uninstalled — `~/.local/share/mise/installs/kind/0.32.0`
is still sitting there. The version simply was not *selected*.

---

## three steps people conflate

These are separate and skipping the middle one causes the confusing failure —
mise installed, `mise install` reporting success, and `kind` still not found.

| step | what it does | how often |
|---|---|---|
| `brew install mise` | puts the mise binary on the machine | once per machine |
| `eval "$(mise activate zsh)"` in `~/.zshrc` | makes your shell use the shims | once per machine |
| `mise install` | installs the tools this project pins | once per project |

Activation is what puts `~/.local/share/mise/shims` on `PATH` and what swaps
versions when you `cd` between projects. Without it the tools exist but your
shell never reaches them.

**Not installed by mise:** Docker. It is a system service with a GUI, not a
versioned CLI, so it installs per OS and is checked separately.

---

## important commands

Everything below is verified against mise 2026.9.1. `mise x` is an alias for
`mise exec`, `mise i` for `mise install`, `mise ls` for `mise list`.

### setup — once per machine

```sh
brew install mise                    # the binary
eval "$(mise activate zsh)"          # put this in ~/.zshrc, not just the shell
mise doctor                          # sanity-check the install, reports problems
```

### inspect — what is actually going on

```sh
mise ls                    # every version installed on this machine
mise ls --current          # what is active HERE, and which file decided it
mise which kind            # absolute path to the binary that would run
mise config ls             # which mise.toml files are in scope right now
mise bin-paths             # the bin dirs mise is injecting
mise env                   # the env vars activation would export
```

`mise ls --current` is the one to reach for when a version surprises you — it
prints the deciding config file next to each tool, so "why is kubectl 1.36 here"
answers itself.

### install and pin

```sh
mise install               # install everything pinned in ./mise.toml
mise use kind@0.32.0       # install AND write the pin into ./mise.toml
mise use -g kind@0.32.0    # same, machine-global — avoid, see below
mise install kind@0.33.0   # install a version WITHOUT pinning it
mise ls-remote kind        # every version available upstream
mise latest kind           # newest available
```

`mise use` is the everyday one: it installs *and* records the decision. Plain
`mise install kind@X` puts a version on disk that nothing selects.

### upgrade

```sh
mise outdated              # behind, but still inside your pin's range
mise outdated --bump       # newer versions OUTSIDE the range — the real answer
mise use kind@0.33.0       # actually move the pin, and rewrite mise.toml
```

Nothing upgrades on its own. That is the point of pinning, and it is why
`mise outdated --bump` exists — it is the only command that will tell you a
newer version exists at all. Right now in this sandbox:

```
kind     0.32.0 -> 0.33.0
kubectl  1.36.4 -> 1.37.0
```

**Before bumping kubectl, check the cluster.** kubectl is supported within ±1
minor of the k8s version kind creates. Moving kubectl alone can walk you out of
that window — the two pins are related, not independent.

### remove

Two different things, easy to confuse:

```sh
mise use --remove kind       # drop the PIN from mise.toml (install stays)
mise uninstall kind@0.32.0   # delete the INSTALLED version (pin stays)
mise prune                   # delete versions nothing pins any more
```

### run tools

```sh
mise exec -- kind create cluster    # ignores shell activation entirely
mise x -- kubectl get nodes         # short form
mise en                             # new shell with the env applied
```

### troubleshoot

```sh
mise doctor                # first thing to run when something is wrong
mise reshim                # rebuild shims after a tool grows a new binary
mise cache clear           # when version lookups go stale
```

### the two that matter in scripts

- **`mise which <tool>`** succeeds only when a version is *both pinned and
  installed* — exactly the condition `command -v` gets wrong, because the shim
  sits on `PATH` even when nothing resolves. This is the correct check.
- **`mise exec --`** ignores shell activation. Correct inside scripts, cron and
  Makefiles, where `~/.zshrc` was never sourced.

Avoid `mise use -g`. It lives on one laptop, is not committed, and cannot
express "filmory needs a different kubectl than the sandbox".

---

## anatomy of mise.toml

```toml
[tools]
kubectl = "1.36.4"   # keep within one minor of the cluster kind creates
kind    = "0.32.0"   # local k8s cluster in Docker
helm    = "4.2.4"
```

Pinning matters here for a kubernetes-specific reason, not general tidiness:
kubernetes has a **version skew policy** — kubectl is supported within ±1 minor
of the cluster. Outside that, commands half-work and YAML fields get silently
dropped. kind creates the cluster at a fixed k8s version, so the two numbers
have to be compared. Putting both in one file is what makes that possible.

The comment next to a pin is the point. `# keep within one minor of the cluster`
is only useful sitting beside the number it constrains.

---

## compare : mise.toml vs. requisites.txt vs. shell script

Three ways to answer "what does this project need". They are not equivalent.

| | **mise.toml** | **requisites.txt** | **shell script** |
|---|---|---|---|
| **What it is** | a manifest the tool itself reads | a plain list only your own script reads | imperative code |
| **Who acts on it** | mise, on every command, in every shell | nothing, until you write a parser | only itself |
| **Delete it and…** | tools stop resolving — `kind` fails | nothing changes at all | no checks run |
| **To install from it** | `mise install` | write a loop that calls `mise use` | whatever you coded |
| **Per-directory versions** | yes — versions switch as you `cd` | no | no |
| **Reproducible for a teammate** | yes, committed and exact | only via the script that reads it | only if it pins versions |
| **Drift risk** | none — single source of truth | duplicates mise.toml, goes stale silently | duplicates mise.toml |

The drift row is not theoretical. Set `requisites.txt` to `kind 0.99.9` while
`mise.toml` says `0.32.0`, and everything reports green — because the tool
already resolves, so the list is never consulted. Two files holding the same
fact will disagree eventually, and only one of them was ever load-bearing.

**Takeaway:** the ecosystem's own manifest *is* the requisites file. Nobody keeps
a hand-written list beside `package.json`, `go.mod` or `Gemfile`, and for the
same reason nothing should sit beside `mise.toml`. A separate file only earns
its place for prerequisites the manifest cannot express — and those turn out to
be docker, brew and mise themselves, which are per-machine, not per-project.

---

## compare : mise vs. brew

The obvious alternative is `brew install kubectl`. It works, and it is wrong here.

| | **mise** | **brew** |
|---|---|---|
| **Versions at once** | many, side by side | one, machine-wide |
| **Chosen by** | nearest `mise.toml` | whatever was installed last |
| **Committed to git** | yes | no |
| **Teammate gets** | the exact pinned version | whatever brew ships that day |
| **Upgrades** | only when you change the pin | `brew upgrade` moves it under you |

brew is right for the per-machine tier — docker, mise itself. mise is right for
anything whose version is a project decision.

---

## what a shell script is still for

Dropping `requisites.txt` does not mean dropping the setup script. It means the
script stops re-implementing what mise already does, and keeps only what mise
cannot:

- bootstrapping **brew**, and installing docker and mise with it
- checking the **docker daemon is running**, not merely installed — two different
  failures needing two different messages
- enforcing **order**: brew → docker + mise → `mise install`
- printing a **human-readable report**, and exiting non-zero when something is
  genuinely missing

Everything else collapses to two lines:

```sh
mise install          # installs everything pinned in mise.toml
mise ls --current     # report what resolved
```

**Rule of thumb:** declarative manifest for anything the tool already models;
script only the gaps. A script that reimplements its own package manager is a
second source of truth wearing a disguise.

---

## resource

- [mise — Getting Started](https://mise.jdx.dev/getting-started.html)
- [mise — Configuration (`mise.toml`)](https://mise.jdx.dev/configuration.html)
- [mise — Shims vs PATH activation](https://mise.jdx.dev/dev-tools/shims.html)
- [Kubernetes — version skew policy](https://kubernetes.io/releases/version-skew-policy/)

- [Mise version manager: number one tool for a developer](https://www.youtube.com/watch?v=w0sQQr7TUu0)
- [Mise: The BEST Way to Manage Versions of Node, Python, Go and Much More](https://www.youtube.com/watch?v=eKJCnc0t8V0)