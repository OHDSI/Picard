# Plot Cohort Dependency Graph

Generates a mermaid `graph TD` diagram showing how cohorts in a
[CohortManifest](https://ohdsi.github.io/Picard/dev/reference/CohortManifest.md)
depend on each other. Dependency data is read directly from the SQLite
manifest database — no sidecar JSON files required.

Prints the mermaid string to the console (renders automatically in
RStudio, Quarto, and GitHub markdown) and returns it invisibly.

## Usage

``` r
plotCohortGraph(manifest)
```

## Arguments

- manifest:

  A
  [CohortManifest](https://ohdsi.github.io/Picard/dev/reference/CohortManifest.md)
  R6 object.

## Value

Character. The mermaid diagram string (invisibly).

## Details

**Node shapes by cohort type:**

- Rectangle `[label]` — circe (base) cohort

- Circle `(label)` — subset cohort

- Diamond `{{label}}` — union cohort

- Hexagon `{{{{label}}}}` — complement / composite cohort

Arrows show dependency direction: parent → dependent cohort.

For a tabular view of derived cohorts and their rule parameters, see
[CohortManifest](https://ohdsi.github.io/Picard/dev/reference/CohortManifest.md)`$reviewDependentCohorts()`.
