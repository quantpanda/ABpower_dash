# Smoke test: scrape live AESO data and render the map for every input combination.
# Run from the project root: Rscript tests/smoke_test.R
suppressMessages(suppressWarnings({
  library(shiny)
  source("global.R")
}))

stopifnot(
  "scrape returned no rows" = nrow(generationBySource) > 0,
  "scrape returned no timestamp" = !is.na(generationBySource$date[1]),
  "MC/TNG failed to parse" = !anyNA(generationBySource$MC) && !anyNA(generationBySource$TNG)
)

server <- source("server.R")$value
types <- c("All", unique(generationBySource$type))
gas <- c("All", unique(dplyr::filter(generationBySource, type == "GAS")$subtype))
failures <- character()

testServer(server, {
  for (t in types) for (g in gas) for (col in c("MC_sum", "TNG_sum", "cap_prop")) {
    session$setInputs(typeInput = t, gasInput = g, colInput = col)
    err <- tryCatch({ output$alberta_map; NULL }, error = function(e) conditionMessage(e))
    if (!is.null(err)) failures <<- c(failures, paste(t, g, col, "->", err))
  }
})

unmapped <- dplyr::filter(generationBySource, is.na(Area_ID))
message(sprintf("Unmapped assets: %d (%.0f MW capacity not shown on map)", nrow(unmapped), sum(unmapped$MC)))

if (length(failures) > 0) stop("Map failed to render:\n", paste(failures, collapse = "\n"))
message("Smoke test passed: ", nrow(generationBySource), " assets, ",
        length(types) * length(gas) * 3, " input combinations rendered")
