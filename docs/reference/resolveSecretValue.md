# Resolve a single secret value

If the value is a plain string (no `!expr` prefix), return it as-is. If
it starts with `!expr `, strip the prefix and evaluate the remaining R
expression using
[`rlang::eval_tidy()`](https://rlang.r-lib.org/reference/eval_tidy.html).
This supports any valid R expression: `keyring::key_get(...)`,
`Sys.getenv(...)`, custom functions, etc.

## Usage

``` r
resolveSecretValue(value)
```

## Arguments

- value:

  A single value from a parsed secrets YAML file.

## Value

The resolved value (plain string or evaluated expression result).
