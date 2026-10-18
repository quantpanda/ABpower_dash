library(shiny)
library(dplyr)
library(ggplot2)
library(plotly)
library(leaflet)

# Define server logic
function(input, output, session) {
  
  # Reactive value to store the fetched data
  reactiveGenerationBySource <- reactiveVal()
  
  # Function to fetch and update data
  updateData <- function() {
              newData <- scrapeGen(read_html('http://ets.aeso.ca/ets_web/ip/Market/Reports/CSDReportServlet'))
              reactiveGenerationBySource(newData)
  }
  
  updateData()
  
  shiny::observeEvent(input$refreshBtn, {
    updateData()})
  
  # reactive expression for filtering
  filteredData <- shiny::reactive({
                  
                  data <- reactiveGenerationBySource()
                  
                  if (input$typeInput != "All") {
                    data <- data %>%
                      dplyr::filter(type == input$typeInput)
                    # gasInput keeps its value while hidden, so only apply it to GAS
                    if (input$typeInput == "GAS" && input$gasInput != "All") {
                      data <- data %>%
                        dplyr::filter(subtype == input$gasInput)
                    }
                  }

                  result <- data %>%
                    dplyr::group_by(Area_ID) %>%
                    dplyr::summarise(MC_sum = sum(MC), TNG_sum = sum(TNG), date = date[1]) %>%
                    dplyr::right_join(boundaries, by = "Area_ID") %>%
                    tidyr::replace_na(list(MC_sum = 0, TNG_sum = 0, date = data$date[1])) %>%
                    # utilization is undefined (NA) where an area has no capacity
                    dplyr::mutate(cap_prop = dplyr::if_else(MC_sum > 0, round(TNG_sum / MC_sum * 100, 1), NA_real_))
                  result
                })

  output$currentDate <- shiny::renderText({
    paste("Last Update: ", format(reactiveGenerationBySource()$date[1], "%b %d, %Y %H:%M %Z"))
  })
  
  # Render the filtered map
  output$alberta_map <- leaflet::renderLeaflet({
    # get the filtered data
    map_data <- filteredData()
    # align rows with the polygon order of boundaries
    map_data <- map_data[match(boundaries$Area_ID, map_data$Area_ID), ]
    # get user input for desired output
    var_x <- map_data[[input$colInput]]
    # floor of 1 keeps the breaks unique when every area is zero or NA
    range_max <- max(c(var_x, 1), na.rm = TRUE)
    # pretty() always returns unique, increasing breaks that cover range_max
    dynamic_bins <- pretty(c(0, range_max), n = 6)
    # color palette; grey for areas with no capacity (NA utilization)
    pal <- leaflet::colorBin(c("YlOrRd"), domain = var_x, bins = dynamic_bins, na.color = "#bdbdbd")

    labss <- lapply(1:nrow(map_data), function(i) {
      util <- if (is.na(map_data$cap_prop[i])) "n/a (no capacity)" else paste0(map_data$cap_prop[i], "%")
      shiny::HTML(paste("Area: ", map_data$NAME[i], "<br>",
                 "Maximum Capacity: ", map_data$MC_sum[i], "MW", "<br>",
                 "Current Output: ", map_data$TNG_sum[i], "MW", "<br>",
                 "Current Utilization Rate: ", util))
      }
    )
    
    leaflet::leaflet() %>%
      leaflet::addTiles() %>%
      leaflet::addPolygons(data = boundaries,
                           fillColor = ~pal(var_x),
                           fillOpacity = 0.75,
                           color = "black",
                           opacity = 1,
                           stroke = T,
                           weight = 1,
                           label = labss,
                           highlightOptions = highlightOptions(
                             weight = 5,
                             color = "#000",
                             bringToFront = TRUE)) %>% 
      leaflet::addLegend(pal = pal, values = var_x,
                         title = c(MC_sum = "Maximum Capacity (MW)",
                                   TNG_sum = "Current Output (MW)",
                                   cap_prop = "Utilization (%)")[[input$colInput]],
                         na.label = "No capacity")
    }
  )
}

