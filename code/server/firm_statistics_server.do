* firm_statistics_server.do -- firm statistics by 2-digit NACE sector.
*
* Runs on the Statistics Norway microdata server (restricted access; not needed
* to reproduce the paper, since its output inputs/firm_statistics.csv is included).
* From the accounts statistics for non-financial firms (rsno{year}.dta, 1999-2019)
* it sums, over firms and over 2008-2019, within each 2-digit NACE sector:
*   costs               total operating costs
*   debt                long-term debt NET of debt to companies in the same
*                       corporate group (post 9500 - post 2260)
*   assets              total assets
*   current_assets, current_liabilities
*   labor_costs, revenue, material_costs
*   interestcosts       interest costs (post 8150, external interest only)
*   op_result           operating result (post 9050)
* and exports them (scaled by 1e12) with the ratios debt_cost, current_ratio,
* capital_cost_share, int_cost and icr. NACE is the firm's latest code; firms
* last observed before 2007 are dropped (pre-NACE 2007 codes).

global w5raw /ssb/stamme01/wealth5/wk48/raw/firm_accounts
global w5temp /ssb/stamme01/wealth5/wk48/mbm/temp
global w5prep /ssb/stamme01/wealth5/wk48/mbm/prepare/ownership

forval year = 1999/2019 {

	use $w5raw/rsno`year'.dta, clear

	cap rename bof_nace07 nace
	cap rename nace_pop nace

	* driftskostnader
	cap g costs = drkost
	* or driftssinntekter minus op_result
	cap g costs = P9000 - P9050

	* langsiktig gjeld minus gjeld til selskap i samme konsern
	g debt = P9500 - P2260

	* aktiva
	g assets = P9400

	* omløpsmidler in Norwegian
	g current_assets = P9350
	* short-term debt
	g current_liabilities = P9550
	* labor costs
	g labor_costs = P5000 + P5300 + P5400 + P5420 + P5600 + P5900
	* revenue
	g revenue = P3000 + P3100 + P3200 + P3300 + P3400 + P3500 + P3600 + P3695 + P3700 + P3800 + P3900
	* varekostnad
	g material_costs = P4005 + P4500

	* interest costs (annen rentekostnad, excludes intra-group interest P8130)
	g interestcosts = P8150

	* operating result (driftsresultat). Only years > 2007 enter the collapse
	* below, and those all have the P-codes; the fallback keeps the append from
	* failing in the older format.
	cap g op_result = P9050
	cap g op_result = .

	format costs debt assets interestcosts %12.0g

	* keep op_result
	keep lfirm nace costs debt assets interestcosts current_assets current_liabilities labor_costs revenue material_costs op_result
	gen year = `year'

	save $w5temp/_temp_ret`year'.dta, replace
	}

clear
forval year = 1999/2019 {
append using $w5temp/_temp_ret`year'.dta
erase $w5temp/_temp_ret`year'.dta
}


order lfirm year
tsset lfirm year

label variable costs "total operating costs"
label variable debt "long-term debt"
label variable assets "total assets"
label variable interestcosts "interest costs (annen rentekostnad, P8150)"
lab var current_assets "omløpsmidler"
lab var current_liabilities "kortsiktig gjeld"
lab var labor_costs "lønnsrelaterte kostnader"
lab var revenue "salgsinntekter"
lab var material_costs "varekostnad"
lab var op_result "driftsresultat (P9050)"


* replace nace with the latest NACE per firm
gen _temp1 = substr(nace,1,2)
destring _temp1, replace
gen _temp2 = substr(nace,3,4)
destring _temp2, replace

bys lfirm: egen maxYear = max(year)
drop if maxYear < 2007
bys lfirm (year): gen _temp3 = _temp1*(year==maxYear)
bys lfirm: egen nace2dig = max(_temp3)
bys lfirm (year): gen _temp4 = _temp2*(year==maxYear)
bys lfirm: egen nacePt2 = max(_temp4)

drop _temp1 _temp2 _temp3 _temp4 maxYear

gen naceFull = nace2dig + nacePt2
format naceFull %9.3f

cap drop nace nacePt2
rename naceFull nace


* firm-level file
save $w5prep/firm_statistics_server.dta, replace

u $w5prep/firm_statistics_server.dta, replace

* do it only after the new nace codes
keep if year > 2007

* collapse to 2-digit NACE
collapse (sum) costs interestcosts debt assets current_assets current_liabilities labor_costs revenue material_costs op_result, by(nace2dig)
g debt_cost = debt / costs
g current_ratio = current_assets/current_liabilities
g capital_cost_share = 1 - (labor_costs + material_costs)/costs
* interest-expense based measures (ratios of sector sums, as debt_cost)
g int_cost = interestcosts / costs
g icr = op_result / interestcosts
drop if  nace2dig == 0 | nace2dig == .
* scale levels
foreach var of varlist costs debt current_assets current_liabilities labor_costs material_costs revenue interestcosts op_result {
	qui replace `var' = `var'/1e12
	}
order nace debt_cost current_ratio capital_cost_share int_cost icr costs debt current_assets current_liabilities labor_costs material_costs revenue interestcosts op_result
keep nace debt_cost current_ratio capital_cost_share int_cost icr costs debt current_assets current_liabilities labor_costs material_costs revenue interestcosts op_result
* export
outsheet nace debt_cost current_ratio capital_cost_share int_cost icr costs debt current_assets current_liabilities labor_costs material_costs revenue interestcosts op_result using "/ssb/stamme01/wealth5/dok/mbm/MPPRICE/firm_statistics.csv", c replace
