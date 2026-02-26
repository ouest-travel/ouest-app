Commit and push the current changes to GitHub:

1. Run `git status` to see all changed/untracked files
2. Run `git diff` to understand what changed
3. Run `git log --oneline -5` to see recent commit style
4. Stage the relevant files — NEVER stage files containing real API keys or secrets (e.g., Debug.xcconfig, Release.xcconfig with real values)
5. Write a clear, descriptive commit message that explains WHAT changed and WHY
6. Create the commit
7. Push to the current branch

Rules:
- Never force push
- Never push secrets or API keys
- Follow the existing commit message style
- If there are no changes, say so
