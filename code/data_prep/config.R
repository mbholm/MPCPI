## =============================================================================
## config.R -- central configuration for the R stage of the replication package.
##
## Sourced by every R script in code/data_prep/ (and by run_all.R). It
## locates the replication root via the .repl_root sentinel (so scripts are
## robust to the working directory), defines the folder paths and sample
## windows, exposes the offline-fallback switch, and provides the assertion
## helpers used by the fetch and prep scripts.
##
## Folder layout (relative to the replication root):
##   inputs/          raw and supplied inputs (CPI tables, bridge matrix, firm statistics, ...)
##   data/            intermediate files consumed by Stata (.dta, .csv, .xlsx)
##   output/          Stata coefficient files and MATLAB figures
##   code/data_prep/  R scripts (this file)
##   code/stata/      Stata scripts       code/matlab/  MATLAB scripts
##   code/server/     script run on the SSB microdata server
##
## Usage inside a script:
##     if (!exists("REPL_ROOT")) source("config.R")
## When launched standalone, run R with the working directory set to
## code/data_prep/. When launched via run_all.R, REPL_ROOT is already
## defined and this is a no-op.
## =============================================================================

## --- locate the replication root via the .repl_root sentinel ------------------
.find_repl_root <- function(start = getwd()) {
  d <- normalizePath(start, winslash = "/", mustWork = FALSE)
  repeat {
    if (file.exists(file.path(d, ".repl_root"))) return(d)
    parent <- dirname(d)
    if (identical(parent, d)) {
      stop("Could not locate the replication root (no .repl_root found above '",
           start, "'). Start R inside the replication/ tree, or set the working ",
           "directory to replication/code/data_prep before sourcing config.R.")
    }
    d <- parent
  }
}

REPL_ROOT <- .find_repl_root()
INPUTS    <- file.path(REPL_ROOT, "inputs")
DATA_PREP <- INPUTS          # legacy name used by the fetch/prep scripts
DATA      <- file.path(REPL_ROOT, "data")
CODE      <- file.path(REPL_ROOT, "code")
CODE_R    <- file.path(CODE, "data_prep")
OUTPUT    <- file.path(REPL_ROOT, "output")

## --- sample windows (kept identical to the original static-file behaviour) ----
CPI_START   <- 2000L   # CPI series are fetched from 2000 (prep then filters to 2001+)
MACRO_START <- 1995L   # macro / national-accounts / rate series start
SAMPLE_END  <- 2018L   # all series end in December 2018

## --- offline fallback ---------------------------------------------------------
## Set environment variable REPL_USE_FALLBACK=1 to SKIP all API fetching and use
## the committed static input files instead. Default (0): fetch from the APIs.
USE_FALLBACK <- isTRUE(suppressWarnings(
  as.integer(Sys.getenv("REPL_USE_FALLBACK", "0"))) == 1L)

## --- assertion helpers --------------------------------------------------------
check_cols <- function(df, expected, what = "data") {
  missing <- setdiff(expected, names(df))
  if (length(missing)) {
    stop(sprintf("[%s] missing expected column(s): %s",
                 what, paste(missing, collapse = ", ")))
  }
  invisible(TRUE)
}

check_month_format <- function(x, what = "Month") {
  x <- as.character(x)
  bad <- x[!grepl("^[0-9]{4}M[0-9]{2}$", x)]
  if (length(bad)) {
    stop(sprintf("[%s] %d value(s) not in YYYYMmm form, e.g. '%s'",
                 what, length(bad), bad[1]))
  }
  invisible(TRUE)
}

check_quarter_format <- function(x, what = "Quarter") {
  x <- as.character(x)
  bad <- x[!grepl("^[0-9]{4}K[1-4]$", x)]
  if (length(bad)) {
    stop(sprintf("[%s] %d value(s) not in YYYYKq form, e.g. '%s'",
                 what, length(bad), bad[1]))
  }
  invisible(TRUE)
}

check_year_range <- function(years, lo, hi, what = "data") {
  years <- as.integer(years)
  ymin <- min(years, na.rm = TRUE); ymax <- max(years, na.rm = TRUE)
  if (ymin > lo || ymax < hi) {
    stop(sprintf("[%s] year coverage [%d, %d] does not span required [%d, %d]",
                 what, ymin, ymax, lo, hi))
  }
  invisible(TRUE)
}

check_nrow_at_least <- function(df, n, what = "data") {
  if (nrow(df) < n) {
    stop(sprintf("[%s] has %d rows, expected at least %d", what, nrow(df), n))
  }
  invisible(TRUE)
}

## Write only after validation: build into a temp file, then move into place.
safe_write <- function(write_fun, path) {
  tmp <- tempfile(tmpdir = dirname(path),
                  fileext = paste0(".", tools::file_ext(path)))
  on.exit(if (file.exists(tmp)) unlink(tmp), add = TRUE)
  write_fun(tmp)
  if (!file.exists(tmp)) stop("writer produced no file for ", path)
  file.copy(tmp, path, overwrite = TRUE)
  invisible(path)
}

message(sprintf("[config] REPL_ROOT = %s | USE_FALLBACK = %s",
                REPL_ROOT, USE_FALLBACK))
