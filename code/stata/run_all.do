* =============================================================================
* run_all.do -- Stata stage of the replication package.
*
* START STATA WITH THE WORKING DIRECTORY SET TO THE PACKAGE ROOT, e.g.
*     cd "/path/to/MPCPI_replication"
*     do code/stata/run_all.do
*
* Requires the R stage (run_all.R) to have produced data/estimation_dataset.dta
* and data/estimation_dataset_main_categories.dta, and the SSC packages newey2,
* xtivreg2, ivreg2 and ranktest. Writes output/coeffs_*.xlsx, output/first_stage.log,
* output/exposure_measures_by_index.xlsx and output/placebo_govreg_ids.txt.
* macro_monthly_regressions.do also writes data/mp_shocks.csv (needed by MATLAB).
*
* Scripts, in run order:
*   macro_monthly_regressions.do            aggregate CPI-AEL, policy rate, I-44, USD/NOK (Figs 1, 2a, 8a, B.1, B.2)
*   macro_quarterly_regressions.do          wages, hours, employment (Fig 7)
*   micro_regressions.do                    28-index panel: weighted average, by category,
*                                           interactions, regulated indices, placebo (Figs 2b, 3, 5, 6, 8b, B.3, B.4, C.1)
*   micro_regressions_individual_series.do  16 main categories, series by series (Fig 4)
*   first_stage.do                          first-stage F statistics (footnote in Section 3.1)
* =============================================================================

capture confirm file "code/stata/macro_monthly_regressions.do"
if _rc {
	display as error "Start Stata in the replication/ directory before running this."
	exit 601
}

do "code/stata/macro_monthly_regressions.do"
do "code/stata/macro_quarterly_regressions.do"
do "code/stata/micro_regressions.do"
do "code/stata/micro_regressions_individual_series.do"
do "code/stata/first_stage.do"
