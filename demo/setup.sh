#!/usr/bin/env bash
#
# Builds a throwaway repository for the git-tidy demo cast and puts the local
# git-tidy on PATH so `git tidy` works during recording. Meant to be *sourced*
# (so the PATH change and working directory persist), e.g.:
#
#   source demo/setup.sh
#
# Creates everything under a fresh temp dir, so it never touches real repos.

_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
_work="$(mktemp -d)"
_bin="$(mktemp -d)"
ln -sf "$_root/git-tidy" "$_bin/git-tidy"
export PATH="$_bin:$PATH"

git init -q --bare "$_work/remote.git"
git clone -q "$_work/remote.git" "$_work/repo" 2>/dev/null
cd "$_work/repo" || return 1

git config user.email "demo@example.com"
git config user.name "Demo"

git checkout -q -b main
echo "# project" > README.md
git add . && git commit -qm "Initial commit"
git push -q origin main
git remote set-head origin main

# Merged via a merge commit.
git checkout -q -b feature/login main
echo "login" > login.js && git add . && git commit -qm "Add login"
git checkout -q main && git merge -q --no-ff feature/login -m "Merge feature/login"

# Squash-merged (commits never appear on main — the case naive tools miss).
git checkout -q -b feature/widget main
echo "wip" > widget.js && git add . && git commit -qm "Widget WIP"
echo "done" >> widget.js && git add . && git commit -qm "Finish widget"
git checkout -q main && git merge -q --squash feature/widget && git commit -qm "Add widget (#42)"

# Merged release branch (no new commits of its own).
git checkout -q -b release/1.2 main

# Still in progress — must NOT be deleted.
git checkout -q -b feature/payments main
echo "wip" > payments.js && git add . && git commit -qm "WIP payments"

git checkout -q main
git push -q origin main
clear
