# Rebuild data/asset_planning_area.csv from AESO "CSD Generation (Hourly)" files.
#
# Download the latest monthly zip from the "Hourly" folder of AESO's Historical
# Generation Data (CSD): https://aeso.box.com/s/qofgn9axnnw6uq3ip1goiq2ngb11txe5
# (linked from aeso.ca > Market > Data Requests > Historical Generation Data),
# unzip it, then run from the project root:
#
#   Rscript data-raw/build_asset_lookup.R "path/to/CSD Generation (Hourly) - YYYY-MM.csv" [...]
#
# Rows from the given files replace existing rows for the same asset; assets not in
# the new files (e.g. retired units) are kept. When several files are given, the
# latest month wins.
suppressMessages(library(dplyr))

lookup_path <- "data/asset_planning_area.csv"
files <- commandArgs(trailingOnly = TRUE)
if (length(files) == 0) stop("Pass one or more CSD Generation (Hourly) CSV files")

read_csd <- function(f) {
  readr::read_csv(f, show_col_types = FALSE,
                  col_select = c(`Date (MPT)`, `Asset Short Name`, `Planning Area`, Region)) %>%
    group_by(assetID = `Asset Short Name`) %>%
    # an asset's latest record in the file wins
    slice_max(`Date (MPT)`, n = 1, with_ties = FALSE) %>%
    ungroup() %>%
    transmute(assetID, Area_ID = as.integer(`Planning Area`), region = Region,
              as_of = format(`Date (MPT)`, "%Y-%m"))
}

new <- bind_rows(lapply(files, read_csd)) %>%
  group_by(assetID) %>%
  slice_max(as_of, n = 1, with_ties = FALSE) %>%
  ungroup()

old <- if (file.exists(lookup_path)) readr::read_csv(lookup_path, show_col_types = FALSE) else new[0, ]

changed <- inner_join(new, old, by = "assetID", suffix = c("", ".old")) %>%
  filter(Area_ID != Area_ID.old)
if (nrow(changed) > 0) {
  message("Planning area changed for: ",
          paste0(changed$assetID, " (", changed$Area_ID.old, " -> ", changed$Area_ID, ")", collapse = ", "))
}

out <- bind_rows(new, anti_join(old, new, by = "assetID")) %>% arrange(assetID)
readr::write_csv(out, lookup_path)
message(sprintf("Wrote %s: %d assets (%d new, %d kept from previous lookup)",
                lookup_path, nrow(out), nrow(anti_join(new, old, by = "assetID")),
                nrow(anti_join(old, new, by = "assetID"))))
