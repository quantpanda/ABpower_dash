library(shiny)
library(tidyverse)
library(readxl)
library(maps)
library(sf)
library(rvest)
library(grDevices)



boundaries_1 <- st_read("AESO-Planning-Areas-2020-06-23/AESO_Planning_Areas.shp") 
# Make sf object
boundaries <- sf::st_as_sf(boundaries_1, coords = c("long", "lat"), crs = "+proj=longlat +datum=NAD83 +no_defs") %>% 
  sf::st_transform( crs = "+proj=longlat +datum=WGS84") %>% 
  dplyr::mutate(Area_ID = as.numeric(Area_ID)) %>% 
  dplyr::arrange(desc(Area_ID))


# asset -> planning area lookup; rebuild with data-raw/build_asset_lookup.R
genFile <- read_csv("data/asset_planning_area.csv", show_col_types = FALSE) %>%
  dplyr::select(assetID, Area_ID, region)

# Scrape function
scrapeGen <- function(aesoDashSource ){
  
  AESOsimpleTable <- function(table, subtype) {
    summary <- aesoDashSource %>% 
      html_elements(css = "table") %>% 
      .[table] %>% 
      html_table() %>% 
      .[[1]] 
    
    dateMST <- aesoDashSource %>% 
      rvest::html_elements(css = "table") %>% 
      .[5] %>% 
      rvest::html_text() %>% 
      .[[1]]
    
    dateMST <- stringr::str_extract(dateMST[1], "\\w{3} \\d{2}, \\d{4} \\d{2}:\\d{2}") %>% 
      stringr::str_replace(",", "") %>% 
      lubridate::mdy_hm(tz = "America/Denver")
    
    colNames <- c("ASSET", "MC", "TNG", "DCR")
    
    type <- colnames(summary)
    colnames(summary) <- colNames
    
    summary <- summary %>% 
      dplyr::mutate(type = type[[1]]) %>% 
      # no applicable subtype; placeholder
      dplyr::mutate(subtype = subtype) %>% 
      # redudant first row
      dplyr::filter(!ASSET %in% c("ASSET", "GROUP")) %>% 
      dplyr::mutate(date = dateMST)
    
    return(summary)
  }
  
  # gas table
  gas <- aesoDashSource %>% 
    rvest::html_elements(css = "table") %>% 
    .[11] %>% 
    rvest::html_table() %>% 
    .[[1]] 
  
  # defining col names to be utilized
  colNames <- c("ASSET", "MC", "TNG", "DCR")
  
  # taking existing col names for type column
  type <- colnames(gas)
  
  # overwriting col names with def list
  colnames(gas) <- colNames
  
  
  dateMST <- aesoDashSource %>% 
    rvest::html_elements(css = "table") %>% 
    .[5] %>% 
    rvest::html_text() %>% 
    .[[1]]
  
  dateMST <- stringr::str_extract(dateMST[1], "\\w{3} \\d{2}, \\d{4} \\d{2}:\\d{2}") %>% 
    stringr::str_replace(",", "") %>% 
    lubridate::mdy_hm(tz = "America/Denver")
  
  
  gas <- gas %>% 
    #adding type, per original column names at import
    dplyr::mutate(type = type[[1]]) %>% 
    # finding divisional row, and where present, using them to define subtype
    dplyr::mutate(subtype = case_when(
      ASSET %in% c("Simple Cycle", "Cogeneration", "Combined Cycle", "Gas Fired Steam") ~ ASSET)) %>% 
    # fill remainder of subtype until new subtype
    tidyr::fill(subtype, .direction = c("down")) %>% 
    # removing divisional rows (now that they are in column subtype)
    dplyr::filter(!ASSET %in% 
             c("Simple Cycle", "Cogeneration", "Combined Cycle", "Gas Fired Steam", "ASSET")) %>% 
    dplyr::mutate(date = dateMST)
  
  hydro <- AESOsimpleTable(13, "hydro")
  
  energyStor <- AESOsimpleTable(14, "energy storage")
  
  solar <- AESOsimpleTable(15, "solar")
  
  wind <- AESOsimpleTable(17, "wind")
  
  bioAndOther <- AESOsimpleTable(18, "biomass and other")
  
  generationBySource <- rbind(gas, hydro, energyStor, solar, wind, bioAndOther)
  
  generationBySource <- generationBySource %>%
    dplyr::mutate(assetID = str_extract(ASSET, "\\([A-Z0-9]{3,4}\\)")) %>%
    dplyr::mutate(assetID = str_remove_all(assetID, "[\\(\\)]"))
  
  # extracting names from shape file to append to generation file
  boundariesJoin <- data.frame(boundaries$Area_ID, boundaries$NAME) %>% 
    dplyr::rename(Area_ID = boundaries.Area_ID, 
           Area_IDName = boundaries.NAME) %>% 
    dplyr::mutate(Area_ID = as.numeric(Area_ID))
  
  #adding planning area
  generationBySource <- dplyr::left_join(generationBySource, genFile, by = 'assetID')
  
  #adding names assoc. w/ each planning area
  generationBySource <- dplyr::left_join(generationBySource, boundariesJoin, by = 'Area_ID') %>% 
    dplyr::mutate(MC = as.numeric(MC),
           TNG = as.numeric(TNG),
           DCR = as.numeric(DCR)) 
  
  return(generationBySource)
}


generationBySource <- scrapeGen(rvest::read_html('http://ets.aeso.ca/ets_web/ip/Market/Reports/CSDReportServlet'))
