# Validate Release Branch Freshness

Checks whether the current branch includes the tip commit from the local
`develop` branch, indicating that develop has been merged or rebased
before creating the release. Issues a warning if the branch appears
stale. Skips gracefully if `develop` does not exist locally or if the
git history cannot be inspected.

## Usage

``` r
validateReleaseBranchFreshness()
```

## Value

Invisibly returns one of: `"fresh"`, `"stale"`, `"no_develop"`, or
`"error"`.
