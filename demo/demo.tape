# vhs tape for the git-tidy demo. Generate the GIF with:
#
#   vhs demo/demo.tape        # https://github.com/charmbracelet/vhs
#
# Run from the repository root. Produces demo/git-tidy.gif.

Output demo/git-tidy.gif

Set Shell bash
Set FontSize 18
Set Width 1100
Set Height 650
Set Padding 24
Set TypingSpeed 60ms

# Build a throwaway demo repo and put git-tidy on PATH (hidden from the cast).
Hide
Type "source demo/setup.sh" Enter
Sleep 1s
Show

Type "git branch" Sleep 500ms Enter
Sleep 2s

Type "# preview what would be removed" Sleep 500ms Enter
Type "git tidy -n" Sleep 500ms Enter
Sleep 2500ms

Type "# clean up (feature/widget was squash-merged)" Sleep 500ms Enter
Type "git tidy" Sleep 500ms Enter
Sleep 2s
Type "y" Sleep 300ms Enter
Sleep 2s

Type "git branch" Sleep 500ms Enter
Sleep 3s
