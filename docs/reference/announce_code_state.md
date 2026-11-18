# Announce a Non-Clean Code State

Prints a loud banner naming the ignored paths and files whenever the
pre-flight code-state check passed only because changes were ignored, or
because the check was skipped outright. Silent when the tree was clean.

## Usage

``` r
announce_code_state(codeState)
```

## Arguments

- codeState:

  List as returned by
  [`code_state_check()`](https://ohdsi.github.io/Picard/reference/code_state_check.md).

## Value

Invisibly NULL.
