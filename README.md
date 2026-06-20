# IconMatrix

![Status](https://img.shields.io/badge/status-active-success) ![VSCode](https://img.shields.io/badge/vscode-extension-blue) ![Theme](https://img.shields.io/badge/theme-icon%20framework-purple) ![Automation](https://img.shields.io/badge/automation-enabled-brightgreen) ![Architecture](https://img.shields.io/badge/structure-modular-orange) ![Pipeline](https://img.shields.io/badge/pipeline-registry--driven-informational) ![PowerShell](https://img.shields.io/badge/powershell-automation-5391FE?logo=powershell&logoColor=white) ![License](https://img.shields.io/badge/license-MIT-green)

Custom registry-driven VS Code icon theme built through a fully automated PowerShell pipeline.

IconMatrix is designed to provide scalable, maintainable, and highly customizable file and folder icon mapping for Visual Studio Code. Rather than relying on manually maintained theme files, IconMatrix generates icon mappings dynamically from a structured registry and a layered, self-learning mapping pipeline — including automatic extension and folder-name inference for every icon added to the source set.

---

## Repository Structure

```text
IconMatrix/
├── Core/                       # Core processing and compilation logic
│   ├── Convert-Icons.ps1               # Converts source assets into standardized icon outputs
│   ├── Invoke-IconNormalization.ps1    # Normalizes naming and formatting
│   ├── Invoke-IconMatrixTheme.ps1      # Builds the VS Code icon theme JSON
│   └── Sync-Icons.ps1                  # Main icon synchronization pipeline
│
├── pipeline/                  # Registry, mapping, and orchestration logic
│   ├── Copy-SourceIcons.ps1            # Copies source icons into the repository workspace
│   ├── MappingGenerator.ps1            # Auto-generates extension/file/folder mappings from icon filenames
│   ├── Invoke-SemanticInference.ps1    # Merges manual + auto mappings into a curated semantic map
│   ├── Invoke-RegistryBuild.ps1        # Merges manual, semantic, and auto mappings into the icon registry
│   ├── Clean-Build.ps1                 # Build cleanup utilities
│   └── Run-All.ps1                     # Runs the full pipeline end-to-end
│
├── Tools/                     # User-facing orchestration scripts
│   ├── Publish-IconMatrix.ps1          # End-to-end build, package, and install workflow
│   └── extension/
│       ├── Build-Extension.ps1         # Packages the VSIX
│       └── Install-Extension.ps1       # Installs the packaged extension into VS Code
│
├── utils/                     # Shared helper functions
│   ├── Logging.ps1                     # Logging and output handling
│   ├── Hashing.ps1                     # Hash comparison utilities
│   ├── Naming.ps1                      # Naming normalization helpers
│   ├── IconResolver.ps1                # Shared icon ID resolution logic
│   └── Invoke-ReviewReport.ps1         # Reporting and validation output
│
├── scripts/Powershell/        # Diagnostics, inventory, and maintenance utilities
│   ├── FindMissingIcons.ps1            # Flags icons with no extension/folder coverage
│   ├── FileCapture/                    # Repository file/structure inventory capture
│   ├── FolderCapture/                  # Repository folder inventory capture
│   └── Maintenace/
│       ├── PipelineHealthCheck.ps1     # Validates pipeline output integrity
│       └── Reset-IconMatrix.ps1        # Full environment reset tooling
│
├── config/                    # Repository configuration and mapping layers
│   ├── paths.json                      # Centralized path configuration (machine-specific, gitignored)
│   ├── mappings.json                   # Manual mapping overrides (highest priority)
│   ├── semantic.map.json               # Curated semantic mappings (extensions, fileNames, folderNames)
│   ├── mappings.auto.json              # Auto-generated mappings, regenerated on every build
│   └── icon-manifest.json              # Source icon manifest
│
├── registry/                  # Generated registry output
│   └── icons.json                      # Merged icon registry (iconDefinitions + all mapping layers)
│
├── theme/                     # VS Code theme output
│   ├── icons-theme.json                # Generated VS Code icon theme
│   └── IconsThemeDiag.ps1              # Theme output diagnostics
│
├── Test/                      # Sample files for icon verification
├── source-icons/              # Raw icon source assets
├── processed-icons/           # Converted/normalized icons
├── archive/                   # Legacy or historical scripts
├── automation/git/            # Git bootstrap and sync helpers
├── logs/                      # Pipeline logging outputs
├── .vscodeignore              # Controls VSIX packaging contents
├── .gitignore                 # Git exclusion rules
├── package.json               # VS Code extension manifest
├── LICENSE                    # Licensing information
└── README.md
```

---

## Purpose

This repository supports **VS Code extension automation and icon theme generation** by providing a structured, registry-driven pipeline for building, packaging, and installing a custom file icon theme.

The goal of IconMatrix is to:

* Eliminate manual icon theme maintenance
* Automate icon discovery, mapping, and theme generation end-to-end
* Provide centralized, layered icon mapping management
* Enable repeatable VSIX packaging and installation
* Support long-term maintainability and customization

---

## Features

### Automated Build Pipeline

IconMatrix uses PowerShell orchestration to automate the entire lifecycle:

* Source icon ingestion
* Icon normalization
* Asset conversion (SVG-safe mode)
* **Automatic mapping generation** (extensions, file names, folder names — inferred directly from icon filenames)
* **Semantic inference merge** (manual curation layered over auto-generated mappings)
* Registry generation
* Theme compilation
* VSIX packaging
* Optional local installation into VS Code

### Layered, Self-Updating Mapping System

This is the newest and most significant piece of the pipeline. Icon mappings are no longer hand-maintained in a single file — they're built from three layers, merged with clear priority:

1. **`mappings.json`** — manual hand overrides. Highest priority; use this to fix or add specific cases.
2. **`semantic.map.json`** — curated semantic mappings, generated by merging manual input with auto-detected mappings on every run.
3. **`mappings.auto.json`** — fully automatic, regenerated from scratch on every build by scanning every icon in `processed-icons/` and deriving its file extension, file name, and folder name associations.

Every icon in the set is automatically made available as both a file match and a folder match, so adding a new icon to `processed-icons/` is enough for it to start working — no manual registry editing required. Manual entries in `mappings.json` still take precedence and layer cleanly on top whenever extra aliases or overrides are needed.

### Registry-Driven Theme Generation

Instead of manually maintaining large JSON theme files, IconMatrix dynamically generates mappings using a structured registry model.

This enables:

* Easier maintenance
* Scalable icon expansion
* Consistent naming
* Reduced manual effort

### Diagnostics & Maintenance Tooling

* **`PipelineHealthCheck.ps1`** — validates that registry and theme output are internally consistent.
* **`FindMissingIcons.ps1`** — flags any icon with no extension or folder coverage so gaps are easy to spot.
* **`Reset-IconMatrix.ps1`** — performs a full clean reset of generated config, registry, and theme output so every build starts from a known-clean state.
* **Structure/tree capture scripts** — snapshot the live repository layout for documentation and review.

### VSIX Packaging

The repository includes automated packaging for local VS Code deployment.

Example:

```powershell
& (Join-Path $env:GIT_ROOT "IconMatrix\Tools\Publish-IconMatrix.ps1")
```

Install automatically:

```powershell
& (Join-Path $env:GIT_ROOT "IconMatrix\Tools\Publish-IconMatrix.ps1") -Install
```

Safe dry-run mode:

```powershell
& (Join-Path $env:GIT_ROOT "IconMatrix\Tools\Publish-IconMatrix.ps1") -DryRun
```

---

## Build Workflow

The publish pipeline performs the following stages:

1. **Sync Icons**
   * Copies source assets
   * Validates repository structure
2. **Normalize Icons**
   * Applies naming normalization
   * Standardizes asset handling
3. **Convert Icons**
   * Converts source assets into processed outputs (SVG-safe mode)
4. **Generate Mappings**
   * Scans every processed icon and auto-derives extension, file name, and folder name mappings
   * Merges manual and semantic mapping layers on top
5. **Build Registry**
   * Generates the dynamic icon registry from the merged mapping layers
6. **Compile Theme**
   * Produces `theme/icons-theme.json`
7. **Package Extension**
   * Builds the `.vsix` extension package
8. **Optional Install**
   * Installs directly into VS Code

In day-to-day use, this whole workflow collapses to two steps: drop in any new icon, run a full reset, then a single install command —

```powershell
& (Join-Path $env:GIT_ROOT "IconMatrix\Tools\Publish-IconMatrix.ps1") -Install
```

— and every mapping layer, the registry, and the theme regenerate automatically.

---

## Technologies

* PowerShell
* Visual Studio Code Extension Framework
* VS Code Icon Theme API
* JSON Configuration
* Automation / Orchestration
* Repository-Driven Build Pipelines
* Windows Automation

---

## Configuration

All repository paths are centralized in:

```text
config/paths.json
```

This file is machine-specific and excluded from version control via `.gitignore`. It avoids hardcoded machine paths and enables portable execution across environments.

Example configuration (paths shown are illustrative, not the actual values used):

```json
{
  "keypassIcons": "<drive>:\\Users\\<user>\\Pictures\\<icon-source-folder>",
  "repoRoot": "<drive>:\\<path-to-repo>\\IconMatrix",
  "sourceIcons": "source-icons",
  "processedIcons": "processed-icons",
  "registry": "registry\\icons.json",
  "theme": "theme\\icons-theme.json",
  "logs": "logs"
}
```

Mapping configuration lives alongside it in `config/`:

```text
config/mappings.json        # manual overrides (highest priority)
config/semantic.map.json    # curated semantic mappings (auto-generated + merged)
config/mappings.auto.json   # fully automatic mappings (regenerated every build)
```

---

## Current Status

### Completed

* Build orchestration
* DryRun execution model
* **Fully automated, layered mapping generation (manual → semantic → auto)**
* **Universal folder-icon eligibility** — every icon can resolve as a folder icon, not just a curated subset
* Registry generation with multi-layer merge
* Theme compilation with corrected VS Code schema output
* VSIX packaging
* Automated installation
* `.vscodeignore` optimization
* Repository path abstraction
* Pipeline health checks and missing-icon diagnostics
* Full environment reset tooling

### In Progress

* Extension/file association tuning (avoiding cross-vendor overlap, e.g. an extension shared by multiple tools)
* Theme rendering validation across VS Code versions
* Expanded icon coverage

---

## Security Notes

* No secrets or credentials are intentionally stored in this repository.
* Sensitive configuration files, including `config/paths.json`, are excluded via `.gitignore`.
* VSIX packaging is restricted using `.vscodeignore`.
* Any accidental exposure should be remediated immediately.

---

## License

This repository is licensed under the terms defined in the LICENSE file.
