# Publish Study Hub to Posit Connect

Builds a Study Hub and publishes it to Posit Connect through Quarto's
public publishing API.

## Usage

``` r
publishStudyHubPosit(
  projectPath = here::here(),
  server,
  account = NULL,
  appName = NULL,
  appTitle = NULL,
  render = "local",
  metadata = list(),
  noBrowser = TRUE
)
```

## Arguments

- projectPath:

  Character. Path to the Ulysses study repository. Defaults to the
  active project.

- server:

  Character. Posit Connect server hostname.

- account:

  Character or NULL. Optional Posit Connect account. If NULL, the
  destination resolver selects the configured account.

- appName:

  Character or NULL. Optional application name passed to Quarto as
  `name`. When NULL, Quarto derives the name from the project directory.

- appTitle:

  Character or NULL. Optional display title on Posit Connect, passed to
  Quarto as `title`.

- render:

  Character. Quarto render mode: `"local"`, `"server"`, or `"none"`.
  Defaults to `"local"`.

- metadata:

  Named list. Optional metadata passed to the Posit Connect deployment.

- noBrowser:

  Logical. If TRUE, prevents Quarto from opening a browser after
  publishing. Defaults to TRUE.

## Value

Invisibly returns the Study Hub project path.
