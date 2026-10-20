## derive_import_shares.R -- derives the import content of household consumption by CPA sector from the 2012 WIOD table for Norway (Dhyne et al., 2023, Section II.D); sources config.R.
## Run with the working directory set to replication/code/data_prep, or via ../../run_all.R.
# Here we derive import shares at the NACE level, following the STATA-replication code for Belgian data in Dhyne, Kikkawa, Mogstad, and Tintelnot (2023, Section II.D) 
# and the 2012 Norwegian IO table from the World Input Output Database

# Portable paths: locate the replication root and read/write within data_prep/.
# Run standalone with the working directory set to replication/data_prep, or via
# ../run_all.R.
if (!exists("REPL_ROOT")) source("config.R")
setwd(DATA_PREP)

library(readxl)
library(openxlsx)
library(tidyverse)

year <- 2012

NOR_NIOT_nov16 <- read_excel("NOR_NIOT_nov16.xlsx", sheet = "National IO-tables")

sectors <- NOR_NIOT_nov16 %>%
  filter(Year == year,
         Origin == "Domestic") %>%
  select(Code, Description)

NOR_NIOT <- NOR_NIOT_nov16 %>%
  slice(-1) %>% # remove descriptive row
  filter(Year == year) %>% # filter 2012 IO table
  filter(!(Code %in% c("II_fob","TXSP","EXP_adj","PURR","PURNR", "IntTTM", "GO"))) # Remove rows: Total intermediate consumption, 
# Taxes less subsidies on products, Cif/ fob adjustments on exports, Direct purchases abroad by residents,
# Purchases on the domestic territory by non-residents, International Transport Margins and Output at basic prices


imports <- NOR_NIOT %>% 
  filter(Origin == "Imports") %>%
  select(-c(1:4)) %>%
  mutate_all(as.numeric) %>%
  summarise_all(sum) %>% # find sum of direct imports in each industry
  mutate(cpa = "FOR") %>%
  select(cpa, everything())

dom_IO <- NOR_NIOT %>% # domestic IO table
  rename(cpa=Code) %>%
  filter(Origin != "Imports") %>%
  select(-Year, -Description, -Origin) %>%
  mutate(across(-1, as.numeric)) %>%
  bind_rows(imports) %>%
  mutate(FINAL = CONS_h	+ CONS_np	+ CONS_g + GFCF + INVEN) %>%
  rename(FOR=EXP) %>%
  select(-c(CONS_h, CONS_np, CONS_g, GFCF, INVEN, GO))

# data clean finish


# compute input shares
data_IOTable <- dom_IO %>% # transform IO table to long df
  pivot_longer(!cpa, names_to = "cpa_j", values_to = "value") %>%
  rename(cpa_i = cpa) %>%
  mutate(value = ifelse(value < 0, 0, value)) %>%  
  filter(!(cpa_i %in% c("U")) & 
           !(cpa_j %in% c("U"))) %>% # Remove Activities of extraterritorial organizations and bodies
  filter(!(cpa_j %in% c("FOR","FINAL"))) %>% # remove exports and final demand
  group_by(cpa_j) %>% 
  mutate(tot_purchase = sum(value)) %>% # sum of inputs (total purchases) in each sector j
  ungroup() %>%
  mutate(share = value / tot_purchase) %>% 
  select(-c(value, tot_purchase)) # each input's share of total inputs (purchases) in industry j
  
  
# df with domestic inputs only
domestic_inputs <- data_IOTable %>%
  filter(cpa_i != "FOR") # exclude imported inputs

# df with imported inputs only
imported_inputs <- data_IOTable %>%
  filter(cpa_i == "FOR") # keep only imported inputs

# guess and iterate to find import share (direct + indirect)

count <- 1
error <- 1000000
threshold <- 1e-10

s_Fi_total_IOTable <- imported_inputs %>%
  select(-cpa_i) %>%
  rename(cpa = cpa_j,
         s_Fi = share) %>%
  mutate(s_Fi_total_IOTable = s_Fi,
         s_Fi_total_IOTable_new = 0) 

while (error > threshold) {
  print(count)
  s_Fi_total_IOTable <- s_Fi_total_IOTable %>%
    rename(cpa_i = cpa) %>% 
    merge(domestic_inputs, by = "cpa_i") %>%
    mutate(tt = s_Fi_total_IOTable * share) %>% # compute indirect imports
    group_by(cpa_j) %>% 
    summarize(tt = sum(tt)) %>% # sum of indirect imports
    ungroup() %>%
    rename(cpa = cpa_j) %>%
    full_join(s_Fi_total_IOTable, by = "cpa") %>% 
    mutate(s_Fi_total_IOTable_new = s_Fi + tt) %>% # sum of direct and indirect import share
    mutate(diff = abs((s_Fi_total_IOTable_new - s_Fi_total_IOTable) / s_Fi_total_IOTable)) # percent difference from last iteration
  
  error <- max(s_Fi_total_IOTable$diff, na.rm = TRUE)   # Update error
  
  s_Fi_total_IOTable <- s_Fi_total_IOTable %>%
    mutate(s_Fi_total_IOTable = s_Fi_total_IOTable_new) %>% 
    select(-c(tt, diff)) 
  
  count <- count + 1
}

import_share_domestic_production <- s_Fi_total_IOTable %>%
  select(-s_Fi_total_IOTable_new) %>%
  rename(Code=cpa,
         import_s_dom_prod = s_Fi_total_IOTable) %>%
  full_join(sectors, by="Code") %>%
  select(Description, everything())

# find the respective shares of imported and domestically produced goods in household final consumption
share_cons <- NOR_NIOT %>%
  mutate(CONS_h = as.numeric(CONS_h)) %>%
  group_by(Code) %>%
  mutate(total = sum(CONS_h)) %>%
  mutate(share = CONS_h / total) %>%
  select(Code, Description, Origin, share)

cpa_import_share <- share_cons %>%
  filter(Origin == "Domestic") %>%
  rename(domestic_share_consumption = share) %>%
  select(Code, Description, domestic_share_consumption) %>%
  full_join(import_share_domestic_production, by = "Code") %>%
  mutate(total_import_share_cons_h = domestic_share_consumption*import_s_dom_prod + (1-domestic_share_consumption))

# prep_data.R joins on `Code` and uses `total_import_share_cons_h`; assert they exist
check_cols(cpa_import_share, c("Code", "total_import_share_cons_h"),
           what = "cpa_import_share")
write.xlsx(cpa_import_share, "cpa_import_share.xlsx", rowNames = FALSE)
