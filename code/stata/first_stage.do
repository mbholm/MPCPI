********************************************************************************
* first_stage.do -- first-stage strength of the monetary policy shock as an
* instrument for the change in the policy rate (footnote in Section 3.1).
*
*   (1) aggregate CPI-AEL regression, monthly 1995-2018 (eqs. 1-2, Newey-West)
*   (2) CPI-weighted panel of 28 sub-indices, 2001-2018 (eqs. 1-2, Driscoll-Kraay)
*   (3) interaction specifications (eqs. 3-5, two endogenous regressors) with
*       debt_cost, nwc_sales and import_share
* Reported: Kleibergen-Paap rk Wald F (robust to the same HAC / Driscoll-Kraay
* structure as the main estimates), Cragg-Donald F, and for (3) the
* Sanderson-Windmeijer F per endogenous regressor, at horizons 0 and 60.
*
* Run Stata from the replication/ directory. Output: output/first_stage.log.
********************************************************************************
capture confirm file "data/estimation_dataset.dta"
if _rc {
	display as error "Start Stata in the replication/ directory (data/ not found)."
	exit 601
}

capture log close fs
log using "output/first_stage.log", replace text name(fs)

* (1) aggregate monthly regression, CPI-AEL (as macro_monthly_regressions.do)
use "data/policy_rate.dta", replace
merge 1:1 yearmonth using "data/kpi_jel.dta", nogen keep(match master)
merge 1:1 yearmonth using "data/mp_shock.dta", nogen keep(match master)
gen time = _n
tsset time
tab month, gen(month_)
gen logkpijel = log(kpijel)*100
foreach jj in 0 60 {
	qui gen lhs_kpijel_`jj' = f`jj'.logkpijel - l.logkpijel
}
forval jj = 1/11 {
	local jjj = `jj'+1
	qui gen lag_delta_kpijel_`jj' = (l`jj'.logkpijel - l`jjj'.logkpijel)
}
global controls lag_delta_policy_rate_1-lag_delta_policy_rate_36 month_*
keep if year >= 1995 & year <= 2018
global numlag = floor(4*((336-12)/100)^(2/9))
local bw = $numlag + 1

display _n(2) "=================================================================="
display "(1) AGGREGATE CPI-AEL, monthly 1995-2018, Newey-West lag = $numlag"
display "=================================================================="
foreach jj in 0 60 {
	display _n "--- horizon h = `jj' ---"
	qui ivreg2 lhs_kpijel_`jj' (delta_policy_rate = MP_Shock) $controls lag_delta_kpijel_*, robust bw(`bw') kernel(bartlett) ffirst
	display "N = " e(N)
	display "Kleibergen-Paap rk Wald F (HAC-robust): " %8.2f e(widstat)
	display "Cragg-Donald Wald F (homoskedastic):    " %8.2f e(cdf)
	display "Stock-Yogo 10% maximal IV size critical value (1 endog, 1 instr): 16.38"
	qui newey delta_policy_rate MP_Shock $controls lag_delta_kpijel_* if e(sample), lag($numlag)
	display "first-stage coef on MP_Shock = " %6.3f _b[MP_Shock] "  (HAC t = " %5.2f _b[MP_Shock]/_se[MP_Shock] ")"
}

* (2) and (3) panel of 28 sub-indices (as micro_regressions.do)
use "data/estimation_dataset.dta", replace
merge m:1 yearmonth using "data/policy_rate.dta", keep(match master) nogen
drop if price_index == "045 Electricity, gas and other fuels"
drop if govreg == 1
drop if price_index == "082 Telephone equipment" | price_index == "096 Package holidays" | price_index == "126 Financial services nec" | price_index == "127 Other services nec"
egen id = group(price_index)
egen time = group(yearmonth)
order id time
tsset id time
tab month, gen(month_)
global controls delta_price_lag_1-delta_price_lag_11 lag_delta_policy_rate_1-lag_delta_policy_rate_36 month_*
foreach jj in 0 60 {
	qui gen lhs_`jj' = f`jj'.log_price - l.log_price
}
replace debt_cost = debt/costs
gen nwc_sales = (current_assets - current_liabilities) / revenue
global numlag = floor(4*((240-12)/100)^(2/9))

display _n(2) "=================================================================="
display "(2) CPI-WEIGHTED PANEL, 28 sub-indices 2001-2018, Driscoll-Kraay lag = $numlag"
display "=================================================================="
foreach jj in 0 60 {
	display _n "--- horizon h = `jj' ---"
	qui xtivreg2 lhs_`jj' (delta_policy_rate = MP_Shock) $controls [weight = weight_avg], fe dkraay($numlag) ffirst
	display "N = " e(N) ", indices = " e(N_g)
	display "Kleibergen-Paap rk Wald F (DK-robust): " %8.2f e(widstat)
	display "Cragg-Donald Wald F (homoskedastic):   " %8.2f e(cdf)
}

display _n(2) "=================================================================="
display "(3) INTERACTION SPECIFICATIONS, two endogenous regressors"
display "    instruments: MP_Shock, MP_Shock x X, X   (as in eqs. 4-5)"
display "=================================================================="
foreach v in debt_cost nwc_sales import_share {
	qui gen inter_`v'_dpr   = `v'*delta_policy_rate
	qui gen inter_`v'_shock = `v'*MP_Shock
	foreach jj in 0 60 {
		display _n "--- X = `v', horizon h = `jj' ---"
		qui xtivreg2 lhs_`jj' (inter_`v'_dpr delta_policy_rate = inter_`v'_shock `v' MP_Shock) $controls [weight = weight_avg], fe dkraay($numlag) ffirst
		display "N = " e(N)
		display "Kleibergen-Paap rk Wald F (DK-robust), joint: " %8.2f e(widstat)
		display "Cragg-Donald Wald F (homoskedastic), joint:   " %8.2f e(cdf)
		matrix first = e(first)
		local r = rownumb(first, "SWF")
		if `r' > 0 {
			display "Sanderson-Windmeijer F, dr x X : " %8.2f first[`r',1]
			display "Sanderson-Windmeijer F, dr     : " %8.2f first[`r',2]
		}
	}
}

log close fs
display _n "Done. Results in output/first_stage.log"
