# Create a Subset End Window Operator

Convenience wrapper to create a SubsetWindowOperator for defining the
temporal window for a subset cohort's end date relative to the filter
cohort event.

## Usage

``` r
createSubsetEndWindow(
  subsetCohortWindowAnchor,
  startDays,
  endDays,
  baseCohortWindowAnchor = "cohort_end_date"
)
```

## Arguments

- subsetCohortWindowAnchor:

  Character. Whether to anchor to the filter cohort's
  'cohort_start_date' or 'cohort_end_date'. Determines which date from
  the filter cohort event is used as the reference point.

- startDays:

  Integer. The number of days from the base cohort anchor to the start
  of the window. Negative values indicate days before the base cohort
  date.

- endDays:

  Integer. The number of days from the base cohort anchor to the end of
  the window. Negative values indicate days before the base cohort date.

- baseCohortWindowAnchor:

  Character. Whether to anchor the window to the base cohort's
  'cohort_start_date' or 'cohort_end_date'. Default: 'cohort_end_date'.

## Value

A SubsetWindowOperator object configured for end window filtering.

## Examples

``` r
# Create an end window: filter cohort must end within 0 to 90 days
# after the base cohort end date
end_w <- createSubsetEndWindow(
  subsetCohortWindowAnchor = "cohort_end_date",
  startDays = 0,
  endDays = 90,
  baseCohortWindowAnchor = "cohort_end_date"
)
```
