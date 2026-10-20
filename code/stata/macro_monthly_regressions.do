* Run Stata from the replication/ directory (the master runner does this for you).
* All paths below are relative to replication/. See README.md.
capture confirm file "data/MP_Shocks.xlsx"
if _rc {
	display as error "Start Stata in the replication/ directory (data/ not found)."
	exit 601
}

* transform usdnok, i44, kpi-jae into stata datasets
import delimited "data/usdnok.csv", clear colrange(15:16)
rename obs_value usdnok
gen yearmonth = substr(time_period,1,4) + substr(time_period,6,2)
destring yearmonth, replace
drop time_period
save "data/usdnok.dta", replace

import delimited "data/i44.csv", clear colrange(15:16)
rename obs_value i44
gen yearmonth = substr(time_period,1,4) + substr(time_period,6,2)
destring yearmonth, replace
drop time_period
save "data/i44.dta", replace


import delimited "data/policy_rate_daily.csv", clear colrange(12:13)
rename obs_value policy_rate
gen day = substr(time_period,1,2)
gen month = substr(time_period,4,2)
gen year = substr(time_period,7,4)
gen yearmonth = substr(time_period,7,4) + substr(time_period,4,2)
*destring day month year, replace
bys year month (day): keep if _n == _N
keep yearmonth  policy_rate 
gen time = _n
tsset time
gen delta_policy_rate = d.policy_rate
forval jj = 1/36 {
	qui gen lag_delta_policy_rate_`jj' = l`jj'.delta_policy_rate
}
destring yearmonth, replace
drop time
save "data/policy_rate.dta", replace

import excel "data/kpi_jae.xlsx", sheet("KPIJustIndMnd") cellrange(B4:C243) clear
gen yearmonth = substr(B,1,4) + substr(B,6,2)
destring yearmonth, replace
rename C kpijae
destring kpijae, replace force
drop B
save "data/kpi_jae.dta", replace

import excel "data/MP_Shocks.xlsx", sheet("Monthly") cellrange(A2:C349) clear
rename A year
rename B month
rename C MP_Shock
gen yearmonth = year*100 + month
save "data/mp_shock.dta", replace


import excel "data/kpi_jel.xlsx", sheet("KPIJustIndMnd") cellrange(B4:C367) clear
gen yearmonth = substr(B,1,4) + substr(B,6,2)
destring yearmonth, replace
rename C kpijel
destring kpijel, replace force
drop B
save "data/kpi_jel.dta", replace


* just keep one of the price indices
use "data/policy_rate.dta", replace
merge 1:1 yearmonth using "data/kpi_jae.dta", nogen keep(match master)
merge 1:1 yearmonth using "data/i44.dta", nogen keep(match master)
merge 1:1 yearmonth using "data/kpi_jel.dta", nogen keep(match master)
merge 1:1 yearmonth using "data/usdnok.dta", nogen keep(match master)
merge 1:1 yearmonth using "data/mp_shock.dta", nogen keep(match master)

outsheet year month yearmonth MP_Shock using "data/mp_shocks.csv", c replace


gen time = _n
tsset time

*gen delta_policy_rate = d.policy_rate


tab month, gen(month_)

forval jj = 1/36 {
	qui gen lag_mp_shock_`jj' = l`jj'.MP_Shock
}

gen logi44 = log(i44)*100
gen logusdnok = log(usdnok)*100
gen logkpijae = log(kpijae)*100
gen logkpijel = log(kpijel)*100


* horizon
*global H = 60

/*
foreach var in i44 usdnok {
forval jj = 0/$H {
	qui gen lhs_`var'_`jj' = 100*(f`jj'.`var' - l.`var')/l.`var'
}
}
*/

global H = 60
foreach var in kpijae kpijel i44 usdnok {
forval jj = 0/$H {
	qui gen lhs_`var'_`jj' = f`jj'.log`var' - l.log`var'
}
}

forval jj = 0/$H {
	replace lhs_kpijae_`jj' = lhs_kpijel_`jj' if lhs_kpijae_`jj' == .
}

forval jj = 0/$H {
	qui gen lhs_policy_rate_`jj' = f`jj'.policy_rate - l.policy_rate
}




* and lags
/*
foreach var in i44 usdnok {
forval jj = 1/11 {
	local jjj = `jj'+1
	qui gen lag_delta_`var'_`jj' = 100*(l`jj'.`var' - l`jjj'.`var')/l`jjj'.`var'
}
}
*/
foreach var in kpijae kpijel i44 usdnok {
forval jj = 1/11 {
	local jjj = `jj'+1
	qui gen lag_delta_`var'_`jj' = (l`jj'.log`var' - l`jjj'.log`var')
}
}

forval jj = 1/11 {
	qui replace lag_delta_kpijae_`jj' = lag_delta_kpijel_`jj' if lag_delta_kpijae_`jj' == .
}


* set parameters
global controls lag_delta_policy_rate_1-lag_delta_policy_rate_36 month_* 

keep if year >= 1995 & year <= 2018

* lag in NEWEY WEST
global numlag = floor(4*((336-12)/100)^(2/9))



********************************************************************************
* PRICE REGRESSION
********************************************************************************

matrix res_agg = J($H + 1,3,0)

forval jj = 0/$H {
		qui newey2 lhs_policy_rate_`jj' MP_Shock $controls, lag($numlag) t(time)
		matrix res_agg[`jj'+1,1] = e(b)[1,1]
		matrix res_agg[`jj'+1,2] = sqrt(e(V)[1,1])
		matrix res_agg[`jj'+1,3] = e(N)
}


* export matrix to excel sheet
putexcel set "output/coeffs_policy_rate.xlsx", sheet(`sheet1') replace
putexcel A1 = matrix(res_agg)
putexcel save





matrix res_agg = J($H + 1,3,0)

forval jj = 0/$H {
		qui newey2 lhs_policy_rate_`jj' (delta_policy_rate = MP_Shock) $controls, lag($numlag) t(time)
		matrix res_agg[`jj'+1,1] = e(b)[1,1]
		matrix res_agg[`jj'+1,2] = sqrt(e(V)[1,1])
		matrix res_agg[`jj'+1,3] = e(N)
}


* export matrix to excel sheet
putexcel set "output/coeffs_policy_rate_iv.xlsx", sheet(`sheet1') replace
putexcel A1 = matrix(res_agg)
putexcel save




********************************************************************************
* AGGREGATE REGRESSIONS
********************************************************************************

foreach var in kpijae kpijel usdnok i44 {

matrix res_agg = J($H + 1,3,0)

forval jj = 0/$H {
		qui newey2 lhs_`var'_`jj' (delta_policy_rate = MP_Shock) $controls lag_delta_`var'_*, lag($numlag) t(time)
		matrix res_agg[`jj'+1,1] = e(b)[1,1]
		matrix res_agg[`jj'+1,2] = sqrt(e(V)[1,1])
		matrix res_agg[`jj'+1,3] = e(N)
}

* export matrix to excel sheet
putexcel set "output/coeffs_`var'.xlsx", sheet(`sheet1') replace
putexcel A1 = matrix(res_agg)
putexcel save
}



* reduced form regression of kpi-jel with monetary policy shock lags and month-fixed effects (reproduce JPE setup)
matrix res_agg = J($H + 1,3,0)

forval jj = 0/$H {
		qui newey2 lhs_kpijel_`jj' MP_Shock lag_mp_shock_* month_*, lag($numlag) t(time)
		matrix res_agg[`jj'+1,1] = e(b)[1,1]
		matrix res_agg[`jj'+1,2] = sqrt(e(V)[1,1])
		matrix res_agg[`jj'+1,3] = e(N)
}

* export matrix to excel sheet
putexcel set "output/coeffs_kpijel_JPE.xlsx", sheet(`sheet1') replace
putexcel A1 = matrix(res_agg)
putexcel save

