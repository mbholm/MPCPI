## =============================================================================
## run_all.R -- R stage of the replication package.
##
## Order: config -> (fetch SSB + Norges Bank, unless REPL_USE_FALLBACK=1) ->
##        derive_import_shares -> prep_data -> prep_data_main_indices.
##
## Afterwards run the Stata and MATLAB stages (see README.md):
##     start Stata with working directory = replication/ :  do code/stata/run_all.do
##     matlab -batch "run('code/matlab/plot_figures.m')"
##
## Usage:  Rscript replication/run_all.R   (offline: REPL_USE_FALLBACK=1 Rscript ...)
## =============================================================================

.args <- commandArgs(trailingOnly = FALSE)
.self <- sub("^--file=", "", .args[grep("^--file=", .args)])
.root <- if (length(.self)) normalizePath(dirname(.self[1])) else getwd()
setwd(.root)

source(file.path("code", "data_prep", "config.R"))

run_step <- function(label, path) {
  message(sprintf("\n========== %s ==========", label))
  ok <- tryCatch({ source(path, chdir = FALSE); TRUE },
                 error = function(e) {
                   message(sprintf("[FAIL] %s: %s", label, conditionMessage(e)))
                   FALSE
                 })
  if (!ok) stop(sprintf("Pipeline stopped at step: %s", label))
  message(sprintf("[ok]  %s", label))
}

if (isTRUE(USE_FALLBACK)) {
  message("[run_all] REPL_USE_FALLBACK=1 -> using committed static inputs (no API fetch).")
} else {
  run_step("Fetch SSB (CPI, KPI-JAE/JEL, national-accounts wages)",
           file.path(CODE_R, "fetch_ssb.R"))
  run_step("Fetch Norges Bank (policy rate, I-44, USD/NOK)",
           file.path(CODE_R, "fetch_norgesbank.R"))
}

run_step("Derive import shares (WIOD 2012, Dhyne et al. 2023)",
         file.path(CODE_R, "derive_import_shares.R"))
run_step("Prepare 3-digit COICOP panel (data/estimation_dataset.dta)",
         file.path(CODE_R, "prep_data.R"))
run_step("Prepare 16 main-category panel (data/estimation_dataset_main_categories.dta)",
         file.path(CODE_R, "prep_data_main_indices.R"))

message("\n========== R stage complete ==========")
message("Next, the Stata stage (start Stata with working directory = replication/):")
message("    do code/stata/run_all.do")
message("Then the MATLAB stage (from any directory):")
message("    matlab -batch \"run('<replication>/code/matlab/plot_figures.m')\"")
