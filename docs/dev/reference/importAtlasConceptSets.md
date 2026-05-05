# Import CIRCE Concept Sets from ATLAS

**Deprecated.** Use
[ConceptSetManifest](https://ohdsi.github.io/Picard/dev/reference/ConceptSetManifest.md)`$importAtlasConceptSets()`
instead.

## Usage

``` r
importAtlasConceptSets(
  conceptSetsFolderPath = here::here("inputs/conceptSets"),
  atlasConnection
)
```

## Arguments

- conceptSetsFolderPath:

  Character. Path to conceptSets folder.

- atlasConnection:

  An ATLAS connection object.

## Value

Invisibly returns the updated concept set load dataframe.
