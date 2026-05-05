# Create Feature Branch for Agent Work

Creates a timestamped feature branch for automated agent-based pipeline
improvements. Branch name format: feature/agent-agentName-timestamp

## Usage

``` r
createAgentBranch(taskDescription, agentName = "auto")
```

## Arguments

- taskDescription:

  Character. Brief description of the work to be done.

- agentName:

  Character. Name/identifier of the agent. Defaults to "auto".

## Value

Branch name (invisible)

## Examples

``` r
if (FALSE) { # \dontrun{
# Create branch for agent optimization work
branch <- createAgentBranch(
  taskDescription = "Optimize post-processing pipeline",
  agentName = "capR-v1"
)
# Returns: feature/agent-capR-v1-20260325_143022
} # }
```
