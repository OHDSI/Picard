# Run the Code State Pre-flight Check

Resolves the "Code state" pre-flight check into a checklist entry plus a
`codeState` provenance record that downstream code writes to the run
history. Split out of
[`runPreflightChecks()`](https://ohdsi.github.io/Picard/reference/runPreflightChecks.md)
so the escape-hatch logic is testable on its own.

A run that passes only because changes were ignored, or because the
check was skipped, is reported as a **warning** rather than a pass or a
silent skip — an escape hatch that hides itself is worse than no escape
hatch.

## Usage

``` r
code_state_check(
  testMode = FALSE,
  skipCodeStateCheck = FALSE,
  ignoreUncommittedPaths = character(0)
)
```

## Arguments

- testMode:

  Logical. TRUE when running the pipeline in test mode.

- skipCodeStateCheck:

  Logical. TRUE to skip the check entirely.

- ignoreUncommittedPaths:

  Character vector of repo-relative paths whose uncommitted changes do
  not fail the check.

## Value

A list with `status` ("pass", "warn", "fail" or "skip"), `message` for
the checklist line, and `codeState`.
