# Visualize Cohort Dependencies (Deprecated)

**Deprecated.** Use
[`plotCohortGraph()`](https://ohdsi.github.io/Picard/dev/reference/plotCohortGraph.md)
for a mermaid dependency diagram and
[CohortManifest](https://ohdsi.github.io/Picard/dev/reference/CohortManifest.md)`$reviewDependentCohorts()`
for a tabular dependency summary.

## Usage

``` r
visualizeCohortDependencies(manifest, outputPath = NULL)
```

## Arguments

- manifest:

  A CohortManifest object.

- outputPath:

  Character. Optional path to save the markdown report. Defaults to
  NULL.

## Value

Character. The markdown report content (invisibly).
