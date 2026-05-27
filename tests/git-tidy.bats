#!/usr/bin/env bats
#
# Functional tests for git-tidy.
#
# Each test runs in a throwaway directory containing a bare "remote" and a
# clone, so nothing touches your real repositories or global git config.

setup() {
    TIDY="$BATS_TEST_DIRNAME/../git-tidy"
    TMP="$(mktemp -d)"

    export GIT_CONFIG_GLOBAL="$TMP/gitconfig"
    export GIT_CONFIG_SYSTEM=/dev/null
    git config --global user.email "test@example.com"
    git config --global user.name "Test"
    git config --global init.defaultBranch main

    git init -q --bare "$TMP/remote.git"
    git clone -q "$TMP/remote.git" "$TMP/work" 2>/dev/null
    cd "$TMP/work"

    git checkout -q -b main
    echo init > file
    git add .
    git commit -qm "init"
    git push -q origin main
    git remote set-head origin main
}

teardown() {
    rm -rf "$TMP"
}

# Create a branch that is fully merged into main (no commits ahead).
make_merged() {
    git branch "$1" main
}

# Create a branch with a commit ahead of main (not merged).
make_unmerged() {
    git checkout -q -b "$1" main
    echo "$1" > "$1.txt"
    git add .
    git commit -qm "work on $1"
    git checkout -q main
}

# Create a branch, then squash-merge it into main (as GitHub "Squash and merge"
# does). The branch keeps its original commits, which never appear in main, so
# it is only detectable by patch-equivalence. Leaves HEAD on main.
make_squash_merged() {
    git checkout -q -b "$1" main
    echo "$1-a" > "$1-a.txt"
    git add .
    git commit -qm "$1 c1"
    echo "$1-b" > "$1-b.txt"
    git add .
    git commit -qm "$1 c2"
    git checkout -q main
    git merge -q --squash "$1"
    git commit -qm "squash merge $1"
    git push -q origin main
}

@test "reports nothing to do when there are no merged branches" {
    make_unmerged feature-a
    run "$TIDY" -y
    [ "$status" -eq 0 ]
    [[ "$output" == *"No merged branches to clean up."* ]]
}

@test "deletes a fully merged local branch with -y" {
    make_merged merged-a
    make_unmerged feature-a
    run "$TIDY" -y
    [ "$status" -eq 0 ]
    [[ "$output" == *"Deleted 1 merged branch(es):"* ]]
    [[ "$output" == *"merged-a"* ]]
    run git branch --list merged-a
    [ -z "$output" ]
    run git branch --list feature-a
    [ -n "$output" ]
}

@test "dry-run lists branches without deleting them" {
    make_merged merged-a
    run "$TIDY" -n
    [ "$status" -eq 0 ]
    [[ "$output" == *"Would delete 1 merged branch(es):"* ]]
    [[ "$output" == *"merged-a"* ]]
    run git branch --list merged-a
    [ -n "$output" ]
}

@test "does not delete the current branch even if merged" {
    git checkout -q -b merged-current main
    run "$TIDY" -y
    [ "$status" -eq 0 ]
    [[ "$output" == *"No merged branches to clean up."* ]]
    run git branch --list merged-current
    [ -n "$output" ]
}

@test "does not delete the default branch" {
    make_merged merged-a
    run "$TIDY" -n
    [[ "$output" != *" main"* ]]
}

@test "exclude pattern skips matching branches" {
    make_merged release/1.0
    make_merged feature-a
    run "$TIDY" -n --exclude 'release/*'
    [ "$status" -eq 0 ]
    [[ "$output" == *"feature-a"* ]]
    [[ "$output" != *"release/1.0"* ]]
}

@test "exclude is repeatable" {
    make_merged release/1.0
    make_merged hotfix/x
    make_merged feature-a
    run "$TIDY" -n -e 'release/*' -e 'hotfix/*'
    [[ "$output" == *"feature-a"* ]]
    [[ "$output" != *"release/1.0"* ]]
    [[ "$output" != *"hotfix/x"* ]]
}

@test "--base compares against a non-default branch" {
    git checkout -q -b develop main
    echo d > d.txt
    git add .
    git commit -qm "develop work"
    git push -q origin develop
    # Branch fully merged into develop but not main.
    git branch sub-of-develop develop
    git checkout -q main
    run "$TIDY" -n -b develop
    [ "$status" -eq 0 ]
    [[ "$output" == *"sub-of-develop"* ]]
}

@test "combined short flags are expanded (-ny)" {
    make_merged merged-a
    run "$TIDY" -ny
    [ "$status" -eq 0 ]
    [[ "$output" == *"Would delete"* ]]
    run git branch --list merged-a
    [ -n "$output" ]
}

@test "prompt aborts on a non-yes answer" {
    make_merged merged-a
    run bash -c "echo n | '$TIDY'"
    [ "$status" -eq 0 ]
    [[ "$output" == *"Aborted."* ]]
    run git branch --list merged-a
    [ -n "$output" ]
}

@test "errors when not inside a git repository" {
    cd "$TMP"
    run "$TIDY"
    [ "$status" -eq 1 ]
    [[ "$output" == *"Not inside a git repository."* ]]
}

@test "errors when the remote does not exist" {
    run "$TIDY" --remote-name nope
    [ "$status" -eq 1 ]
    [[ "$output" == *"Remote 'nope' not found."* ]]
}

@test "--remote-name compares against a non-origin remote" {
    git remote add upstream "$TMP/remote.git"
    git fetch -q upstream
    git remote set-head upstream main
    make_merged merged-a
    run "$TIDY" -n --remote-name upstream
    [ "$status" -eq 0 ]
    [[ "$output" == *"merged-a"* ]]
}

@test "progress output contains no ANSI escapes when not a TTY" {
    make_merged merged-a
    run "$TIDY" -y
    [[ "$output" == *"Deleted 1 merged branch(es):"* ]]
    [[ "$output" != *$'\033'* ]]
}

@test "unknown option exits with an error" {
    run "$TIDY" --bogus
    [ "$status" -eq 1 ]
    [[ "$output" == *"Unknown option"* ]]
}

@test "--help prints usage and exits 0" {
    run "$TIDY" --help
    [ "$status" -eq 0 ]
    [[ "$output" == *"Usage: git tidy"* ]]
}

@test "detects and force-deletes a squash-merged branch" {
    make_squash_merged squashed
    run "$TIDY" -y
    [ "$status" -eq 0 ]
    [[ "$output" == *"Deleted 1 merged branch(es):"* ]]
    [[ "$output" == *"squashed"* ]]
    [[ "$output" != *"Failed to delete"* ]]
    run git branch --list squashed
    [ -z "$output" ]
}

@test "squash-merged branch shows in dry-run without being deleted" {
    make_squash_merged squashed
    run "$TIDY" -n
    [ "$status" -eq 0 ]
    [[ "$output" == *"squashed"* ]]
    run git branch --list squashed
    [ -n "$output" ]
}

@test "preserves unmerged work while cleaning a squash-merged branch" {
    make_squash_merged squashed
    make_unmerged open-work
    run "$TIDY" -y
    [ "$status" -eq 0 ]
    [[ "$output" == *"squashed"* ]]
    [[ "$output" != *"open-work"* ]]
    run git branch --list open-work
    [ -n "$output" ]
}

@test "deletes a squash-merged branch from the remote" {
    git checkout -q -b squashed main
    echo s > s.txt
    git add .
    git commit -qm "squashed work"
    git push -q origin squashed
    git checkout -q main
    git merge -q --squash squashed
    git commit -qm "squash merge squashed"
    git push -q origin main
    git fetch -q origin --prune
    run "$TIDY" -r -y
    [ "$status" -eq 0 ]
    [[ "$output" == *"Deleted 1 merged branch(es):"* ]]
    [[ "$output" == *"squashed"* ]]
    [[ "$output" != *"Failed to delete"* ]]
}

@test "remote mode deletes merged remote branches and leaves origin/HEAD alone" {
    make_merged feature-a
    git push -q origin feature-a
    git fetch -q origin --prune
    run "$TIDY" -r -y
    [ "$status" -eq 0 ]
    [[ "$output" == *"Deleted 1 merged branch(es):"* ]]
    [[ "$output" == *"feature-a"* ]]
    # The spurious "origin" (origin/HEAD symref) must not be touched/reported.
    [[ "$output" != *"Failed to delete"* ]]
    git fetch -q origin --prune
    run git for-each-ref --format='%(refname:short)' refs/remotes/origin/feature-a
    [ -z "$output" ]
}
