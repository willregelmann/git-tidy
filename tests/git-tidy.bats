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
