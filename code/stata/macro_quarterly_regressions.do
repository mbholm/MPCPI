* Run Stata from the replication/ directory (the master runner does this for you).
* All paths below are relative to replication/. See README.md.
capture confirm file "data/MP_Shocks.xlsx"
if _rc {
	display as error "Start Stata in the replication/ directory (data/ not found)."
	exit 601
}

import excel "data/MP_Shocks.xlsx", sheet("Quarterly") cellrange(A2:C117) clear
gen yearquarter = A + (B-1)/4
rename C mpshocks
rename A year
rename B quarter
save "data/mpshocks_quarterly.dta", replace

import delimited "data/policy_rate_daily.csv", clear colrange(12:13)
rename obs_value policy_rate_month
gen day = substr(time_period,1,2)
gen month = substr(time_period,4,2)
gen year = substr(time_period,7,4)
gen yearmonth = substr(time_period,7,4) + substr(time_period,4,2)
destring yearmonth year month day, replace
drop time_period
*save "data/policy_rate_monthly.dta", replace

gen quarter = floor((month-1)/3)+1
*bys year quarter (month day): gen policy_rate_quarterly = policy_rate_month if _n == _N
bys year quarter (month day): keep if _n == _N
gen yearquarter = year + (quarter-1)/4
keep year quarter yearquarter policy_rate

gen time = _n
tsset time
gen delta_policy_rate = d.policy_rate
forval jj = 1/12 {
	qui gen lag_delta_policy_rate_`jj' = l`jj'.delta_policy_rate
}
drop time
save "data/policy_rate_quarterly.dta", replace


* National-accounts wages/employment/hours (SSB table 09175). fetch_ssb.R writes
* this with the stable name below; the original timestamped export name was
* 09175_20250618-082243.xlsx.
import excel "data/09175_quarterly.xlsx", sheet("Lonn2") cellrange(B4:F124) clear
gen year = substr(B,1,4)
gen quarter = substr(B,6,1)
destring year quarter, replace
gen yearquarter = year + (quarter-1)/4
*rename G wage_per_hour
*rename J wage_per_empl
rename C wage_total
rename E employment
rename F hours
gen wage_per_hour = wage_total/hours
gen wage_per_empl = wage_total/employment
keep year quarter yearquarter wage_* employment hours
save "data/wages_quarterly.dta", replace


* just keep one of the price indices
use "data/wages_quarterly.dta", replace
merge 1:1 yearquarter using "data/mpshocks_quarterly.dta", nogen keep(match master)
merge 1:1 yearquarter using "data/policy_rate_quarterly.dta", nogen keep(match master)

gen time = _n
tsset time

gen logwageph = log(wage_per_hour)*100
gen logwagepe = log(wage_per_empl)*100
gen logwagetot = log(wage_total)*100
gen loghours = log(hours)*100
gen logemployment = log(employment)*100

tab quarter, gen(quarter_)

* horizon
global H = 20
foreach var in logwageph logwagepe logwagetot loghours logemployment {
forval jj = 0/$H {
	qui gen lhs_`var'_`jj' = f`jj'.`var' - l.`var'
}
}

* and lags
foreach var in logwageph logwagepe logwagetot loghours logemployment  {
forval jj = 1/3 {
	local jjj = `jj'+1
	qui gen lag_delta_`var'_`jj' = l`jj'.`var' - l`jjj'.`var'
}
}


* set parameters
global controls lag_delta_policy_rate_1-lag_delta_policy_rate_12 quarter_*

keep if year >= 1995 & year <= 2018


* lag in NEWEY WEST
global numlag = floor(4*((96-4)/100)^(2/9))


********************************************************************************
* AGGREGATE REGRESSION
********************************************************************************


foreach var in logwageph logwagepe logwagetot loghours logemployment  {

matrix res_agg = J($H + 1,3,0)

forval jj = 0/$H {
		qui newey2 lhs_`var'_`jj' (delta_policy_rate = mpshocks) $controls lag_delta_`var'_*, lag($numlag) t(time)
		matrix res_agg[`jj'+1,1] = e(b)[1,1]
		matrix res_agg[`jj'+1,2] = sqrt(e(V)[1,1])
		matrix res_agg[`jj'+1,3] = e(N)
}


* export matrix to excel sheet
putexcel set "output/coeffs_`var'.xlsx", sheet(`sheet1') replace
putexcel A1 = matrix(res_agg)
putexcel save
}

