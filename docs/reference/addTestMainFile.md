# Add Test Main File to Extras Folder

Creates test_main.R script in the extras folder for development
iteration. This provides a testing variant of the production pipeline
that uses testStudyPipeline().

## Usage

``` r
addTestMainFile(repoName, repoFolder, configBlocks, studyName)
```

## Arguments

- repoName:

  Character. Name of the repository.

- repoFolder:

  Character. Parent directory of the repository.

- configBlocks:

  List or Character vector. Database config blocks or block names.

- studyName:

  Character. Name of the study.
