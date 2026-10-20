## prep_data_main_indices.R -- builds the 16-category panel data/estimation_dataset_main_categories.dta used for the series-by-series responses in Figure 4; sources config.R.
## Run with the working directory set to replication/code/data_prep, or via ../../run_all.R.

# Portable paths: locate the replication root, read inputs from data_prep/ and
# write the .dta output to data/. Run standalone with the working directory set
# to replication/data_prep, or via ../run_all.R.
if (!exists("REPL_ROOT")) source("config.R")
setwd(DATA_PREP)

# load packages
library(readxl)
library(tidyverse)
library(haven)

# load mp shocks
MP_Shocks <- read_excel("MP_Shocks.xlsx", sheet = "Monthly") 

CPI_3_digits_index <- read_excel("CPI_3_digits.xlsx") %>%
  mutate(year = as.integer(substr(Month, 1, 4)),
         month = as.integer(substr(Month, 6, 7))) %>% 
  select(year, month, everything()) %>% 
  select(-Month) %>% 
  filter(year >= 2000 & year <= 2018) %>% 
  mutate_all(as.numeric) %>% 
  rename_with(~ gsub("^\\d+(\\.\\d+)*\\s+", "", .))

CPI_3_digits_weights <- read_excel("CPI_3_digits_weights.xlsx") %>%
  mutate(year = as.integer(substr(Month, 1, 4)),
         month = as.integer(substr(Month, 6, 7))) %>% 
  select(year, month, everything()) %>% 
  select(-Month) %>% 
  filter(year >= 2000 & year <= 2018) %>%  
  mutate_all(as.numeric) %>% 
  rename_with(~ gsub("^\\d+(\\.\\d+)*\\s+", "", .)) %>% 
  rename_with(~paste0(.,"_weight"), .cols = -c("year","month"))

CPI_4_digits_index <- read_excel("CPI_4_digits.xlsx") %>%
  mutate(year = as.integer(substr(Month, 1, 4)),
         month = as.integer(substr(Month, 6, 7))) %>% 
  select(year, month, everything()) %>% 
  select(-Month) %>% 
  filter(year >= 2000 & year <= 2018) %>% 
  mutate_all(as.numeric) %>% 
  rename_with(~ gsub("^\\d+(\\.\\d+)*\\s+", "", .))

CPI_4_digits_weights <- read_excel("CPI_4_digits_weights.xlsx") %>%
  mutate(year = as.integer(substr(Month, 1, 4)),
         month = as.integer(substr(Month, 6, 7))) %>% 
  select(year, month, everything()) %>% 
  select(-Month) %>% 
  filter(year >= 2000 & year <= 2018) %>%  
  mutate_all(as.numeric) %>% 
  rename_with(~ gsub("^\\d+(\\.\\d+)*\\s+", "", .)) %>% 
  rename_with(~paste0(.,"_weight"), .cols = -c("year","month"))

hh_equipment <- CPI_3_digits_index %>% 
  full_join(CPI_3_digits_weights, by=c("year", "month"))  %>% 
  select(year, month, 
         starts_with("Furniture"),
         starts_with("Household textiles"),
         starts_with("Household appliances"),
         starts_with("Glassware"),
         starts_with("Tools")) %>% 
  select(-matches("weight"), matches("weight")) %>%
  rowwise(year, month) %>% 
  summarise(`Household eqpt. and furnishings` = weighted.mean(
    x = c_across(1:5), 
    w = c_across(6:10)))

transport_ex_air <- CPI_4_digits_index %>% 
  full_join(CPI_4_digits_weights, by=c("year", "month"))  %>% 
  select(year, month, 
         starts_with("Passenger transport")) %>% 
  select(-starts_with("Passenger transport by air")) %>% 
  select(-matches("weight"), matches("weight")) %>%
  rowwise(year, month) %>% 
  summarise(`Transportservices excluding air` = weighted.mean(
    x = c_across(1:3), 
    w = c_across(4:6)))

main_indices <- CPI_2_digits_index <- read_excel("CPI_2_digits.xlsx") %>%
  mutate(year = as.integer(substr(Month, 1, 4)),
         month = as.integer(substr(Month, 6, 7))) %>% 
  select(year, month, everything()) %>% 
  select(-Month) %>% 
  filter(year >= 2000 & year <= 2018) %>% 
  mutate_all(as.numeric) %>% 
  rename_with(~ gsub("^\\d+\\s+", "", .)) %>% 
  full_join(CPI_3_digits_index, by=c("year", "month")) %>% 
  full_join(hh_equipment, by=c("year", "month")) %>% 
  full_join(transport_ex_air, by=c("year", "month")) %>% 
  select(year, month, `Food and non-alcoholic beverages`, `Alcoholic beverages and tobacco`, `Household eqpt. and furnishings`, `Clothing and footwear`, `Purchase of vehicles`, `Transportservices excluding air`, `Communications`, `Actual rentals for housing`, `Recreation and culture`, Insurance,`Financial services n.e.c.`, `Restaurant services`, `Accommodation services`, `Electricity, gas and other fuels`, Education, Health) %>% 
  mutate(across(-c(1,2), ~log(.))) %>% 
  mutate(across(-c(1,2), ~.*100)) 

data_main_indices <- main_indices %>% 
  pivot_longer(cols = -c(1,2), names_to = "price_index", values_to = "price") %>% 
  left_join(MP_Shocks, by = c("year" = "Year", "month" = "Month")) %>% # inner_join før
  mutate(yearmonth = as.numeric(paste0(year, str_pad(month, 2, pad = "0")))) %>%
  mutate(price_index = str_replace_all(price_index, "\\.", "")) %>%
  select(year, month, yearmonth,price_index,price,MP_Shock) %>% 
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
         delta_price_lag_11 = lag(log_price, n = 11)-lag(log_price, n = 12)
  ) %>%  
  ungroup() %>%
  filter(year >= 2001 & year <= 2018)

# --- IMPORTANT: figure-number -> COICOP category mapping (see CONSISTENCY_REPORT.md C4)
# In micro_regressions_individual_series.do, `egen id = group(price_index)` assigns
# ids ALPHABETICALLY by the (dot-stripped) price_index strings below. plot_figures.m
# then writes FIG_IRF_PRICE_INDEX_{id}, and the paper hand-picks specific ids. The
# expected alphabetical id -> category mapping is:
#   1 Accommodation services      2 Actual rentals for housing   3 Alcoholic beverages and tobacco
#   4 Clothing and footwear       5 Communications               6 Education
#   7 Electricity, gas ...        8 Financial services n.e.c.    9 Food and non-alcoholic beverages
#  10 Health                     11 Household eqpt. ...          12 Insurance
#  13 Purchase of vehicles       14 Recreation and culture       15 Restaurant services
#  16 Transportservices excluding air
# The assertion below fails if a label change shifts that order (which would silently
# mislabel the paper's Fig. `panel` sub-plots).
.expected_main <- c(
  "Food and non-alcoholic beverages","Alcoholic beverages and tobacco",
  "Household eqpt. and furnishings","Clothing and footwear","Purchase of vehicles",
  "Transportservices excluding air","Communications","Actual rentals for housing",
  "Recreation and culture","Insurance","Financial services nec","Restaurant services",
  "Accommodation services","Electricity, gas and other fuels","Education","Health")
.got_main <- sort(unique(str_replace_all(.expected_main, "\\.", "")))
stopifnot("main-category set changed -> Figure 4 panel mapping would break" =
            setequal(sort(unique(str_replace_all(data_main_indices$price_index, "\\.", ""))),
                     .got_main))
check_year_range(data_main_indices$year, 2001, SAMPLE_END, what = "estimation_dataset_main_categories")

write_dta(data_main_indices, file.path(DATA, "estimation_dataset_main_categories.dta"))

