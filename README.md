# IconMatrix

![Status](https://img.shields.io/badge/status-active-success) ![VSCode](https://img.shields.io/badge/vscode-extension-blue) ![Theme](https://img.shields.io/badge/theme-icon%20framework-purple) ![Automation](https://img.shields.io/badge/automation-enabled-brightgreen)

![Architecture](https://img.shields.io/badge/structure-modular-orange) ![Pipeline](https://img.shields.io/badge/pipeline-registry--driven-informational) ![PowerShell](https://img.shields.io/badge/powershell-automation-5391FE?logo=powershell&logoColor=white) ![License](https://img.shields.io/badge/license-MIT-green)

Custom registry-driven VS Code icon theme built through a fully automated PowerShell pipeline.

IconMatrix is designed to provide scalable, maintainable, and highly customizable file and folder icon mapping for Visual Studio Code. Rather than relying on manually maintained theme files, IconMatrix generates icon mappings dynamically from a structured registry and processing pipeline.

---

## Repository Structure

```text
IconMatrix/
├── Core/                      # Core processing and compilation logic
│   ├── Convert-Icons.ps1              # Converts source assets into standardized icon outputs
│   ├── Invoke-IconNormalization.ps1   # Normalizes naming and formatting
│   ├── Invoke-IconMatrixTheme.ps1     # Builds VS Code icon theme JSON
│   └── Sync-Icons.ps1                 # Main icon synchronization pipeline
│
├── pipeline/                 # Registry and orchestration logic
│   ├── Copy-SourceIcons.ps1          # Copies source icons into repository workspace
│   ├── Invoke-RegistryBuild.ps1      # Generates icon registry from processed assets
│   └── Clean-Build.ps1               # Build cleanup utilities
│
├── Tools/                    # User-facing orchestration scripts
│   ├── Publish-IconMatrix.ps1        # End-to-end build, package, and install workflow
│   ├── Reset-IconMatrix.ps1          # Environment reset tooling
│   └── <additional tools>            # Utility execution helpers
│
├── utils/                    # Shared helper functions
│   ├── Logging.ps1                   # Logging and output handling
│   ├── Hashing.ps1                   # Hash comparison utilities
│   ├── Naming.ps1                    # Naming normalization helpers
│   └── Invoke-ReviewReport.ps1       # Reporting and validation output
│
├── config/                   # Repository configuration
│   ├── paths.json                    # Centralized path configuration
│   └── <supporting config files>
│
├── registry/                 # Generated registry outputs
│   └── icons.json                    # Generated icon registry
│
├── theme/                    # VS Code theme output
│   └── icons-theme.json              # Generated VS Code icon theme
│
├── source-icons/             # Raw icon source assets
├── processed-icons/          # Converted/normalized icons
├── archive/                  # Legacy or historical scripts
├── logs/                     # Pipeline logging outputs
├── .vscodeignore             # Controls VSIX packaging contents
├── .gitignore                # Git exclusion rules
├── package.json              # VS Code extension manifest
├── LICENSE.txt               # Licensing information
└── README.md
```

---

## Purpose

This repository supports **VS Code extension automation and icon theme generation** by providing a structured, registry-driven pipeline for building, packaging, and installing a custom file icon theme.

The goal of IconMatrix is to:

* Eliminate manual icon theme maintenance
* Automate icon discovery and theme generation
* Provide centralized icon mapping management
* Enable repeatable VSIX packaging and installation
* Support long-term maintainability and customization

---

## Features

### Automated Build Pipeline

IconMatrix uses PowerShell orchestration to automate:

* Source icon ingestion
* Icon normalization
* Asset conversion
* Registry generation
* Theme compilation
* VSIX packaging
* Optional local installation into VS Code

### Registry-Driven Theme Generation

Instead of manually maintaining large JSON theme files, IconMatrix dynamically generates mappings using a structured registry model.

This enables:

* Easier maintenance
* Scalable icon expansion
* Consistent naming
* Reduced manual effort

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
   * Converts source assets into processed outputs
4. **Build Registry**
   * Generates dynamic icon registry
5. **Compile Theme**
   * Produces `theme/icons-theme.json`
6. **Package Extension**
   * Builds `.vsix` extension package
7. **Optional Install**
   * Installs directly into VS Code

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

This avoids hardcoded machine paths and enables portable execution across environments.

Example configuration:

```json
{
  "keypassIcons": "E:\\Users\\<user>\\Pictures\\Keypass_Icons",
  "repoRoot": "D:\\GitHub\\IconMatrix",
  "sourceIcons": "source-icons",
  "processedIcons": "processed-icons",
  "registry": "registry\\icons.json",
  "theme": "theme\\icons-theme.json",
  "logs": "logs"
}
```

---

## Current Status

### Completed

* Build orchestration
* DryRun execution model
* Registry generation
* Theme compilation
* VSIX packaging
* Automated installation
* `.vscodeignore` optimization
* Repository path abstraction

### In Progress

* File icon mapping refinement
* Extension/file association tuning
* Theme rendering validation
* Expanded icon coverage

---

## Security Notes

* No secrets or credentials are intentionally stored in this repository.
* Sensitive configuration files are excluded via `.gitignore`.
* VSIX packaging is restricted using `.vscodeignore`.
* Any accidental exposure should be remediated immediately.

---

## License

This repository is licensed under the terms defined in the LICENSE file.
