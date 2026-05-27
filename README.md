# git-tidy

[![Tests](https://github.com/willregelmann/git-tidy/actions/workflows/test.yml/badge.svg)](https://github.com/willregelmann/git-tidy/actions/workflows/test.yml)

Delete local branches that are fully merged into the default branch.

## Installation

```sh
curl -sL https://raw.githubusercontent.com/willregelmann/git-tidy/main/git-tidy \
  -o ~/.local/bin/git-tidy && chmod +x ~/.local/bin/git-tidy
```

This places it on your PATH as a git subcommand — no alias needed.

Requires `~/.local/bin` to be on your `PATH`. To verify: `echo $PATH | tr ':' '\n' | grep local`.

## Usage

```sh
# Preview what would be deleted
git tidy -n

# Delete merged branches
git tidy

# Skip confirmation prompt
git tidy -y

# Delete merged branches from the remote
git tidy -r

# Exclude branches matching a glob pattern (repeatable)
git tidy --exclude 'release/*'
git tidy -e 'release/*' -e 'hotfix/*'

# Compare against a specific base branch
git tidy -b develop

# Combine flags
git tidy -rn --exclude 'release/*'
```

### Options

| Flag | Description |
|---|---|
| `-n`, `--dry-run` | Show which branches would be deleted without deleting them |
| `-r`, `--remote` | Delete merged branches from the remote instead of local |
| `-y`, `--yes` | Skip confirmation prompt |
| `-b`, `--base <branch>` | Branch to compare against (default: auto-detected from remote) |
| `-e`, `--exclude <pattern>` | Exclude branches matching a glob pattern (repeatable) |

Example output:

```
Deleted 3 merged branch(es):
  feature/old-widget
  release-25.2.1
  hotfix/typo
```

## Requirements

- Bash 4+ (uses associative-style arrays and substring expansion)
- Git

## How it works

1. Detects the default branch from the remote (`origin/HEAD`, falling back to `main` or `master`)
2. Runs `git fetch --prune` to sync remote tracking refs
3. For each branch, decides whether it is merged into `origin/<default>`:
   - **Plain / fast-forward merges** — the branch has 0 commits beyond the base.
   - **Squash and rebase merges** — the branch's commits keep their original SHAs and never appear in the base, so a commit-count check misses them. `git tidy` instead checks whether the branch's changes are already present upstream (via `git cherry` patch-equivalence, including a synthetic squashed-diff commit), so squash-merged branches are detected too.
4. Deletes merged branches: locally with `git branch -d` (or `-D` for squash/rebase merges, whose changes are confirmed upstream but which Git's own ancestry check would refuse), or `git push origin --delete` with `-r`

Skips the current branch and the default branch.

> **Note:** `git tidy` compares against the `origin` remote, so the repository needs an `origin` remote with the default branch pushed to it. Branches are only deleted after their changes are verified present in `origin/<default>`.

## Development

Lint the script:

```sh
shellcheck git-tidy
```

Run the test suite ([bats](https://github.com/bats-core/bats-core)):

```sh
bats tests/
```

The tests create isolated, throwaway Git repositories with their own global
config, so they don't touch your real repositories or git settings.

## License

[MIT](LICENSE)
