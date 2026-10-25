# GitSync Ultra v4.0

> **Ultra-fast, failsafe, cross-platform Git automation & stash tracker for Windows and macOS.**  
> Callable from **any folder**, runs in **< 30ms**, and never loses uncommitted work.

---

## ⚡ What's New in v4.0

1. **Rock-Solid PATH Execution on Windows**:
   - Fixed the critical codepage offset bug where batch files with LF line endings or ANSI banner tricks caused `cmd.exe` to seek to invalid byte offsets and freeze or error out.
   - Safe, native ANSI terminal detection without external subshells.
   - Isolated tracking cache inside `.git/gitsync/` and user profile (`~/.gitsync/`), completely preventing `Access is denied` errors in system/root folders.
   - Dual `.bat` and `.cmd` wrappers for instant execution in Command Prompt, PowerShell, Git Bash, and Windows Terminal.

2. **Advanced Stash & Stash Pop Tracking**:
   - **Audit Trail**: Every stash creation, pop, apply, drop, and clear is recorded with timestamps, branch names, commit hashes, and status (clean vs conflicted).
   - **Safety Patch Snapshots**: Every stash automatically backs up a full diff patch into `.git/gitsync/stashes/`.
   - **Never Lose Popped Stashes**: Even after `git stash pop` or `git stash drop` permanently removes a stash from Git, you can view or restore it anytime with `gitsync stash recover`.
   - **Smart Auto-Stash**: `gitsync sync` and `gitsync pull` automatically stash dirty changes before pulling/rebasing and restore them afterwards.

3. **Dedicated macOS Version (`gitsync`)**:
   - Standalone, high-performance POSIX Bash/Zsh script with 100% feature parity.
   - Native colors, interactive menus, and subcommands.

4. **Blazing Speed ("Damn Fast")**:
   - Removed blocking 10-second network update checks from startup.
   - Instant command-line dispatch (< 30ms execution).

---

## 🚀 Installation & PATH Setup

### Windows Setup
You can run `gitsync` from any folder by adding the repository folder to your system or user `PATH`.

1. Open PowerShell as Administrator or standard user and run:
   ```powershell
   [Environment]::SetEnvironmentVariable("Path", $env:Path + ";C:\path\to\gitsync", [EnvironmentVariableTarget]::User)
   ```
   *(Replace `C:\path\to\gitsync` with your actual folder path)*.
2. Restart your terminal (CMD, PowerShell, or Windows Terminal).
3. Type `gitsync` or `gitsync status` from **any directory**!

### macOS Setup
1. Clone or copy this repository to your Mac.
2. Make `gitsync` executable (if not already):
   ```bash
   chmod +x gitsync
   ```
3. Copy to `/usr/local/bin` (recommended for system-wide access):
   ```bash
   sudo cp gitsync /usr/local/bin/gitsync
   ```
   *Or add to your `~/.zshrc` / `~/.bash_profile`:*
   ```bash
   export PATH="$PATH:/path/to/gitsync"
   ```
4. Run `gitsync` from **any directory**!

---

## 📦 Stash & Pop Tracker Commands

| Command | Description |
|---|---|
| `gitsync stash` | Open interactive Stash & Pop Tracker Manager |
| `gitsync pop` | Pop latest stash with automatic tracking and conflict detection |
| `gitsync stash pop [index]` | Pop specific stash (default: 0) and record result |
| `gitsync stash save [msg]` | Stash working changes with an automatic safety patch snapshot |
| `gitsync stash history` | View the complete audit log of all stashes created and popped |
| `gitsync stash recover` | Interactively select and restore any historical or dropped stash |
| `gitsync stash list` | Show active Git stash queue |
| `gitsync stash show [index]` | View the diff of a specific stash |
| `gitsync stash drop [index]` | Drop stash from Git while keeping a safety backup patch |
| `gitsync stash clear` | Clear all stashes with a full safety backup snapshot |

---

## 🛠️ Complete CLI Command Reference

### Workflows & Wizards
- `gitsync` — Full interactive 3-step wizard (Repo Check → Commit → Remote Push)
- `gitsync sync` — One-step Auto-Stash + Pull (rebase) + Commit + Push
- `gitsync doctor` — Run 11-point health check diagnostic
- `gitsync setup` — First-time Git configuration wizard (name, email, default branch)

### Fast Operations
- `gitsync status` (or `gitsync s`) — Show branch status, staged, and unstaged files
- `gitsync commit [msg]` (or `gitsync c [msg]`) — Stage all and commit
- `gitsync push [branch]` (or `gitsync p`) — Push current branch to remote origin
- `gitsync pull [branch]` — Pull with auto-stash protection
- `gitsync log` (or `gitsync l`) — Pretty one-line graph view (last 15 commits)
- `gitsync logfull` — Full history with dates and commit authors
- `gitsync diff [file]` — Show changes (staged and unstaged)
- `gitsync undo` — Soft reset previous commit (keeps your files staged)
- `gitsync amend [msg]` — Edit or amend the last commit message
- `gitsync fetch` — Fetch and prune all remote tracking branches
- `gitsync prune` — Delete local branches that were removed on the remote
- `gitsync clean` — Interactively preview and remove untracked files
- `gitsync blame <file>` — Line-by-line commit authorship

### Branch, Remote, Tag, Reset
- `gitsync branch` (or `gitsync br`) — Interactive branch manager
- `gitsync branch create <name>` — Create and switch to new branch
- `gitsync branch switch <name>` — Switch to branch
- `gitsync branch delete <name>` — Delete local branch
- `gitsync branch merge <name>` — Merge branch into current
- `gitsync branch push [name]` — Push branch to origin
- `gitsync tag` — Interactive tag manager
- `gitsync remote` — Manage remote repository URLs
- `gitsync reset` — Interactive soft / mixed / hard reset
- `gitsync cherrypick [hash]` (or `gitsync cp`) — Cherry-pick specific commit
- `gitsync rebase` — Rebase manager (continue / abort / skip)
- `gitsync conflicts` — Guided merge conflict resolver

### Utilities
- `gitsync ignore` — Manage `.gitignore` patterns and templates
- `gitsync whoami` — Display configured Git identity
- `gitsync stats` — Commit, branch, tag, and contributor stats
- `gitsync history` — View GitSync action log
- `gitsync clearhistory` — Clear GitSync history logs
- `gitsync archive` — Create a `.zip` archive of the current commit
- `gitsync backup` — Create a standalone Git bundle backup
- `gitsync update` — Check GitHub for updates on demand
- `gitsync version` — Show version info
- `gitsync help` — Show help manual
