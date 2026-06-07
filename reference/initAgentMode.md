# Initialize or Restore Agent Mode for Cloned Repository

When a Picard repository is cloned, agent mode files (.gitignored) won't
be present. This function checks if agent mode is available and restores
it using metadata from existing repo files. Agent mode provides VS Code
Copilot with study context through copilot-instructions.md and reference
docs.

## Usage

``` r
initAgentMode(projectPath = here::here(), verbose = TRUE)
```

## Arguments

- projectPath:

  Character. Path to the Picard repository. Defaults to current working
  directory.

- verbose:

  Logical. Display informative messages during initialization. Default:
  TRUE

## Value

Invisibly returns a list with:

- `agent_mode_active`: Logical. TRUE if agent mode files are now
  available

- `files_created`: Character vector of files that were created/restored

- `already_existed`: Logical. TRUE if agent mode files already existed

## Details

Agent mode setup consists of:

- `.agent/` folder with reference documentation

- `copilot-instructions.md` at workspace root (auto-loaded by VS Code
  Copilot)

- `.agent/copilot-instructions.md` (backup/reference)

Study metadata is extracted from existing repo files:

- Study title and project name from README.md

- Tool type from config.yml

- Repository name from the repo folder name

## Examples

``` r
if (FALSE) { # \dontrun{
  # Restore agent mode in current repository
  initAgentMode()

  # Restore in specific repository
  initAgentMode(projectPath = "/path/to/study_repo")
} # }
```
