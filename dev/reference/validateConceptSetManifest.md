# Validate Concept Set Manifest

Checks whether a concept set manifest SQLite database exists and
contains records. Absence of the manifest is not a blocking error — not
all studies use concept sets. Returns a status indicator for the
pre-flight orchestrator to interpret.

## Usage

``` r
validateConceptSetManifest(
  conceptSetsFolderPath = here::here("inputs/conceptSets")
)
```

## Arguments

- conceptSetsFolderPath:

  Character. Path to the concept sets folder. Defaults to
  "inputs/conceptSets" relative to the project root.

## Value

Invisibly returns "no_manifest", "empty", an integer record count, or
"error" depending on findings.
