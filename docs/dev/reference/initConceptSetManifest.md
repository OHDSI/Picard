# Initialize a New Concept Set Manifest

Creates a blank `conceptSetManifest.sqlite` database with the new
schema.

## Usage

``` r
initConceptSetManifest(path = "inputs/conceptSets")
```

## Arguments

- path:

  Character. Path to the conceptSets folder. Defaults to
  `"inputs/conceptSets"`.

## Value

A `ConceptSetManifest` R6 object (empty, ready for `$add*()` calls).
