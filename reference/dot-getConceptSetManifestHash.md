# Get Concept Set Manifest Hash

Returns
[ConceptSetManifest\$getManifestHash()](https://ohdsi.github.io/Picard/reference/ConceptSetManifest.md)
for the study's concept set manifest. Used by
[`shouldRerunTask()`](https://ohdsi.github.io/Picard/reference/shouldRerunTask.md)
to detect concept set changes (including label/category/tag changes)
that require a task rerun.

## Usage

``` r
.getConceptSetManifestHash(projectPath = here::here())
```

## Arguments

- projectPath:

  Character. A path inside the study repository. Defaults to the current
  project
  ([`here::here()`](https://here.r-lib.org/reference/here.html)).

## Value

Character. SHA256 hex digest, `"<no-concept-set-manifest>"`, or
`NA_character_` if the manifest cannot be read.

## Details

Concept sets are optional, so a study without a concept set manifest
hashes to a stable sentinel rather than `NA` (which would force a rerun
on every pipeline run). Any failure to read an existing manifest returns
`NA_character_`, which
[`shouldRerunTask()`](https://ohdsi.github.io/Picard/reference/shouldRerunTask.md)
treats as "cannot prove unchanged" and forces the rerun.
