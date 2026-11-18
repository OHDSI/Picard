# Test whether a candidate manifest column value differs from the stored one

SQLite rewrites the pages it touches, so an `UPDATE` that assigns the
value a row already holds still changes the manifest file on disk (and
bumps `updated_at`), which surfaces as an uncommitted change in git.
Manifest writers use this to drop no-op assignments before issuing an
`UPDATE`.

## Usage

``` r
manifestValueUnchanged(newValue, storedValue)
```

## Arguments

- newValue:

  The value about to be written. `NULL`, zero-length, and `NA` are all
  treated as "no value".

- storedValue:

  The value currently held in the manifest row.

## Value

Logical. `TRUE` when the stored value already matches.
