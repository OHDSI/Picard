# This function takes the README and NEWS md files and updates to qmd for rendering
knitIndexAndNews <- function(projectPath) {

  # copy readme to index file
  readMeQmd <- readr::read_lines(
    file = fs::path(projectPath, "README.md")
  )

  writeFileAndNotify(
    x = readMeQmd,
    repoPath = fs::path(projectPath, "dissemination/quarto"),
    fileName = "index.qmd"
  )

  # copy news to
  newsQmd <- readr::read_lines(
    file = fs::path(projectPath, "NEWS.md")
  )
  writeFileAndNotify(
    x = newsQmd,
    repoPath = fs::path(projectPath, "dissemination/quarto"),
    fileName = "news.qmd"
  )
  invisible(projectPath)
}


initStudyHubFiles <- function(repoName,
                              repoFolder,
                              studyTitle,
                              foregroundColor = "#00E47C",
                              backgroundColor = "#08312A") {

  repoPath <- fs::path(repoFolder, repoName) |>
    fs::path_expand()

  ## Make folders for quarto
  foldersToCreate <- c("R", "images")
  fs::dir_create(
    fs::path(repoPath, "dissemination/quarto", foldersToCreate)
  )
  # add key files
  egp <- readr::read_file(
    file = fs::path_package("picard", "templates/EGP.qmd")
  ) |>
    glue::glue(.open = "<<", .close = ">>")

  writeFileAndNotify(
    x = egp,
    repoPath = fs::path(repoPath, "dissemination/quarto"),
    fileName = "egp.qmd"
  )

  # set upd hub quarto
  hubQuarto <- fs::path_package("picard", "templates/quartoWebsite.yml") |>
    readr::read_file() |>
    glue::glue()

  writeFileAndNotify(
    x = hubQuarto,
    repoPath = fs::path(repoPath, "dissemination/quarto"),
    fileName = "_quarto.yml"
  )

  resultsFile <- readr::read_file(
    file = fs::path_package("picard", "templates/resultsFile.qmd")
  ) |>
    glue::glue(.open = "<<", .close = ">>")

  writeFileAndNotify(
    x = resultsFile,
    repoPath = fs::path(repoPath, "dissemination/quarto"),
    fileName = "results.qmd"
  )

  # setup quarto css file
  cssFile <- fs::path_package("picard", "templates/style.css") |>
    readr::read_file() |>
    glue::glue(.open = "${", .close = "}")

  writeFileAndNotify(
    x = cssFile,
    repoPath = fs::path(repoPath, "dissemination/quarto"),
    fileName = "style.css"
  )

  # update index and news
  knitIndexAndNews(projectPath = repoPath)

  # done
  invisible(repoPath)
}

#' @title Build Study Hub
#' @param projectPath the path to the Ulysses repo, by default takes the path of the active R project
#' @param previewHub toggle to preview the hub after it builds. Default is TRUE
#' @returns invisible return. Creates _site folder with html files to preview site
#' @export
buildStudyHub <- function(projectPath = here::here(), previewHub = TRUE) {

  cli::cat_rule("Build Study Hub")

  cli::cat_bullet("Update Index and NEWS files", bullet = "info", bullet_col = "blue")
  knitIndexAndNews(projectPath)

  docsPath <- fs::path(projectPath, "dissemination/quarto") |>
    fs::path_expand()

  cli::cat_bullet("Render Study Hub", bullet = "info", bullet_col = "blue")
  quarto::quarto_render(
    input = docsPath,
    as_job = FALSE
  )

  if (previewHub) {
    indexFilePath <- fs::path(projectPath, "dissemination/quarto/_site/index.html")
    #check <- fs::file_exists(indexFilePath)
    cli::cat_bullet("Preview Study Hub", bullet = "pointer", bullet_col = "yellow")
    #launch preview
    utils::browseURL(indexFilePath)
  }

  invisible(docsPath)

}

#' @title Publish Study Hub to Posit Connect
#' @description Builds a Study Hub and publishes it to Posit Connect through
#'   Quarto's public publishing API.
#' @param projectPath Character. Path to the Ulysses study repository. Defaults to
#'   the active project.
#' @param server Character. Posit Connect server hostname.
#' @param account Character or NULL. Optional Posit Connect account. If NULL,
#'   the destination resolver selects the configured account.
#' @param appName Character or NULL. Optional application name passed to Quarto
#'   as `name`. When NULL, Quarto derives the name from the project directory.
#' @param appTitle Character or NULL. Optional display title on Posit Connect,
#'   passed to Quarto as `title`.
#' @param render Character. Quarto render mode: `"local"`, `"server"`, or
#'   `"none"`. Defaults to `"local"`.
#' @param metadata Named list. Optional metadata passed to the Posit Connect
#'   deployment.
#' @param noBrowser Logical. If TRUE, prevents Quarto from opening a browser
#'   after publishing. Defaults to TRUE.
#' @return Invisibly returns the Study Hub project path.
#' @export
publishStudyHubPosit <- function(projectPath = here::here(),
                            server,
                            account = NULL,
                            appName = NULL,
                            appTitle = NULL,
                            render = "local",
                            metadata = list(),
                            noBrowser = TRUE) {
  if (!requireNamespace("quarto", quietly = TRUE)) {
    cli::cli_abort(c(
      "Package {.pkg quarto} is required to publish a Study Hub.",
      i = "Install it with {.code install.packages('quarto')}."
    ))
  }

  checkmate::assert_string(projectPath, min.chars = 1)
  checkmate::assert_string(server, min.chars = 1)
  checkmate::assert_string(account, min.chars = 1, null.ok = TRUE)
  checkmate::assert_string(appName, min.chars = 1, null.ok = TRUE)
  checkmate::assert_string(appTitle, min.chars = 1, null.ok = TRUE)
  checkmate::assert_choice(render, choices = c("local", "server", "none"))
  checkmate::assert_list(metadata, names = "named")
  checkmate::assert_flag(noBrowser)

  projectPath <- fs::path_expand(projectPath)
  docsPath <- fs::path(projectPath, "dissemination/quarto")
  if (!fs::dir_exists(docsPath)) {
    cli::cli_abort("Study Hub directory not found: {.path {docsPath}}")
  }

  cli::cli_rule("Publish Study Hub")
  knitIndexAndNews(projectPath)
  cli::cli_alert_info("Publishing Study Hub from {.path {fs::path_rel(docsPath)}}")

  publish_args <- list(
    input = docsPath,
    name = appName,
    title = appTitle,
    server = server,
    account = account,
    render = render,
    metadata = metadata,
    launch.browser = !noBrowser
  )

  do.call(quarto::quarto_publish_site, publish_args)

  cli::cli_alert_success("Study Hub published to {.val {server}}")
  invisible(docsPath)
}
