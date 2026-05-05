# Validate Ulysses Repository Structure

Checks that a directory is a valid Ulysses-style repository with all
required files and folders.

## Usage

``` r
validateUlyssesStructure(path = NULL)
```

## Arguments

- path:

  Character. Path to the repository to validate. If NULL (default), uses
  the current working directory.

## Value

List with validation results containing:

- is_valid: Logical. TRUE if all requirements met

- path: Character. Path that was validated

- required_files: Data frame with required files and their status

- required_dirs: Data frame with required directories and their status

- summary: Character. Summary message

## Details

A valid Ulysses repository must contain:

- README.md file

- NEWS.md file

- config.yml file

- \*.Rproj file (R project file)

- analysis/ directory

## Examples

``` r
if (FALSE) { # \dontrun{
  validateUlyssesStructure()  # Check current directory
  validateUlyssesStructure("/path/to/repo")  # Check specific directory
} # }
```
