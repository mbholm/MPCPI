## fetch_ssb.R -- downloads CPI tables, core inflation indices and national-accounts wage data from the Statistics Norway PxWeb API; sources config.R.
## Run with the working directory set to replication/code/data_prep, or via ../../run_all.R.
## =============================================================================
## fetch_ssb.R -- download the SSB (Statistics Norway) inputs from the PxWeb API
## and write them into the EXACT file shapes the downstream R/Stata code expects.
##
## Produces, in data_prep/ unless noted:
##   CPI_2_digits.xlsx / CPI_3_digits.xlsx / CPI_4_digits.xlsx  (+ _weights)
##   kpi_jae.xlsx   (CPI-ATE, sheet "KPIJustIndMnd", native layout, B4:C243)   -> data/ too
##   kpi_jel.xlsx   (CPI-AEL, sheet "KPIJustIndMnd", native layout, B4:C367)   -> data/ too
##   09175_quarterly.xlsx  (national-accounts wages/employment/hours, sheet "Lonn2", B4:F124) -> data/
##
## Table identifiers were confirmed against live SSB metadata (June 2026):
##   03013 Consumer Price Index by COICOP group; ContentsCode KpiIndMnd (index),
##         KpiVektMnd (weights). The Konsumgrp variable mixes all digit levels
##         (codes "01", "01.1", "01.1.1"), so we fetch all and filter by dot-level.
##   05327 CPI-AT/ATE/AE/AEL; the adjusted series live in the Konsumgrp variable
##         (JAE_TOTAL = CPI-ATE, JEL_TOTAL = CPI-AEL), ContentsCode KPIJustIndMnd.
##   09175 Wages and employment by industry; NACE total = nr23_6; ContentsCode
##         Lonn (wages), Sysselsatte (employment), Timeverk (hours).
## If SSB renames anything, set VERIFY_META <- TRUE (or call ssb_print_meta()).
##
## Honours REPL_USE_FALLBACK=1 (skips fetching, keeps the committed static files).
## =============================================================================

if (!exists("REPL_ROOT")) source("config.R")

suppressPackageStartupMessages({
  library(httr2); library(jsonlite); library(dplyr); library(tidyr)
  library(stringr); library(readxl); library(openxlsx); library(tibble)
})

## ----------------------------------------------------------------------------
## CONFIG
## ----------------------------------------------------------------------------
SSB_BASE <- "https://data.ssb.no/api/v0/en/table"   # English-label endpoint

SSB <- list(
  cpi        = list(table = "03013", var = "Konsumgrp", content = "KpiIndMnd"),
  cpi_weights= list(table = "03013", var = "Konsumgrp", content = "KpiVektMnd"),
  kpi_adj    = list(table = "05327", var = "Konsumgrp", content = "KPIJustIndMnd",
                    group_jae = "JAE_TOTAL", group_jel = "JEL_TOTAL"),
  wages      = list(table = "09175", nace = "nr23_6",
                    content = c(wage_total = "Lonn",
                                employment = "Sysselsatte",
                                hours      = "Timeverk"))
)

## regex selecting a COICOP digit level by the dotted SSB code
LEVEL_RE <- c(`2` = "^[0-9]{2}$",
              `3` = "^[0-9]{2}\\.[0-9]+$",
              `4` = "^[0-9]{2}\\.[0-9]+\\.[0-9]+$")

## Fixed row counts the Stata fixed cell-ranges assume (kpi_jae B4:C243 -> 240;
## kpi_jel B4:C367 -> 364; 09175 B4:F124 -> 120). Writers pad/trim to exactly
## these windows, anchored at the sample end (2018M12 / 2018K4), ".." for missing.
KPI_JAE_ROWS <- 240L
KPI_JEL_ROWS <- 364L
WAGE_ROWS    <- 120L

VERIFY_META <- FALSE   # set TRUE to print table metadata instead of fetching

## ----------------------------------------------------------------------------
## Low-level PxWeb helpers
## ----------------------------------------------------------------------------
ssb_get_meta <- function(table) {
  request(file.path(SSB_BASE, table)) |> req_retry(max_tries = 3) |>
    req_perform() |> resp_body_string() |> fromJSON(simplifyVector = FALSE)
}

ssb_print_meta <- function(table) {
  m <- ssb_get_meta(table)
  cat(sprintf("\n=== SSB %s: %s ===\n", table, m$title))
  for (v in m$variables) {
    cat(sprintf("  var '%s' (%s)\n", v$code, v$text))
    vals <- unlist(v$values); labs <- unlist(v$valueTexts); n <- min(length(vals), 10L)
    for (i in seq_len(n)) cat(sprintf("    %s = %s\n", vals[i], labs[i]))
  }
  invisible(m)
}

## one PxWeb query item; scalars unbox()ed, `values` kept as a plain vector so that
## with auto_unbox=FALSE it serialises as a JSON array (["a"] / ["a","b"]), not a
## nested array. (as.list() here would wrongly produce [["a"]] and trip a 400.)
ssb_sel <- function(code, filter, values) {
  list(code = jsonlite::unbox(code),
       selection = list(filter = jsonlite::unbox(filter), values = as.character(values)))
}

ssb_query <- function(table, query) {
  body <- list(query = query, response = list(format = jsonlite::unbox("json-stat2")))
  resp <- request(file.path(SSB_BASE, table)) |>
    req_body_json(body, auto_unbox = FALSE) |>
    req_retry(max_tries = 3) |> req_timeout(120) |> req_perform()
  jsonstat2_to_long(fromJSON(resp_body_string(resp), simplifyVector = FALSE))
}

## json-stat2 -> long (value array is row-major, last dimension fastest)
jsonstat2_to_long <- function(js) {
  ids <- unlist(js$id)
  dim_codes <- lapply(ids, function(d) {
    idx <- js$dimension[[d]]$category$index
    if (is.null(idx)) stop("no category index for dimension ", d)
    nm <- names(idx); nm[order(as.integer(unlist(idx)))]
  })
  names(dim_codes) <- ids
  grid <- do.call(expand.grid, c(rev(dim_codes), list(stringsAsFactors = FALSE)))
  grid <- grid[, rev(seq_along(ids)), drop = FALSE]
  names(grid) <- ids
  v <- js$value
  if (is.list(v)) v[vapply(v, is.null, logical(1))] <- NA
  grid$value <- as.numeric(unlist(v))
  glab <- js$dimension[[ids[1]]]$category$label
  if (!is.null(glab)) grid[[paste0(ids[1], "_label")]] <- unlist(glab)[grid[[ids[1]]]]
  as_tibble(grid)
}

month_window <- function(n, endY = SAMPLE_END) {
  end <- endY * 12 + 12; idx <- seq(end - n + 1, end)
  sprintf("%dM%02d", (idx - 1) %/% 12, ((idx - 1) %% 12) + 1)
}
quarter_window <- function(n, endY = SAMPLE_END) {
  end <- endY * 4 + 4; idx <- seq(end - n + 1, end)
  sprintf("%dK%d", (idx - 1) %/% 4, ((idx - 1) %% 4) + 1)
}

## ----------------------------------------------------------------------------
## CPI (2/3/4-digit) indices and weights
## ----------------------------------------------------------------------------
fetch_cpi_long <- function(content) {
  q <- list(ssb_sel("Konsumgrp", "all", "*"),
            ssb_sel("ContentsCode", "item", content),
            ssb_sel("Tid", "all", "*"))
  long <- ssb_query(SSB$cpi$table, q)
  check_cols(long, c("Konsumgrp", "Konsumgrp_label", "Tid", "value"),
             what = paste0("CPI ", content))
  check_month_format(long$Tid, what = paste0("CPI ", content, " Tid"))
  long
}

cpi_wide_for_level <- function(long, level) {
  re <- LEVEL_RE[[as.character(level)]]
  d <- long |>
    filter(grepl(re, .data$Konsumgrp)) |>
    mutate(header = paste(.data$Konsumgrp, .data$Konsumgrp_label)) |>
    transmute(Month = .data$Tid, header, value = .data$value) |>
    arrange(.data$Month) |>
    pivot_wider(names_from = "header", values_from = "value")
  catcols <- setdiff(names(d), "Month")
  d <- d[, c("Month", catcols[order(catcols)])]
  check_nrow_at_least(d, 200L, what = sprintf("CPI level-%d", level))
  check_year_range(substr(d$Month, 1, 4), CPI_START, SAMPLE_END,
                   what = sprintf("CPI level-%d", level))
  d
}

write_cpi_files <- function() {
  idx_long <- fetch_cpi_long(SSB$cpi$content)
  w_long <- tryCatch(fetch_cpi_long(SSB$cpi_weights$content),
                     error = function(e) {
                       warning("CPI weights fetch failed (", conditionMessage(e),
                               "); keeping static *_weights.xlsx"); NULL })
  for (lvl in c(2, 3, 4)) {
    idx <- cpi_wide_for_level(idx_long, lvl)
    safe_write(function(p) write.xlsx(idx, p),
               file.path(DATA_PREP, sprintf("CPI_%d_digits.xlsx", lvl)))
    message(sprintf("[ssb] CPI_%d_digits.xlsx (%d cols, %d rows)",
                    lvl, ncol(idx) - 1L, nrow(idx)))
    if (!is.null(w_long)) {
      w <- cpi_wide_for_level(w_long, lvl)
      safe_write(function(p) write.xlsx(w, p),
                 file.path(DATA_PREP, sprintf("CPI_%d_digits_weights.xlsx", lvl)))
    }
  }
}

## ----------------------------------------------------------------------------
## KPI-JAE / KPI-JEL adjusted indices -> native layout (sheet "KPIJustIndMnd")
## ----------------------------------------------------------------------------
fetch_kpi_series <- function(group) {
  spec <- SSB$kpi_adj
  q <- list(ssb_sel(spec$var, "item", group),
            ssb_sel("ContentsCode", "item", spec$content),
            ssb_sel("Tid", "all", "*"))
  long <- ssb_query(spec$table, q)
  check_cols(long, c("Tid", "value"), what = paste0("KPI ", group))
  check_month_format(long$Tid, what = paste0("KPI ", group, " Tid"))
  long |> transmute(Month = .data$Tid, value = .data$value) |> arrange(.data$Month)
}

write_kpi_native <- function(series, n_rows, path, label) {
  months <- month_window(n_rows)
  df <- tibble(Month = months) |> left_join(series, by = "Month")
  vals <- ifelse(is.na(df$value), "..", format(df$value, trim = TRUE))
  block <- data.frame(A = c(label, rep("", n_rows - 1L)),
                      B = df$Month, C = vals, stringsAsFactors = FALSE)
  wb <- createWorkbook(); addWorksheet(wb, "KPIJustIndMnd")
  writeData(wb, 1, x = block, startRow = 4, startCol = 1, colNames = FALSE)
  saveWorkbook(wb, path, overwrite = TRUE)
}

write_kpi_files <- function() {
  jae <- fetch_kpi_series(SSB$kpi_adj$group_jae)
  jel <- fetch_kpi_series(SSB$kpi_adj$group_jel)
  check_year_range(substr(jel$Month, 1, 4), MACRO_START, SAMPLE_END, what = "KPI-JEL")
  for (dest in c(DATA_PREP, DATA)) {
    write_kpi_native(jae, KPI_JAE_ROWS, file.path(dest, "kpi_jae.xlsx"), "KPI-JAE")
    write_kpi_native(jel, KPI_JEL_ROWS, file.path(dest, "kpi_jel.xlsx"), "KPI-JEL")
  }
  message("[ssb] kpi_jae.xlsx / kpi_jel.xlsx (data_prep/ and data/)")
}

## ----------------------------------------------------------------------------
## 09175 quarterly national accounts -> native layout (sheet "Lonn2", B4:F124)
## ----------------------------------------------------------------------------
fetch_wages <- function() {
  spec <- SSB$wages
  q <- list(ssb_sel("NACE", "item", spec$nace),
            ssb_sel("ContentsCode", "item", unname(spec$content)),
            ssb_sel("Tid", "all", "*"))
  long <- ssb_query(spec$table, q)
  check_cols(long, c("ContentsCode", "Tid", "value"), what = "wages raw")
  check_quarter_format(long$Tid, what = "wages Tid")
  inv <- setNames(names(spec$content), unname(spec$content))
  long |>
    mutate(name = inv[.data$ContentsCode]) |>
    transmute(Quarter = .data$Tid, name, value = .data$value) |>
    pivot_wider(names_from = "name", values_from = "value") |>
    arrange(.data$Quarter)
}

write_wages_native <- function(w, path) {
  qs <- quarter_window(WAGE_ROWS)
  df <- tibble(Quarter = qs) |> left_join(w, by = "Quarter")
  check_cols(df, c("wage_total", "employment", "hours"), what = "wages window")
  block <- data.frame(A = c("National accounts (table 09175)", rep("", WAGE_ROWS - 1L)),
                      B = df$Quarter, C = df$wage_total, D = NA_real_,
                      E = df$employment, F = df$hours, stringsAsFactors = FALSE)
  wb <- createWorkbook(); addWorksheet(wb, "Lonn2")
  writeData(wb, 1, x = block, startRow = 4, startCol = 1, colNames = FALSE)
  saveWorkbook(wb, path, overwrite = TRUE)
}

write_wages_file <- function() {
  w <- fetch_wages()
  check_year_range(substr(w$Quarter, 1, 4), MACRO_START, SAMPLE_END, what = "wages")
  safe_write(function(p) write_wages_native(w, p), file.path(DATA, "09175_quarterly.xlsx"))
  message("[ssb] data/09175_quarterly.xlsx")
}

## ----------------------------------------------------------------------------
## main
## ----------------------------------------------------------------------------
fetch_ssb_all <- function() {
  if (isTRUE(USE_FALLBACK)) {
    message("[ssb] REPL_USE_FALLBACK=1 -> skipping SSB fetch, using static files.")
    return(invisible(NULL))
  }
  if (isTRUE(VERIFY_META)) {
    for (tb in c(SSB$cpi$table, SSB$kpi_adj$table, SSB$wages$table)) ssb_print_meta(tb)
    return(invisible(NULL))
  }
  write_cpi_files()
  write_kpi_files()
  write_wages_file()
  message("[ssb] all SSB inputs refreshed.")
}

if (sys.nframe() == 0L || identical(environment(), globalenv())) fetch_ssb_all()
