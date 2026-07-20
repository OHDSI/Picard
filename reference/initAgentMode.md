# Initialize or Restore Agent Mode for Cloned Repository

When a Picard repository is cloned, agent mode files (.gitignored) won't
be present. This function checks if agent mode is available and restores
it using metadata from existing repo files. Agent mode provides any
coding agent (Claude Code, GitHub Copilot, Cursor, etc.) with study
context through a root AGENTS.md file plus reference docs and skills in
`.agent/`.

## Usage

``` r
initAgentMode(projectPath = here::here(), verbose = TRUE, reset = FALSE)
```

## Arguments

- projectPath:

  Character. Path to the Picard repository. Defaults to current working
  directory.

- verbose:

  Logical. Display informative messages during initialization. Default:
  TRUE

- reset:

  Logical. If TRUE, replace any existing agent files with fresh copies
  from the installed picard (and Capr) version. This deletes `AGENTS.md`
  and the entire `.agent/` folder — including any custom files added
  there — before rewriting them. Use after upgrading picard to pick up
  new or relocated agent files. Default: FALSE

## Value

Invisibly returns a list with:

- `agent_mode_active`: Logical. TRUE if agent mode files are now
  available

- `files_created`: Character vector of files that were created/restored

- `files_removed`: Character vector of legacy agent files that were
  deleted

- `already_existed`: Logical. TRUE if agent mode files already existed

## Details

Agent mode setup consists of:

- `AGENTS.md` at the workspace root (tool-agnostic agent instructions)

- `.agent/reference-docs/` with detailed study-framework documentation

- `.agent/skills/` with task-specific skills, including
  `picard-capr-cohorts` and, when the Capr package is installed, its
  `capr-cohort-generation` skill bundle

Study metadata is extracted from existing repo files:

- Study title and project name from README.md

- Tool type from config.yml

- Repository name from the repo folder name

Repositories created with picard versions before the `.agent/` layout
(which used `copilot-instructions.md` and `.github/reference-docs/`) are
migrated automatically: the legacy files and their `.gitignore` entries
are removed whenever this function writes the new layout, and
`.agent/`/`AGENTS.md` are added to `.gitignore` if missing.

## Examples

``` r
if (FALSE) { # \dontrun{
  # Restore agent mode in current repository
  initAgentMode()

  # Restore in specific repository
  initAgentMode(projectPath = "/path/to/study_repo")

  # After upgrading picard, refresh agent files to the installed version
  initAgentMode(reset = TRUE)
} # }
```
