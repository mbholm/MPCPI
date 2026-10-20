* Run Stata from the replication/ directory (the master runner does this for you).
* All paths below are relative to replication/. See README.md.
capture confirm file "data/estimation_dataset_main_categories.dta"
if _rc {
	display as error "Start Stata in the replication/ directory (data/ not found)."
	exit 601
}

* NOTE (CONSISTENCY_REPORT.md C4): this produces output/coeffs_price_index_{id}.xlsx,
* where `id` is assigned ALPHABETICALLY by price_index (see the mapping table in
* prep_data_main_indices.R). plot_figures.m -> FIG_IRF_PRICE_INDEX_{id}, and the
* paper's Fig. `panel` hand-picks specific ids. A label change shifts every id.
use "data/estimation_dataset_main_categories.dta", replace

* get in delta_policy_rate lags
merge m:1 yearmonth using "data/policy_rate.dta", keep(match master) nogen


egen id = group(price_index)
egen time = group(yearmonth)
order id time
tsset id time

* horizon
global H = 60
forval jj = 0/$H {
	qui gen lhs_`jj' = f`jj'.log_price - l.log_price
}

tab month, gen(month_)

* set parameters
global controls lag_delta_policy_rate_1-lag_delta_policy_rate_36 delta_price_lag_1-delta_price_lag_11 month_*


global numlag = floor(4*((240-12)/100)^(2/9))

********************************************************************************
* MICRO REGRESSIONS
********************************************************************************

su id
global N = r(max)

forval jjj = 1/$N {

matrix res_agg = J($H + 1,3,0)

forval jj = 0/$H {
		qui newey2 lhs_`jj' (delta_policy_rate = MP_Shock) $controls if id == `jjj', lag($numlag) t(time)
		matrix res_agg[`jj'+1,1] = e(b)[1,1]
		matrix res_agg[`jj'+1,2] = sqrt(e(V)[1,1])
		matrix res_agg[`jj'+1,3] = e(N)
}


* export matrix to excel sheet
putexcel set "output/coeffs_price_index_`jjj'.xlsx", sheet(`sheet1') replace
putexcel A1 = matrix(res_agg)
putexcel save
}

