## Submission comments

This is a new submission.

## Test environments

* local Ubuntu 22.04 (via rocker/r-ver:4.4.0 container), R 4.4.0
* win-builder (devel and release)

## R CMD check results

0 errors | 0 warnings | 1 note

* checking CRAN incoming feasibility ... NOTE
  Maintainer: 'Nichodemus Amollo <nichodemuswerre@gmail.com>'
  New submission

## Notes for the reviewer

* Software and format names in the Description field ('REDCap', 'Stata',
  'SPSS') are quoted as required.

* Examples that would need a live PostgreSQL server or network access are
  wrapped in `\dontrun{}`. Examples that depend on packages listed only in
  Suggests are guarded with `requireNamespace()`.

* All examples and tests that write files write only to `tempdir()` and clean
  up after themselves.
