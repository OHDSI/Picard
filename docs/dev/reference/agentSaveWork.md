# Save Work for Agents (Automated, No Prompts)

Internal function for agent-based workflows. Commits and pushes changes
without user interaction. Agent must be on feature/agent-\* branch.

## Usage

``` r
agentSaveWork(commitMessage, gitRemoteName = "origin")
```

## Arguments

- commitMessage:

  Character. Commit message.

- gitRemoteName:

  Character. Remote name. Defaults to "origin".

## Value

Commit SHA hash
