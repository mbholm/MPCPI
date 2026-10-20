## =============================================================================
## prep_data.R -- builds the 3-digit COICOP estimation panel data/estimation_dataset.dta.
##
## Steps: read the CPI sub-indices and weights, the monetary policy shocks, the
## firm statistics by NACE sector (inputs/firm_statistics.csv, produced on the
## Statistics Norway microdata server by code/server/firm_statistics_server.do),
## and the import shares; bridge the NACE-level firm statistics and import shares
## to COICOP with the Cai and Vandyck (2020) correspondence; merge everything into
## a monthly panel 2001-2018 with lags of the price changes.
##
## The server exports numeric 2-digit NACE codes; the bridge matrix uses CPA-style
## labels ("A01", "C10-C12", ...), so the codes are mapped to labels below. Levels
## (debt, costs, interest costs, ...) are bridged as sums; all ratios are formed in
## Stata from the COICOP-level sums.
##
## Run standalone with the working directory set to code/data_prep, or via
## ../../run_all.R.
## =============================================================================

if (!exists("REPL_ROOT")) source("config.R")
setwd(INPUTS)

library(readxl)
library(tidyverse)
library(haven)

# ---- firm statistics from the server export ----------------------------------
firm_file <- "firm_statistics.csv"
if (!file.exists(firm_file)) {
  stop(firm_file, " not found in inputs/. Run code/server/firm_statistics_server.do ",
       "on the SSB server and copy its output here.")
}
firm_stats_raw <- read_csv(firm_file, show_col_types = FALSE)
if (!"nace2dig" %in% names(firm_stats_raw) && "nace" %in% names(firm_stats_raw)) {
  firm_stats_raw <- rename(firm_stats_raw, nace2dig = nace)
}
check_cols(firm_stats_raw,
           c("nace2dig","costs","debt","current_assets","current_liabilities",
             "labor_costs","material_costs","revenue","interestcosts","op_result"),
           what = "firm_statistics")

# The server exports numeric 2-digit NACE codes; the CPA bridge uses labels
# ("A01", "C10-C12", ...). Rows sharing a label are summed below. Codes 98-99
# are not covered by the bridge and are dropped.
nace_label_map <- c(
  `1`="A01", `2`="A02", `3`="A03", `5`="B", `6`="B", `7`="B", `8`="B", `9`="B",
  `10`="C10-C12", `11`="C10-C12", `12`="C10-C12",
  `13`="C13-C15", `14`="C13-C15", `15`="C13-C15",
  `16`="C16", `17`="C17", `18`="C18", `19`="C19", `20`="C20", `21`="C21", `22`="C22",
  `23`="C23", `24`="C24", `25`="C25", `26`="C26", `27`="C27", `28`="C28", `29`="C29",
  `30`="C30", `31`="C31_C32", `32`="C31_C32", `33`="C33", `35`="D35", `36`="E36",
  `37`="E37-E39", `38`="E37-E39", `39`="E37-E39", `41`="F", `42`="F", `43`="F",
  `45`="G45", `46`="G46", `47`="G47", `49`="H49", `50`="H50", `51`="H51", `52`="H52",
  `53`="H53", `55`="I", `56`="I", `58`="J58", `59`="J59_J60", `60`="J59_J60",
  `61`="J61", `62`="J62_J63", `63`="J62_J63", `64`="K64", `65`="K65", `66`="K66",
  `68`="L68", `69`="M69_M70", `70`="M69_M70", `71`="M71", `72`="M72", `73`="M73",
  `74`="M74_M75", `75`="M74_M75", `77`="N77", `78`="N78", `79`="N79",
  `80`="N80-N82", `81`="N80-N82", `82`="N80-N82", `84`="O84", `85`="P85",
  `86`="Q86", `87`="Q87_Q88", `88`="Q87_Q88", `90`="R90-R92", `91`="R90-R92",
  `92`="R90-R92", `93`="R93", `94`="S94", `95`="S95", `96`="S96", `97`="T")
if (is.numeric(firm_stats_raw$nace2dig)) {
  codes <- as.character(as.integer(firm_stats_raw$nace2dig))
  unmapped <- setdiff(unique(codes), c(names(nace_label_map), "98", "99"))
  if (length(unmapped)) stop("Unmapped NACE code(s) in server export: ", paste(unmapped, collapse = ", "))
  firm_stats_raw <- firm_stats_raw %>%
    mutate(nace2dig = unname(nace_label_map[codes])) %>%
    filter(!is.na(nace2dig))
  message("[prep_data] mapped numeric NACE codes to CPA labels (", nrow(firm_stats_raw), " rows)")
}
# The ratio columns exported by the server (debt_cost, current_ratio,
# capital_cost_share, int_cost, icr) pass through the bridge like the levels,
# they are placeholders only, and Stata recomputes
# every ratio from the COICOP-level sums.

# ---- monetary policy shocks ---------------------------------------------------
MP_Shocks <- read_excel("MP_Shocks.xlsx", sheet = "Monthly")

# ---- price indices ------------------------------------------------------------
CPI_3_digits <- read_excel("CPI_3_digits.xlsx") %>%
  mutate(year = as.integer(substr(Month, 1, 4)),
         month = as.integer(substr(Month, 6, 7))) %>%
  select(year, month, everything()) %>%
  select(-Month) %>%
  mutate_all(as.numeric) %>%
  mutate(across(-c(1,2), ~log(.))) %>%
  mutate(across(-c(1,2), ~.*100)) %>%
  filter(year >= 2000 & year <= 2018)

# ---- average CPI weights ------------------------------------------------------
CPI_3_digits_weights_average <- read_excel("CPI_3_digits_weights.xlsx") %>%
  mutate(year = as.integer(substr(Month, 1, 4))) %>%
  filter(year >= 2000 & year <= 2018) %>%
  select(-c(year, Month)) %>%
  mutate_all(as.numeric) %>%
  summarise_all(mean) %>%
  pivot_longer(cols = everything(), names_to = "description",values_to = "weight_avg") %>%
  mutate(price_index = str_replace_all(description, "\\.", ""))

# ---- NACE/CPA -> COICOP bridge (Cai and Vandyck, 2020) ------------------------
weights_normalized <- read_excel("CPA_COICOP_correspondence.xlsx", sheet = "NO") %>%
  rename(CPA=`Unit: Million euro, current prices`) %>%
  mutate(CP124 = ifelse(CPA == "CPA_Q87_Q88",CP122_127,0),
         CP125 = ifelse(CPA == "CPA_K65",CP122_127,0),
         CP126 = ifelse(CPA == "CPA_K64",CP122_127,0)) %>%
  select(-CP122_127) %>%
  pivot_longer(cols = -CPA, names_to = "COICOP", values_to = "weight") %>%
  mutate(CPA = str_replace(CPA, "^CPA_", "")) %>%
  mutate(COICOP = str_replace(COICOP, "^CP", "")) %>%
  mutate(across(CPA, ~ str_replace_all(., "_", "-"))) %>%
  group_by(COICOP) %>%
  mutate(normalized_weight = weight / sum(weight)) %>%
  select(-weight)

COICOP_firm_statistics <- firm_stats_raw %>%
  group_by(nace2dig) %>%
  summarise(across(everything(), \(x) sum(x, na.rm = TRUE))) %>%
  rename(CPA=nace2dig) %>%
  mutate(across(CPA, ~ str_replace_all(., "_", "-"))) %>%
  full_join(weights_normalized, by="CPA") %>%
  mutate(across(
    .cols = -c(CPA,COICOP,normalized_weight),
    .fns = ~ . * normalized_weight
  )) %>%
  group_by(COICOP) %>%
  summarise(across(.cols = -c(CPA,normalized_weight), \(x) sum(x, na.rm = TRUE)))

# ---- import shares (derived by derive_import_shares.R) ---------------------
COICOP_import_shares <- read_excel("cpa_import_share.xlsx") %>%
  filter(!(Code %in% c("N", "Q", "R_S"))) %>%
  bind_rows(
    read_excel("cpa_import_share.xlsx") %>%
      filter(Code == "N") %>%
      slice(rep(1, 4)) %>%
      mutate(Code = c("N77", "N78", "N79", "N80-N82")),
    read_excel("cpa_import_share.xlsx") %>%
      filter(Code == "Q") %>%
      slice(rep(1, 2)) %>%
      mutate(Code = c("Q86", "Q87_Q88")),
    read_excel("cpa_import_share.xlsx") %>%
      filter(Code == "R_S") %>%
      slice(rep(1, 5)) %>%
      mutate(Code = c("R90-R92", "R93", "S94", "S95", "S96"))) %>%
  rename(CPA=Code) %>%
  filter(CPA!="U") %>%
  full_join(weights_normalized, by="CPA") %>%
  mutate(weighted_share = total_import_share_cons_h * normalized_weight) %>%
  group_by(COICOP) %>%
  summarize(import_share = sum(weighted_share, na.rm = T))

COICOP_statistics <- COICOP_firm_statistics %>%
  left_join(COICOP_import_shares, by = "COICOP")

COICOP_statistics_ext <- COICOP_statistics %>%
  filter(!(COICOP %in% c("02", "082_083"))) %>%
  bind_rows(
    COICOP_statistics %>%
      filter(COICOP == "02") %>%
      slice(rep(1, 2)) %>%
      mutate(COICOP = c("021", "022")),
    COICOP_statistics %>%
      filter(COICOP == "082_083") %>%
      slice(rep(1, 2)) %>%
      mutate(COICOP = c("082", "083")))

# ---- final panel ----------------------------------------------------------------
data <- CPI_3_digits %>%
  pivot_longer(cols = -c(1,2), names_to = "price_index", values_to = "price") %>%
  left_join(MP_Shocks, by = c("year" = "Year", "month" = "Month")) %>%
  mutate(yearmonth = as.numeric(paste0(year, str_pad(month, 2, pad = "0")))) %>%
  mutate(price_index = str_replace_all(price_index, "\\.", "")) %>%
  mutate(COICOP = str_extract(price_index, "\\d{3}")) %>%
  left_join(read_excel("consumption_category.xlsx") %>% mutate(COICOP = str_extract(COICOP, "^\\d{3}")), by = "COICOP") %>%
  left_join(COICOP_statistics_ext, by = "COICOP") %>%
  left_join(CPI_3_digits_weights_average, by = "price_index") %>%
  left_join(read_excel("govreg.xlsx"), by = "price_index") %>%
  select(year, month, yearmonth,price_index,weight_avg,govreg,price,MP_Shock,import_share,debt_cost, current_ratio, capital_cost_share, costs, debt, current_assets, current_liabilities, labor_costs, material_costs, revenue, interestcosts, op_result, D,ND,S) %>%
  rename(log_price=price) %>%
  arrange(price_index, yearmonth) %>%
  group_by(price_index) %>%
  mutate(delta_price_lag_1 = lag(log_price, n = 1)-lag(log_price, n = 2),
         delta_price_lag_2 = lag(log_price, n = 2)-lag(log_price, n = 3),
         delta_price_lag_3 = lag(log_price, n = 3)-lag(log_price, n = 4),
         delta_price_lag_4 = lag(log_price, n = 4)-lag(log_price, n = 5),
         delta_price_lag_5 = lag(log_price, n = 5)-lag(log_price, n = 6),
         delta_price_lag_6 = lag(log_price, n = 6)-lag(log_price, n = 7),
         delta_price_lag_7 = lag(log_price, n = 7)-lag(log_price, n = 8),
         delta_price_lag_8 = lag(log_price, n = 8)-lag(log_price, n = 9),
         delta_price_lag_9 = lag(log_price, n = 9)-lag(log_price, n = 10),
         delta_price_lag_10 = lag(log_price, n = 10)-lag(log_price, n = 11),
         delta_price_lag_11 = lag(log_price, n = 11)-lag(log_price, n = 12)) %>%
  ungroup() %>%
  filter(year >= 2001 & year <= 2018)

check_cols(data, c("year","month","yearmonth","price_index","weight_avg","govreg",
                   "log_price","MP_Shock","import_share","debt_cost","D","ND","S",
                   "interestcosts","op_result"),
           what = "estimation_dataset")
check_year_range(data$year, 2001, SAMPLE_END, what = "estimation_dataset")
stopifnot("estimation_dataset lost most of the 3-digit price panel" =
            dplyr::n_distinct(data$price_index) >= 30)

write_dta(data, file.path(DATA, "estimation_dataset.dta"))
message("[prep_data] wrote data/estimation_dataset.dta")
