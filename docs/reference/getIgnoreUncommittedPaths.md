# Read Configured Code-State Ignore Paths

Reads `ignoreUncommittedPaths` from the study's config.yml. The setting
lives in the `default:` block (alongside `projectName` and `version`)
and lists repo-relative paths whose uncommitted changes should not fail
the "Code state" pre-flight check.

Putting the list in config.yml keeps it version-controlled and
reviewable: the same incidental churn recurs on every run, so it is a
property of the study, not of one invocation.

## Usage

``` r
getIgnoreUncommittedPaths(configFilePath = "config.yml")
```

## Arguments

- configFilePath:

  Character. Path to config.yml. Defaults to "config.yml" in the working
  directory.

## Value

Character vector of paths. `character(0)` when the file is absent,
unparseable, or the setting is not present — so the default is to ignore
nothing.

## Examples

``` r
if (FALSE) { # \dontrun{
# config.yml
# default:
#   projectName: myStudy
#   version: 1.0.0
#   ignoreUncommittedPaths:
#     - inputs
getIgnoreUncommittedPaths()
} # }
```
