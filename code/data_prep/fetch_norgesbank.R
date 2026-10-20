## fetch_norgesbank.R -- downloads the policy rate and exchange rates from the Norges Bank API; sources config.R.
## Run with the working directory set to replication/code/data_prep, or via ../../run_all.R.
## =============================================================================
## fetch_norgesbank.R -- download the Norges Bank inputs (NOT SSB) and regenerate
## the semicolon-delimited CSVs the Stata macro code reads by fixed column range.
##
## Produces in data/:
##   usdnok.csv            (USD/NOK monthly, Stata colrange 15:16 = TIME_PERIOD;OBS_VALUE)
##   i44.csv               (I-44 import-weighted index, monthly, colrange 15:16)
##   policy_rate_daily.csv (key policy rate, daily, colrange 12:13; date DD.MM.YYYY)
##
## Source: Norges Bank Data API (https://data.norges-bank.no/api/), SDMX. These are
## Norges Bank series, NOT Statistics Norway -- kept separate from fetch_ssb.R.
##
## Robustness: rather than try to reproduce Norges Bank's full bilingual column
## layout (which can change), we read the EXISTING committed CSV as a template
## (its header and one data row give the constant metadata columns and the exact
## positions of TIME_PERIOD / OBS_VALUE), fetch fresh observations, and re-emit the
## file with only TIME_PERIOD and OBS_VALUE replaced. This guarantees the Stata
## colrange(15:16)/(12:13) keep hitting the right columns. Requires the committed
## CSV to be present as the template (it also serves as the offline fallback).
## =============================================================================

if (!exists("REPL_ROOT")) source("config.R")

suppressPackageStartupMessages({
  library(httr2)
  library(dplyr)
  library(stringr)
})

## ----------------------------------------------------------------------------
## CONFIG -- confirm series keys against https://data.norges-bank.no/ if fetch fails
## ----------------------------------------------------------------------------
NB_BASE <- "https://data.norges-bank.no/api/data"

NB <- list(
  usdnok = list(file = "usdnok.csv",
                flow = "EXR", key = "M.USD.NOK.SP",   # monthly USD/NOK spot
                freq = "month"),
  i44    = list(file = "i44.csv",
                flow = "EXR", key = "M.I44.NOK.SP",   # monthly I-44 index
                freq = "month"),
  policy = list(file = "policy_rate_daily.csv",
                flow = "IR",  key = "B.KPRA.SD.R",    # daily key policy rate
                freq = "day")
)

START_PERIOD <- sprintf("%d-01", MACRO_START - 1L)  # a year of slack before 1995
END_PERIOD   <- sprintf("%d-12", SAMPLE_END)

## ----------------------------------------------------------------------------
## fetch observations (TIME_PERIOD, OBS_VALUE) from the Norges Bank API
## ----------------------------------------------------------------------------
nb_fetch_obs <- function(flow, key) {
  url <- sprintf("%s/%s/%s", NB_BASE, flow, key)
  resp <- request(url) |>
    req_url_query(format = "csv", startPeriod = START_PERIOD,
                  endPeriod = END_PERIOD, locale = "en") |>
    req_retry(max_tries = 3) |>
    req_timeout(120) |>
    req_perform()
  txt <- resp_body_string(resp)
  con <- textConnection(txt)
  on.exit(close(con))
  df <- utils::read.csv(con, sep = ";", dec = ".", check.names = FALSE,
                        colClasses = "character", stringsAsFactors = FALSE)
  tp <- grep("^TIME_PERIOD$", names(df), value = TRUE)
  ov <- grep("^OBS_VALUE$",   names(df), value = TRUE)
  if (!length(tp) || !length(ov))
    stop("Norges Bank CSV for ", flow, "/", key,
         " is missing TIME_PERIOD/OBS_VALUE columns (got: ",
         paste(names(df), collapse = ", "), ")")
  tibble::tibble(period = df[[tp[1]]], value = df[[ov[1]]]) |>
    filter(period != "", value != "")
}

## DD.MM.YYYY for daily, YYYY-MM for monthly -- matching the static files / Stata parsing
fmt_period <- function(period, freq) {
  if (freq == "month") return(substr(period, 1, 7))           # YYYY-MM
  d <- as.Date(period, format = "%Y-%m-%d")
  format(d, "%d.%m.%Y")                                        # DD.MM.YYYY
}

## ----------------------------------------------------------------------------
## re-emit a CSV using the committed file as a structural template
## ----------------------------------------------------------------------------
nb_rewrite_from_template <- function(spec) {
  path <- file.path(DATA, spec$file)
  if (!file.exists(path))
    stop("template/fallback CSV not found: ", path,
         " -- cannot preserve the Stata column layout without it.")
  lines <- readLines(path, warn = FALSE, encoding = "UTF-8")
  if (length(lines) < 2L) stop("template CSV too short: ", path)
  header <- lines[1]
  cols   <- strsplit(header, ";", fixed = TRUE)[[1]]
  ti <- which(cols == "TIME_PERIOD"); vi <- which(cols == "OBS_VALUE")
  if (!length(ti) || !length(vi))
    stop("TIME_PERIOD/OBS_VALUE not found in template header of ", spec$file)
  ti <- ti[1]; vi <- vi[1]
  template_row <- strsplit(lines[2], ";", fixed = TRUE)[[1]]
  ## pad the template row to full width if the last fields were empty/trimmed
  if (length(template_row) < length(cols))
    template_row <- c(template_row, rep("", length(cols) - length(template_row)))

  obs <- nb_fetch_obs(spec$flow, spec$key)
  obs$period <- fmt_period(obs$period, spec$freq)
  ## sanity: coverage and column positions match what Stata assumes. Use if/else
  ## (not ifelse) so the year is extracted from the whole vector: month periods are
  ## "YYYY-MM" (year = chars 1-4), daily periods "DD.MM.YYYY" (year = chars 7-10).
  yrs <- if (spec$freq == "month") {
    as.integer(substr(obs$period, 1, 4))
  } else {
    as.integer(substr(obs$period, 7, 10))
  }
  check_year_range(yrs, MACRO_START, SAMPLE_END, what = paste0("NB ", spec$file))
  if (spec$freq == "month" && (ti != 15 || vi != 16))
    warning(sprintf("[nb] %s: TIME_PERIOD/OBS_VALUE at cols %d/%d, Stata expects 15/16",
                    spec$file, ti, vi))
  if (spec$freq == "day" && (ti != 12 || vi != 13))
    warning(sprintf("[nb] %s: TIME_PERIOD/OBS_VALUE at cols %d/%d, Stata expects 12/13",
                    spec$file, ti, vi))

  rows <- vapply(seq_len(nrow(obs)), function(i) {
    r <- template_row
    r[ti] <- obs$period[i]
    r[vi] <- obs$value[i]
    paste(r, collapse = ";")
  }, character(1))

  out <- c(header, rows)
  safe_write(function(p) writeLines(out, p, useBytes = TRUE), path)
  message(sprintf("[nb] wrote %s (%d obs, %s)", spec$file, nrow(obs), spec$freq))
}

## ----------------------------------------------------------------------------
## main
## ----------------------------------------------------------------------------
fetch_norgesbank_all <- function() {
  if (isTRUE(USE_FALLBACK)) {
    message("[nb] REPL_USE_FALLBACK=1 -> skipping Norges Bank fetch, using static files.")
    return(invisible(NULL))
  }
  for (spec in NB) nb_rewrite_from_template(spec)
  message("[nb] all Norges Bank inputs refreshed.")
}

if (sys.nframe() == 0L || identical(environment(), globalenv())) {
  fetch_norgesbank_all()
}
