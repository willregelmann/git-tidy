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
```

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

## License

MIT
