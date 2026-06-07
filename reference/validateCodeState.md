# Validate Code State Before Pipeline Operations

Ensures the repository is in a clean state (no uncommitted changes)
before running major pipeline operations. Returns the current commit SHA
for audit/reproducibility tracking.

## Usage

``` r
validateCodeState()
```

## Value

Character. Current commit SHA (invisible)
