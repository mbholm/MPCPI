********************************************************************************
* micro_regressions.do -- regressions on the panel of 3-digit COICOP price indices.
*
* Reads data/estimation_dataset.dta (built by code/data_prep/prep_data.R) and
* estimates the instrumental variable local projections of equations (1)-(2)
* and (3)-(5) in the paper:
*   - distribution of individual price responses              (Figure 3)
*   - CPI-weighted average response, incl. excl. housing       (Figure 2b)
*   - by consumption category                                  (Figure 6)
*   - interactions with import content, debt-to-cost ratio, net working capital,
*     wage share, interest expenses / costs, interest coverage (Figures 5, 8b, C.1)
*   - block (A): weighted average including the government-regulated indices (Figure B.3)
*   - block (B): placebo on the government-regulated indices               (Figure B.4)
* Exposure measures are ratios of COICOP-level sums (output/exposure_measures_by_index.xlsx).
*
* Run Stata from the package root. Paths are relative to it.
********************************************************************************

capture confirm file "data/estimation_dataset.dta"
if _rc {
	display as error "Start Stata in the replication/ directory and run the R stage first (data/estimation_dataset.dta not found)."
	exit 601
}
use "data/estimation_dataset.dta", replace

* policy-rate changes and lags
merge m:1 yearmonth using "data/policy_rate.dta", keep(match master) nogen

* baseline sample: drop electricity and the government-regulated indices ...
drop if price_index == "045 Electricity, gas and other fuels"
drop if govreg == 1
* ... and the four series with incomplete coverage (126 Financial services is
* unavailable before 2003; 082/096/127 before 2008)
drop if price_index == "082 Telephone equipment" | price_index == "096 Package holidays" | price_index == "126 Financial services nec" | price_index == "127 Other services nec"

* NOTE: `id` is assigned ALPHABETICALLY by price_index. In this 28-index sample,
* id 7 and id 8 are the two housing-rental series (041 Actual rentals, 042
* Imputed rentals), excluded from the "excl. housing" specifications below.
egen id = group(price_index)
egen time = group(yearmonth)
order id time
tsset id time

tab month, gen(month_)

* set parameters
global controls delta_price_lag_1-delta_price_lag_11 lag_delta_policy_rate_1-lag_delta_policy_rate_36 month_*

* horizon
global H = 60
forval jj = 0/$H {
	qui gen lhs_`jj' = f`jj'.log_price - l.log_price
}

* exposure measures: ratios of COICOP-level sums (the ratio columns carried
* through the R bridge are placeholders and are overwritten here)
replace debt_cost = debt/costs
gen net_working_capital = current_assets - current_liabilities
gen gross_working_capital = current_assets
gen nwc_sales = net_working_capital / revenue
gen gwc_sales = gross_working_capital / revenue
replace current_ratio = current_assets/current_liabilities
replace capital_cost_share = (costs - labor_costs - material_costs)/costs
gen labor_cost_share = labor_costs/costs
* interest-expense measures
gen int_cost = interestcosts / costs
gen icr      = op_result / interestcosts
gen inv_icr  = interestcosts / op_result

* interaction variables
qui gen inter_is_dpr = import_share*delta_policy_rate
qui gen inter_is_shock = import_share*MP_Shock
qui gen inter_dc_dpr = debt_cost*delta_policy_rate
qui gen inter_dc_shock = debt_cost*MP_Shock
qui gen inter_nwc_dpr = nwc_sales*delta_policy_rate
qui gen inter_nwc_shock = nwc_sales*MP_Shock
qui gen inter_lcs_dpr = labor_cost_share*delta_policy_rate
qui gen inter_lcs_shock = labor_cost_share*MP_Shock
foreach v in int_cost icr inv_icr {
	qui gen inter_`v'_dpr   = `v'*delta_policy_rate
	qui gen inter_`v'_shock = `v'*MP_Shock
}

* Newey-West / Driscoll-Kraay lag
global numlag = floor(4*((240-12)/100)^(2/9))

* descriptive table of the exposure measures by index (Appendix C text)
preserve
	collapse (mean) weight_avg debt_cost nwc_sales int_cost icr inv_icr import_share, by(price_index)
	export excel using "output/exposure_measures_by_index.xlsx", firstrow(variables) replace
restore

********************************************************************************
* DISTRIBUTION OF INDIVIDUAL PRICE RESPONSES (Figure 3)
********************************************************************************
su id
global N = r(max)

matrix res_agg = J($H + 1,$N,0)
matrix res_weight = J($H + 1,$N,0)
forval jjj = 1/$N {
	di `jjj'
	forval jj = 0/$H {
		qui newey2 lhs_`jj' (delta_policy_rate = MP_Shock) $controls if id == `jjj', lag($numlag) t(time)
		matrix res_agg[`jj'+1,`jjj'] = e(b)[1,1]
		qui su weight_avg if id == `jjj'
		matrix res_weight[`jj'+1,`jjj'] = r(mean)
	}
}
putexcel set "output/coeffs_price_index_detail.xlsx", sheet(`Sheet1') replace
putexcel A1 = matrix(res_agg)
putexcel save
putexcel set "output/coeffs_price_index_detail_weights.xlsx", sheet(`Sheet1') replace
putexcel A1 = matrix(res_weight)
putexcel save

********************************************************************************
* CPI-WEIGHTED AVERAGE (Figure 2b), and excluding housing rentals
********************************************************************************
matrix res_agg = J($H + 1,3,0)
forval jj = 0/$H {
	qui xtivreg2 lhs_`jj' (delta_policy_rate = MP_Shock) $controls [weight = weight_avg], fe dkraay($numlag)
	matrix res_agg[`jj'+1,1] = e(b)[1,1]
	matrix res_agg[`jj'+1,2] = sqrt(e(V)[1,1])
	matrix res_agg[`jj'+1,3] = e(N)
}
putexcel set "output/coeffs_cpi_weighted.xlsx", sheet(`sheet1') replace
putexcel A1 = matrix(res_agg)
putexcel save

matrix res_agg = J($H + 1,3,0)
forval jj = 0/$H {
	qui xtivreg2 lhs_`jj' (delta_policy_rate = MP_Shock) $controls [weight = weight_avg] if id != 7 & id != 8, fe dkraay($numlag)
	matrix res_agg[`jj'+1,1] = e(b)[1,1]
	matrix res_agg[`jj'+1,2] = sqrt(e(V)[1,1])
	matrix res_agg[`jj'+1,3] = e(N)
}
putexcel set "output/coeffs_cpi_excl_housing_weighted.xlsx", sheet(`sheet1') replace
putexcel A1 = matrix(res_agg)
putexcel save

********************************************************************************
* BY CONSUMPTION CATEGORY (Figure 6)
********************************************************************************
foreach spec in "dur D == 1" "nd ND == 1" "ser S == 1" "ser_excl_housing S == 1 & id != 7 & id != 8" {
	local name : word 1 of `spec'
	local cond = substr("`spec'", strlen("`name'") + 2, .)
	matrix res_agg = J($H + 1,3,0)
	forval jj = 0/$H {
		qui xtivreg2 lhs_`jj' (delta_policy_rate = MP_Shock) $controls [weight = weight_avg] if `cond', fe dkraay($numlag)
		matrix res_agg[`jj'+1,1] = e(b)[1,1]
		matrix res_agg[`jj'+1,2] = sqrt(e(V)[1,1])
		matrix res_agg[`jj'+1,3] = e(N)
	}
	putexcel set "output/coeffs_`name'_weighted.xlsx", sheet(`sheet1') replace
	putexcel A1 = matrix(res_agg)
	putexcel save
}

********************************************************************************
* INTERACTION EFFECTS (Figures 5, 8b, Appendix C.1)
*   name  endogenous interaction  exposure variable   output file
********************************************************************************
foreach spec in "is import_share coeffs_int_import_share" "dc debt_cost coeffs_int_deb_costs" "nwc nwc_sales coeffs_int_nwc" "lcs labor_cost_share coeffs_int_wage_share" "int_cost int_cost coeffs_int_int_cost" "icr icr coeffs_int_icr" "inv_icr inv_icr coeffs_int_inv_icr" {
	local tag  : word 1 of `spec'
	local xvar : word 2 of `spec'
	local file : word 3 of `spec'
	matrix res_int = J($H + 1,3,0)
	forval jj = 0/$H {
		qui xtivreg2 lhs_`jj' (inter_`tag'_dpr delta_policy_rate = inter_`tag'_shock `xvar' MP_Shock) $controls [weight = weight_avg], fe dkraay($numlag)
		matrix res_int[`jj'+1,1] = e(b)[1,1]
		matrix res_int[`jj'+1,2] = sqrt(e(V)[1,1])
		matrix res_int[`jj'+1,3] = e(N)
	}
	putexcel set "output/`file'.xlsx", sheet(`sheet1') replace
	putexcel A1 = matrix(res_int)
	putexcel save
}

********************************************************************************
* (A) WEIGHTED AVERAGE INCLUDING THE GOVERNMENT-REGULATED INDICES (Figure B.3)
*     A1: all seven regulated indices (044, 045, 061, 062, 073, 081, 124)
*     A2: as A1 but excluding 045 Electricity (market-priced, very volatile)
********************************************************************************
capture program drop setup
program define setup
	use "data/estimation_dataset.dta", replace
	merge m:1 yearmonth using "data/policy_rate.dta", keep(match master) nogen
	drop if price_index == "082 Telephone equipment" | price_index == "096 Package holidays" | price_index == "126 Financial services nec" | price_index == "127 Other services nec"
	egen id = group(price_index)
	egen time = group(yearmonth)
	order id time
	tsset id time
	tab month, gen(month_)
	global controls delta_price_lag_1-delta_price_lag_11 lag_delta_policy_rate_1-lag_delta_policy_rate_36 month_*
	global H = 60
	forval jj = 0/$H {
		qui gen lhs_`jj' = f`jj'.log_price - l.log_price
	}
	global numlag = floor(4*((240-12)/100)^(2/9))
end

foreach spec in "incl_govreg" "incl_govreg_excl_elec" {
	setup
	if "`spec'" == "incl_govreg_excl_elec" drop if price_index == "045 Electricity, gas and other fuels"
	matrix res_agg = J($H + 1,3,0)
	forval jj = 0/$H {
		qui xtivreg2 lhs_`jj' (delta_policy_rate = MP_Shock) $controls [weight = weight_avg], fe dkraay($numlag)
		matrix res_agg[`jj'+1,1] = e(b)[1,1]
		matrix res_agg[`jj'+1,2] = sqrt(e(V)[1,1])
		matrix res_agg[`jj'+1,3] = e(N)
	}
	putexcel set "output/coeffs_cpi_weighted_`spec'.xlsx", sheet(`sheet1') replace
	putexcel A1 = matrix(res_agg)
	putexcel save
}

********************************************************************************
* (B) PLACEBO: GOVERNMENT-REGULATED INDICES ONLY (Figure B.4)
*     Excludes 045 Electricity (market-priced) and 081 Postal services (series
*     only available from July 2008; incomplete-coverage criterion).
*     B1: CPI-weighted average; B2: series by series (Newey-West).
********************************************************************************
setup
drop if price_index == "045 Electricity, gas and other fuels"
drop if price_index == "081 Postal services"
keep if govreg == 1
drop id
egen id = group(price_index)
tsset id time

matrix res_agg = J($H + 1,3,0)
forval jj = 0/$H {
	qui xtivreg2 lhs_`jj' (delta_policy_rate = MP_Shock) $controls [weight = weight_avg], fe dkraay($numlag)
	matrix res_agg[`jj'+1,1] = e(b)[1,1]
	matrix res_agg[`jj'+1,2] = sqrt(e(V)[1,1])
	matrix res_agg[`jj'+1,3] = e(N)
}
putexcel set "output/coeffs_placebo_govreg_weighted.xlsx", sheet(`sheet1') replace
putexcel A1 = matrix(res_agg)
putexcel save

* individual series; id -> price_index map written to output/placebo_govreg_ids.txt
* (third column = 1 if the own-price lags had to be dropped for lack of variation)
global controls_nolag lag_delta_policy_rate_1-lag_delta_policy_rate_36 month_*
su id
global N = r(max)
capture file close idmap
file open idmap using "output/placebo_govreg_ids.txt", write replace
forval jjj = 1/$N {
	qui levelsof price_index if id == `jjj', local(nm)
	local fallback = 0
	matrix res_agg = J($H + 1,3,0)
	forval jj = 0/$H {
		capture qui newey2 lhs_`jj' (delta_policy_rate = MP_Shock) $controls if id == `jjj', lag($numlag) t(time)
		if _rc != 0 | e(V)[1,1] == . {
			local fallback = 1
			qui newey2 lhs_`jj' (delta_policy_rate = MP_Shock) $controls_nolag if id == `jjj', lag($numlag) t(time)
		}
		matrix res_agg[`jj'+1,1] = e(b)[1,1]
		matrix res_agg[`jj'+1,2] = sqrt(e(V)[1,1])
		matrix res_agg[`jj'+1,3] = e(N)
	}
	file write idmap "`jjj'" _tab `nm' _tab "`fallback'" _n
	display as text "placebo id `jjj': " `nm' " (fallback without own-price lags = `fallback')"
	putexcel set "output/coeffs_placebo_govreg_`jjj'.xlsx", sheet(`sheet1') replace
	putexcel A1 = matrix(res_agg)
	putexcel save
}
file close idmap

display as text _n "micro_regressions.do: done."
