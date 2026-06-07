# Make Ulysses Study Settings

Make Ulysses Study Settings

## Usage

``` r
makeUlyssesStudySettings(
  repoName,
  repoFolder,
  studyMeta,
  dbConnectionBlocks = NULL,
  gitRemote = NULL,
  renvLockFile = NULL
)
```

## Arguments

- repoName:

  the name of repo as a character string

- repoFolder:

  the folder path where the repo is stored in local as a character
  string

- studyMeta:

  a StudyMeta R6 class with the details describing the study

- dbConnectionBlocks:

  a list of DbConfigBlock R6 classes specifying the databases to connect
  (optional)

- gitRemote:

  a remote url used to clone and set remote git

- renvLockFile:

  file path to a renvLockFile file

## Value

A UlyssesStudy R6 class with the ulysses study details to make
