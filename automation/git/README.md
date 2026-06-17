# Git Automation

This folder contains PowerShell automation for staging, committing, and pushing workspace changes directly to GitHub from Visual Studio Code.

## Purpose

This automation streamlines Git workflows during active engineering sessions while maintaining explicit control over when changes are synchronized to remote repositories.

Instead of committing continuously or manually running Git commands, this workflow enables:

- Local Development Freedom: Work continuously with VS Code Auto Save handling local edits.
- On-Demand Sync: Trigger a single action to stage, commit, and push changes at logical stopping points.
- Consistent Version Tracking: Automatically updates repository version metadata on each execution.
- Controlled Change Management: Reduces noisy commit history while preserving meaningful checkpoints.

## How It Works

This is a manual execution workflow.

- Run `sync.ps1` when ready to synchronize changes
- The script executes once and then exits
- All changes are staged, committed, and pushed in a single operation
- Version tracking is updated automatically during execution

## Safety Behavior

- The script detects file deletions in the staged changes
- If deletions are detected, execution is aborted
- Manual review via Git is required before proceeding
- This prevents accidental loss of tracked files


## Folder Structure

```text
repo-root/
├── automation/
│   └── git/
│       ├── README.md
│       └── sync.ps1
│
├── .gitattributes
├── .gitignore
├── LICENSE
├── README.md
└── version.txt
```
