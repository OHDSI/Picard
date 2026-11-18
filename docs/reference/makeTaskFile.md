# Function initializing an R file for an analysis task

Function initializing an R file for an analysis task

## Usage

``` r
makeTaskFile(
  nameOfTask,
  author = NULL,
  description = NULL,
  projectPath = here::here(),
  openFile = TRUE
)
```

## Arguments

- nameOfTask:

  The name of the analysis task script

- author:

  the name of the person authoring the file. Defaults to template text
  if NULL

- description:

  a description of the analysis task. Defaults to template text if NULL

- projectPath:

  the path to the project

- openFile:

  toggle on whether the file should be opened
