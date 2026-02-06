# git-tidy

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

### As a post-merge hook

Add to your global or repo-level `post-merge` hook to run automatically after `git pull`:

```sh
#!/bin/bash
git tidy
```

## How it works

1. Detects the default branch (`main` or `master`) from the remote
2. Runs `git fetch --prune` to sync remote tracking refs
3. For each local branch, checks if it has 0 commits ahead of `origin/<default>`
4. Deletes fully merged branches with `git branch -d` (safe delete — won't force-delete unmerged work)

Skips the current branch and the default branch.
