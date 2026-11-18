# Validate Code State Before Pipeline Operations

Ensures the repository is in a clean state before running major pipeline
operations, and reports the current commit SHA for audit/reproducibility
tracking.

Uncommitted changes confined to `ignorePaths` do not block execution.
This is the supported escape hatch for study repositories whose
`inputs/` folder churns without a deliberate edit (manifest sqlite files
rewritten on re-import, ATLAS-sourced JSON refetched). Changes anywhere
else - notably `analysis/` - still abort. The default ignores nothing,
so behaviour is unchanged unless a study opts in.

## Usage

``` r
validateCodeState(ignorePaths = character(0))
```

## Arguments

- ignorePaths:

  Character vector of repo-relative folder or file paths whose
  uncommitted changes should not block execution. Defaults to
  `character(0)`, i.e. any uncommitted change blocks.

## Value

Invisibly, a list with:

- `sha` - the HEAD commit SHA,

- `status` - `"clean"` when the working tree had no uncommitted changes,
  `"dirty-ignored"` when it did but every change fell inside
  `ignorePaths`,

- `clean` - logical, `TRUE` only when the tree was genuinely clean,

- `ignoredFiles` - the uncommitted files that were tolerated,

- `ignorePaths` - the normalized paths that were honoured.
