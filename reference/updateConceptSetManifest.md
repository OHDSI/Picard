# Update a Concept Set in the Manifest

Updates metadata (label, category, and/or tags) for a concept set in the
ConceptSetManifest.

## Usage

``` r
updateConceptSetManifest(
  manifest,
  conceptSetId,
  label = NULL,
  category = NULL,
  tags = NULL
)
```

## Arguments

- manifest:

  A ConceptSetManifest object.

- conceptSetId:

  Integer. The ID of the concept set to update.

- label:

  Character. New label for the concept set. If NULL (default), label is
  not updated.

- category:

  Character. New category for the concept set. If NULL (default),
  category is not updated. Valid values: "drug_exposure",
  "condition_occurrence", "measurement", "procedure", "observation",
  "device_exposure", "visit_occurrence", "init".

- tags:

  List. New tags (named list) for the concept set. If NULL (default),
  tags are not updated.

## Value

Invisibly returns NULL. Prints a success message if the update succeeds.

## Examples

``` r
if (FALSE) { # \dontrun{
  manifest <- loadConceptSetManifest()
  updateConceptSetManifest(manifest, 1, label = "Updated Label")
  updateConceptSetManifest(manifest, 2, category = "measurement")
  updateConceptSetManifest(manifest, 3, tags = list(source = "ATLAS", version = "2"))
} # }
```
