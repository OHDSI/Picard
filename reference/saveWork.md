# Sync Local Work to Remote Branch

Commits and optionally pushes local changes to a specified feature
branch. Automatically handles branch creation, pulling updates, and
pushing changes. Users cannot sync to main branch—only feature branches
allowed.

## Usage

``` r
saveWork(
  commitMessage,
  branch = get_current_branch(),
  push = TRUE,
  gitRemoteName = "origin"
)
```

## Arguments

- commitMessage:

  Character. Descriptive message for the commit.

- branch:

  Character. Target branch name. Defaults to current branch. If branch
  doesn't exist, it will be created. Cannot be "main".

- push:

  Logical. If TRUE (default), pushes changes to remote after committing.
  If FALSE, changes are committed locally only. Useful for
  work-in-progress commits.

- gitRemoteName:

  Character. Remote name. Defaults to "origin".

## Value

Invisible TRUE on success

## Examples

``` r
if (FALSE) { # \dontrun{
# Sync to current feature branch and push
saveWork("Add new validation checks to cohort manifest")

# Commit locally without pushing (work-in-progress)
saveWork("WIP: Testing new approach", push = FALSE)

# Sync to specific feature branch
saveWork("Update documentation", branch = "feature/docs-update")
} # }
```
