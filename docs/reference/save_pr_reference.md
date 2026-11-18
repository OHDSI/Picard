# Save PR Reference Information

Internal function that writes PR metadata to PENDING_PR.md for manual PR
creation. Saves branch name, target, title, and description for user
reference.

## Usage

``` r
save_pr_reference(prMeta)
```

## Arguments

- prMeta:

  List. PR metadata from createPullRequest()
