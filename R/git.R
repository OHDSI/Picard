
# Git Workflow Helpers for Picard Pipelines
# Functions to help users and agents manage version control:
# - saveWork(): User-friendly commit/push to feature branches
# - agentSaveWork(): Automated commits for agent-based workflows
# - createAgentBranch(): Create timestamped feature branches for agents
# - createPullRequest(): Log PR metadata for manual creation
# - validateCodeState(): Ensure clean code before major pipeline operations

# Helpers for internal use

check_git_status <- function() {
  tryCatch({
    status <- gert::git_status(staged = FALSE)
    nrow(status) > 0
  }, error = function(e) {
    cli::cli_abort("Failed to check git status: {e$message}")
  })
}

# Helper: Verify we're on main branch (for protection)
is_on_main <- function() {
  tryCatch({
    branch <- gert::git_branch()
    branch == "main"
  }, error = function(e) {
    cli::cli_abort("Failed to check current branch: {e$message}")
  })
}

# Helper: Get current branch name
get_current_branch <- function() {
  tryCatch({
    gert::git_branch()
  }, error = function(e) {
    cli::cli_abort("Failed to get current branch: {e$message}")
  })
}

# Helper: Add git remote and push initialization commit
git_remote_ulysses <- function(gitRemoteUrl, gitRemoteName = "origin") {
  commitMessage <- "Prep Ulysses repo with remote"
  
  tryCatch({
    # Stage all files
    gert::git_add(files = ".")
    
    # Commit all files with standard message
    gert::git_commit_all(message = commitMessage)
    
    # Add remote
    gert::git_remote_add(url = gitRemoteUrl, name = gitRemoteName)
    
    # Push to remote
    gert::git_push(remote = gitRemoteName)
    
    cli::cli_alert_success("Repository connected to remote: {gitRemoteUrl}")
  }, error = function(e) {
    cli::cli_alert_danger("Failed to connect to remote: {e$message}")
    stop(e)
  })
  
  invisible(gitRemoteUrl)
}

#' Validate Code State Before Pipeline Operations
#' @description Ensures the repository is in a clean state (no uncommitted changes)
#'   before running major pipeline operations. Returns the current commit SHA for
#'   audit/reproducibility tracking.
#' @return Character. Current commit SHA (invisible)
#' @keywords internal
validateCodeState <- function() {
  # Check for uncommitted changes
  if (check_git_status()) {
    cli::cli_abort(c(
      "Cannot proceed with uncommitted changes!",
      "i" = "Commit all work first with: {.code saveWork('message')}",
      "i" = "This ensures reproducibility and auditability"
    ))
  }

  # Get current commit SHA
  sha <- tryCatch({
    log <- gert::git_log()
    if (nrow(log) == 0) {
      cli::cli_abort("No commits found in repository")
    }
    log$commit[1]
  }, error = function(e) {
    cli::cli_abort("Failed to get git commit SHA: {e$message}")
  })

  cli::cli_alert_success("✓ Code state validated. Commit SHA: {.code {substr(sha, 1, 7)}}")
  return(invisible(sha))
}

#' Sync Local Work to Remote Branch
#' @description Commits and optionally pushes local changes to a specified feature branch.
#'   Automatically handles branch creation, pulling updates, and pushing changes.
#'   Users cannot sync to main branch—only feature branches allowed.
#' @param commitMessage Character. Descriptive message for the commit.
#' @param branch Character. Target branch name. Defaults to current branch.
#'   If branch doesn't exist, it will be created. Cannot be "main".
#' @param push Logical. If TRUE (default), pushes changes to remote after committing.
#'   If FALSE, changes are committed locally only. Useful for work-in-progress commits.
#' @param gitRemoteName Character. Remote name. Defaults to "origin".
#' @return Invisible TRUE on success
#' @export
#' @examples
#' \dontrun{
#' # Sync to current feature branch and push
#' saveWork("Add new validation checks to cohort manifest")
#'
#' # Commit locally without pushing (work-in-progress)
#' saveWork("WIP: Testing new approach", push = FALSE)
#'
#' # Sync to specific feature branch
#' saveWork("Update documentation", branch = "feature/docs-update")
#' }
saveWork <- function(commitMessage, branch = get_current_branch(), push = TRUE, gitRemoteName = "origin") {
  checkmate::assert_string(commitMessage, min.chars = 1)
  checkmate::assert_string(branch, min.chars = 1)
  checkmate::assert_logical(push, len = 1)
  checkmate::assert_string(gitRemoteName, min.chars = 1)

  cli::cli_rule("Sync Work to Remote")

  # Protection: prevent commits to main
  if (branch == "main") {
    cli::cli_abort(c(
      "Cannot commit to main branch!",
      "i" = "Main branch is protected. Create a feature branch instead.",
      "i" = "Example: {.code saveWork(msg, branch = 'feature/my-work')}"
    ))
  }

  # Check if we have changes to commit
  changes <- tryCatch({
    gert::git_status(staged = FALSE)
  }, error = function(e) {
    cli::cli_abort("Failed to check git status: {e$message}")
  })

  if (nrow(changes) == 0) {
    cli::cli_alert_info("No changes to commit on {.emph {branch}}")
    return(invisible(FALSE))
  }

  # Show user what will be committed
  cli::cli_alert_info("Found {nrow(changes)} file{?s} with changes:")
  for (file in changes$file) {
    status_icon <- dplyr::case_when(
      changes$status[changes$file == file] == "new" ~ "✚",
      changes$status[changes$file == file] == "modified" ~ "✎",
      changes$status[changes$file == file] == "deleted" ~ "✗",
      .default = "•"
    )
    cli::cli_bullets(c(" " = "{status_icon} {file}"))
  }

  # Confirm with user
  cli::cli_text("")
  response <- utils::askYesNo(
    paste("Commit these changes to", cli::style_bold(branch), "?"),
    default = FALSE
  )

  if (!response) {
    cli::cli_alert_warning("Commit cancelled.")
    return(invisible(FALSE))
  }

  # Ensure we're on the correct branch
  active_branch <- get_current_branch()
  if (active_branch != branch) {
    branch_exists <- tryCatch({
      gert::git_branch_exists(branch)
    }, error = function(e) FALSE)

    if (!branch_exists) {
      cli::cli_alert_info("Creating new branch: {.emph {branch}}")
      tryCatch({
        gert::git_branch_create(branch = branch, checkout = TRUE)
      }, error = function(e) {
        cli::cli_abort("Failed to create branch {.emph {branch}}: {e$message}")
      })
    } else {
      cli::cli_alert_info("Switching to existing branch: {.emph {branch}}")
      tryCatch({
        gert::git_branch_checkout(branch = branch)
      }, error = function(e) {
        cli::cli_abort("Failed to checkout branch {.emph {branch}}: {e$message}")
      })
    }
  }

  # Pull latest changes
  cli::cli_alert_info("Pulling latest changes from {.emph {gitRemoteName}/{branch}}")
  tryCatch({
    gert::git_pull(remote = gitRemoteName, refspec = branch)
  }, error = function(e) {
    cli::cli_alert_warning("Pull failed or no remote changes: {e$message}")
  })

  # Stage all changes
  cli::cli_alert_info("Staging files...")
  tryCatch({
    gert::git_add(files = ".")
  }, error = function(e) {
    cli::cli_abort("Failed to stage files: {e$message}")
  })

  # Commit
  sha <- tryCatch({
    gert::git_commit_all(message = commitMessage)
  }, error = function(e) {
    cli::cli_abort("Failed to commit: {e$message}")
  })

  cli::cli_alert_success("Committed {.code {substr(sha, 1, 7)}} to {.emph {branch}}")

  # Push to remote (conditionally)
  if (push) {
    cli::cli_alert_info("Pushing to {.emph {gitRemoteName}}")
    tryCatch({
      gert::git_push(remote = gitRemoteName, set_upstream = branch)
    }, error = function(e) {
      cli::cli_abort("Failed to push: {e$message}")
    })
    cli::cli_alert_success("✓ Work synced to {.emph {gitRemoteName}/{branch}}")
  } else {
    cli::cli_alert_info("Changes committed locally. Use {.code saveWork(..., push = TRUE)} to push to remote.")
  }

  invisible(TRUE)
}

#' Save Work for Agents (Automated, No Prompts)
#' @description Internal function for agent-based workflows. Commits and pushes
#'   changes without user interaction. Agent must be on feature/agent-* branch.
#' @param commitMessage Character. Commit message.
#' @param gitRemoteName Character. Remote name. Defaults to "origin".
#' @return Commit SHA hash
#' @keywords internal
#' @export
agentSaveWork <- function(commitMessage, gitRemoteName = "origin") {
  checkmate::assert_string(commitMessage, min.chars = 1)
  checkmate::assert_string(gitRemoteName, min.chars = 1)

  branch <- get_current_branch()

  # Verify we're on an agent branch
  if (!grepl("^feature/agent-", branch)) {
    cli::cli_abort(c(
      "Agent can only commit to feature/agent-* branches",
      "i" = "Current branch: {.code {branch}}"
    ))
  }

  # Stage and commit
  tryCatch({
    gert::git_add(files = ".")
    sha <- gert::git_commit_all(message = commitMessage)
    gert::git_push(remote = gitRemoteName)
    return(sha)
  }, error = function(e) {
    cli::cli_abort("Agent commit failed: {e$message}")
  })
}

#' Create Feature Branch for Agent Work
#' @description Creates a timestamped feature branch for automated agent-based
#'   pipeline improvements. Branch name format: feature/agent-{agentName}-{timestamp}
#' @param taskDescription Character. Brief description of the work to be done.
#' @param agentName Character. Name/identifier of the agent. Defaults to "auto".
#' @return Branch name (invisible)
#' @export
#' @examples
#' \dontrun{
#' # Create branch for agent optimization work
#' branch <- createAgentBranch(
#'   taskDescription = "Optimize post-processing pipeline",
#'   agentName = "capR-v1"
#' )
#' # Returns: feature/agent-capR-v1-20260325_143022
#' }
createAgentBranch <- function(taskDescription, agentName = "auto") {
  checkmate::assert_string(taskDescription, min.chars = 1)
  checkmate::assert_string(agentName, min.chars = 1)

  # Create branch name with timestamp
  timestamp <- format(Sys.time(), "%Y%m%d_%H%M%S")
  branch_name <- paste0("feature/agent-", agentName, "-", timestamp)

  cli::cli_rule("Create Agent Work Branch")
  cli::cli_alert_info("Task: {taskDescription}")
  cli::cli_alert_info("Creating branch: {.emph {branch_name}}")

  tryCatch({
    gert::git_branch_create(branch = branch_name, checkout = TRUE)
    cli::cli_alert_success("✓ Ready for agent work on {.emph {branch_name}}")
    return(invisible(branch_name))
  }, error = function(e) {
    cli::cli_abort("Failed to create branch: {e$message}")
  })
}

#' Create Pull Request Metadata
#' @description Prepares and logs metadata for a pull request from agent work.
#'   Returns structured information for PR creation.
#' @param branchName Character. Source feature branch.
#' @param title Character. PR title.
#' @param description Character. PR description (optional).
#' @param targetBranch Character. Target branch. Defaults to "main".
#' @return List with PR metadata 
#' @export
#' @examples
#' \dontrun{
#' # Create PR after agent work completes
#' pr <- createPullRequest(
#'   branchName = "feature/agent-capR-v1-20260325_143022",
#'   title = "Optimize post-processing pipeline",
#'   description = "Agent-generated improvements to export validation"
#' )
#' }
createPullRequest <- function(branchName, title, description = NULL, targetBranch = "main") {
  checkmate::assert_string(branchName, min.chars = 1)
  checkmate::assert_string(title, min.chars = 1)
  checkmate::assert_string(description, null.ok = TRUE)
  checkmate::assert_string(targetBranch, min.chars = 1)

  cli::cli_rule("Prepare Pull Request")

  # Validate branch exists
  branch_exists <- tryCatch({
    gert::git_branch_exists(branchName)
  }, error = function(e) FALSE)

  if (!branch_exists) {
    cli::cli_abort(c(
      "Branch {.code {branchName}} not found",
      "i" = "Create branch with {.code createAgentBranch()}"
    ))
  }

  # Log PR info
  cli::cli_alert_info("PR Title: {title}")
  cli::cli_alert_info("Source: {.emph {branchName}}")
  cli::cli_alert_info("Target: {.emph {targetBranch}}")

  if (!is.null(description)) {
    cli::cli_alert_info("Description provided")
  }

  cli::cli_alert_success("✓ PR metadata prepared")

  # Return PR info
  pr_meta <- list(
    branch = branchName,
    title = title,
    description = description,
    targetBranch = targetBranch,
    createdAt = Sys.time()
  )

  cli::cli_alert_info("Next: Create PR in your Git provider and merge after review")

  return(pr_meta)
}


#' @title Validate Release Branch Freshness
#' @description Checks whether the current branch includes the tip commit from
#'   the local \code{develop} branch, indicating that develop has been merged or
#'   rebased before creating the release. Issues a warning if the branch appears
#'   stale. Skips gracefully if \code{develop} does not exist locally or if
#'   the git history cannot be inspected.
#' @return Invisibly returns one of: \code{"fresh"}, \code{"stale"},
#'   \code{"no_develop"}, or \code{"error"}.
#' @keywords internal
validateReleaseBranchFreshness <- function() {
  tryCatch({
    branches <- gert::git_branch_list()
    local_develop <- branches[branches$name == "develop" & branches$local, ]

    if (nrow(local_develop) == 0) {
      return(invisible("no_develop"))
    }

    develop_commit <- local_develop$commit[1]

    # Look back up to 200 commits in current branch history
    current_log <- gert::git_log(max = 200)

    if (!develop_commit %in% current_log$commit) {
      return(invisible("stale"))
    }

    invisible("fresh")
  }, error = function(e) {
    invisible("error")
  })
}
