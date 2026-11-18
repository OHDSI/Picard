# Create Pull Request Metadata

Prepares and logs metadata for a pull request from agent work. Returns
structured information for PR creation.

## Usage

``` r
createPullRequest(branchName, title, description = NULL, targetBranch = "main")
```

## Arguments

- branchName:

  Character. Source feature branch.

- title:

  Character. PR title.

- description:

  Character. PR description (optional).

- targetBranch:

  Character. Target branch. Defaults to "main".

## Value

List with PR metadata

## Examples

``` r
if (FALSE) { # \dontrun{
# Create PR after agent work completes
pr <- createPullRequest(
  branchName = "feature/agent-capR-v1-20260325_143022",
  title = "Optimize post-processing pipeline",
  description = "Agent-generated improvements to export validation"
)
} # }
```
