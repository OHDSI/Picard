# Clear Pending PR Reference

Removes the PENDING_PR.md file after PR has been created and merged.
Safe to call even if file doesn't exist.

## Usage

``` r
clearPendingPR()
```

## Value

Logical. TRUE if file was deleted, FALSE if it didn't exist

## Examples

``` r
if (FALSE) { # \dontrun{
# After merging PR to main
clearPendingPR()
} # }
```
