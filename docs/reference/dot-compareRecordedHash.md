# Compare a Current Hash Against the Recorded One

Fail-safe comparison shared by the input/environment checks in
[`shouldRerunTask()`](https://ohdsi.github.io/Picard/reference/shouldRerunTask.md).
A rerun is required when the current hash cannot be computed, when no
hash was recorded on the previous run (first run, or a history row
written before the column existed), or when the hashes differ.

## Usage

``` r
.compareRecordedHash(current, previous, name)
```

## Arguments

- current:

  Character or NULL. The hash computed for this run.

- previous:

  Character or NULL. The hash recorded on the previous run.

- name:

  Character. Human-readable name used in the rerun reason.

## Value

Character. A rerun reason, or `character(0)` when unchanged.
