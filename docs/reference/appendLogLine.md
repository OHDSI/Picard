# Append a milestone line to the pipeline log file (file only, never console). A no-op when `logFilePath` is NULL, so callers don't need to guard it.

Append a milestone line to the pipeline log file (file only, never
console). A no-op when `logFilePath` is NULL, so callers don't need to
guard it.

## Usage

``` r
appendLogLine(logFilePath, ...)
```
