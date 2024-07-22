library(shiny)
library(dplyr)
library(readr)
library(sf)
library(maps)
library(ggplot2)
library(lubridate)
library(DT)

# State code to name mapping
state_code_to_name <- c(
  "01" = "alabama", "02" = "alaska", "04" = "arizona", "05" = "arkansas", 
  "06" = "california", "08" = "colorado", "09" = "connecticut", "10" = "delaware", 
  "11" = "district of columbia", "12" = "florida", "13" = "georgia", "15" = "hawaii", 
  "16" = "idaho", "17" = "illinois", "18" = "indiana", "19" = "iowa", 
  "20" = "kansas", "21" = "kentucky", "22" = "louisiana", "23" = "maine", 
  "24" = "maryland", "25" = "massachusetts", "26" = "michigan", "27" = "minnesota", 
  "28" = "mississippi", "29" = "missouri", "30" = "montana", "31" = "nebraska", 
  "32" = "nevada", "33" = "new hampshire", "34" = "new jersey", "35" = "new mexico", 
  "36" = "new york", "37" = "north carolina", "38" = "north dakota", "39" = "ohio", 
  "40" = "oklahoma", "41" = "oregon", "42" = "pennsylvania", "44" = "rhode island", 
  "45" = "south carolina", "46" = "south dakota", "47" = "tennessee", "48" = "texas", 
  "49" = "utah", "50" = "vermont", "51" = "virginia", "53" = "washington", 
  "54" = "west virginia", "55" = "wisconsin", "56" = "wyoming"
)

ui <- fluidPage(
  titlePanel("PM2.5 and HMS Smoke Data Analysis"),
  
  sidebarLayout(
    sidebarPanel(
      dateRangeInput("dateRange", "Date Range", start = Sys.Date() - 30, end = Sys.Date()),
      actionButton("downloadData", "Download Data"),
      selectInput("stateCode", "State Code", choices = NULL),
      selectInput("countyCode", "County Code", choices = NULL),
      selectInput("siteId", "Site ID", choices = NULL),
      checkboxGroupInput("smokeIntensity", "Smoke Intensity", 
                         choices = c("Light", "Medium", "Heavy"),
                         selected = c("Light", "Medium", "Heavy")),
      actionButton("processHMSData", "Process HMS Smoke Data")
    ),
    
    mainPanel(
      tabsetPanel(
        tabPanel("PM2.5 Data", DTOutput("dataTable")),
        tabPanel("Combined Data", DTOutput("combinedDataTable")),
        tabPanel("HMS Plot", 
                 fluidRow(
                   column(12, 
                          selectizeInput("selectedSitenames", "Select Sitenames", 
                                         choices = NULL, multiple = TRUE,
                                         options = list(placeholder = 'Select sitenames to display')),
                          plotOutput("hmsPlot", height = "900px", width = "100%"),
                          tags$style(type="text/css", "#hmsPlot.recalculating { opacity: 1.0; }")
                   )
                 )
        ),
        tabPanel("Filtered Data",
                 fluidRow(
                   column(3,
                          numericInput("pm25Threshold", "PM2.5 Threshold (μg/m³)", value = 15, min = 0, step = 0.1),
                          checkboxGroupInput("filteredSmokeIntensity", "Smoke Intensity", 
                                             choices = c("Light", "Medium", "Heavy"),
                                             selected = c("Medium", "Heavy"))
                   ),
                   column(9,
                          DTOutput("filteredDataTable"),
                          downloadButton("downloadFilteredData", "Download Filtered Data")
                   )
                 )
        )
      )
    )
  )
)

server <- function(input, output, session) {
  
  pm25Data <- reactiveVal(NULL)
  combinedData <- reactiveVal(NULL)
  
  observeEvent(input$downloadData, {
    withProgress(message = 'Downloading AirNow data', value = 0, {
      start_date <- input$dateRange[1]
      end_date <- input$dateRange[2]
      num_days <- as.integer(end_date - start_date)
      
      all_data <- data.frame()
      
      for (i in 0:num_days) {
        incProgress(1/(num_days+1), detail = paste("Processing day", i+1, "of", num_days+1))
        date <- start_date + i
        year <- format(date, "%Y")
        yyyymmdd <- format(date, "%Y%m%d")
        
        url <- paste0("https://s3-us-west-1.amazonaws.com//files.airnowtech.org/airnow/", year, "/", yyyymmdd, "/daily_data_v2.dat")
        
        tryCatch({
          data <- read_delim(url, delim = "|", col_names = c("Valid_date", "AQSID", "Sitename", "Parameter_name", "Reporting_units", "Value", "Averaging_period", "Data_Source", "AQI_Value", "AQI_Category", "Latitude", "Longitude", "Full_AQSID"))
          
          data <- data %>%
            mutate(
              Valid_date = mdy(Valid_date),
              Latitude = as.numeric(Latitude),
              Longitude = as.numeric(Longitude),
              Value = as.numeric(Value),
              State_Code = substr(AQSID, 1, 2),
              County_Code = substr(AQSID, 3, 5),
              Site_ID = substr(AQSID, 6, 9)
            ) %>%
            filter(Parameter_name == "PM2.5-24hr")
          
          all_data <- rbind(all_data, data)
        }, error = function(e) {
          showNotification(paste("Error downloading data for", yyyymmdd, ":", e$message), type = "warning")
        })
      }
      
      pm25Data(all_data)
      updateSelectInput(session, "stateCode", choices = c("ALL", sort(unique(all_data$State_Code))))
    })
  })
  
  observe({
    req(pm25Data())
    state_code <- input$stateCode
    
    if (state_code == "ALL") {
      county_choices <- c("ALL", sort(unique(pm25Data()$County_Code)))
    } else {
      county_choices <- c("ALL", sort(unique(pm25Data()[pm25Data()$State_Code == state_code, ]$County_Code)))
    }
    
    updateSelectInput(session, "countyCode", choices = county_choices)
  })
  
  observe({
    req(pm25Data(), input$stateCode, input$countyCode)
    state_code <- input$stateCode
    county_code <- input$countyCode
    
    if (state_code == "ALL" && county_code == "ALL") {
      site_choices <- c("ALL", sort(unique(pm25Data()$Site_ID)))
    } else if (state_code != "ALL" && county_code == "ALL") {
      site_choices <- c("ALL", sort(unique(pm25Data()[pm25Data()$State_Code == state_code, ]$Site_ID)))
    } else if (state_code != "ALL" && county_code != "ALL") {
      site_choices <- c("ALL", sort(unique(pm25Data()[pm25Data()$State_Code == state_code & pm25Data()$County_Code == county_code, ]$Site_ID)))
    } else {
      site_choices <- c("ALL")
    }
    
    updateSelectInput(session, "siteId", choices = site_choices)
  })
  
  observe({
    req(combinedData())
    updateSelectizeInput(session, "selectedSitenames", 
                         choices = unique(combinedData()$Sitename),
                         selected = NULL)
  })
  
  filteredPM25Data <- reactive({
    req(pm25Data(), input$stateCode)
    data <- pm25Data()
    
    if (input$stateCode != "ALL") {
      data <- data[data$State_Code == input$stateCode, ]
    }
    
    if (input$countyCode != "ALL") {
      data <- data[data$County_Code == input$countyCode, ]
    }
    
    if (input$siteId != "ALL") {
      data <- data[data$Site_ID == input$siteId, ]
    }
    
    data
  })
  
  output$dataTable <- renderDT({
    req(filteredPM25Data())
    filteredPM25Data() %>%
      mutate(Valid_date = format(Valid_date, "%Y-%m-%d")) %>%
      datatable(options = list(pageLength = 15, 
                               lengthMenu = c(15, 30, 50), 
                               scrollX = TRUE))
  })
  
  observeEvent(input$processHMSData, {
    req(filteredPM25Data(), input$dateRange)
    
    withProgress(message = 'Processing HMS Smoke data', value = 0, {
      state_pm25_data <- filteredPM25Data()
      
      if (!all(c("Latitude", "Longitude") %in% names(state_pm25_data))) {
        showNotification("Latitude and Longitude columns not found in PM2.5 data.", type = "error")
        return(NULL)
      }
      
      # Get the map data for the selected state(s)
      if (input$stateCode == "ALL") {
        state_names <- unique(state_code_to_name[unique(state_pm25_data$State_Code)])
      } else {
        state_names <- state_code_to_name[input$stateCode]
      }
      
      if (any(is.na(state_names))) {
        showNotification(paste("Invalid state code(s) found:", 
                               paste(input$stateCode[is.na(state_names)], collapse = ", ")), 
                         type = "error")
        return(NULL)
      }
      
      us_states <- maps::map("state", fill = TRUE, plot = FALSE)
      us_states_sf <- st_as_sf(us_states)
      state_sf <- us_states_sf[tolower(us_states_sf$ID) %in% state_names, ]
      
      if (nrow(state_sf) == 0) {
        showNotification(paste("State(s) not found:", paste(state_names, collapse = ", ")), type = "error")
        return(NULL)
      }
      
      state_sf_transformed <- st_transform(state_sf, 4326)
      
      # Convert PM2.5 sites to sf object
      sites_sf <- st_as_sf(state_pm25_data, coords = c("Longitude", "Latitude"), crs = 4326)
      
      read_kml <- function(date, layer) {
        url <- paste0("https://satepsanone.nesdis.noaa.gov/pub/FIRE/web/HMS/Smoke_Polygons/KML/", 
                      format(date, "%Y/%m/hms_smoke"), format(date, "%Y%m%d"), ".kml")
        
        tryCatch({
          kml_data <- st_read(url, layer = layer, quiet = TRUE)
          kml_data_valid <- st_make_valid(kml_data)
          
          # Intersect with the state boundary first
          state_smoke <- st_intersection(kml_data_valid, state_sf_transformed)
          
          if (nrow(state_smoke) == 0) return(NULL)
          
          # Then intersect with the sites
          sites_data <- st_intersection(state_smoke, sites_sf)
          
          if (nrow(sites_data) == 0) return(NULL)
          
          sites_data$date <- as.Date(date)
          sites_data$Smoke_Intensity <- layer
          sites_data
        }, error = function(e) {
          warning(paste("Failed to read layer", layer, "for date", date, ":", e$message))
          return(NULL)
        })
      }
      
      dates <- seq.Date(input$dateRange[1], input$dateRange[2], by = "day")
      layers <- paste0("Smoke (", input$smokeIntensity, ")")
      
      all_data <- lapply(dates, function(date) {
        incProgress(1/length(dates), detail = paste("Processing", date))
        lapply(layers, function(layer) read_kml(date, layer))
      })
      
      all_data <- unlist(all_data, recursive = FALSE)
      all_data <- Filter(Negate(is.null), all_data)
      
      if (length(all_data) == 0) {
        showNotification(paste("No HMS Smoke data available for the selected area, dates, and smoke intensities."), type = "warning")
        return(NULL)
      }
      
      combined_data <- do.call(rbind, all_data)
      
      pm25_join <- state_pm25_data %>%
        select(AQSID, Valid_date, Averaging_period, Value, Sitename) %>%
        distinct()  # Ensure no duplicates in PM2.5 data
      
      smoke_intensity_order <- c("Smoke (Heavy)" = 3, "Smoke (Medium)" = 2, "Smoke (Light)" = 1)
      
      combined_data <- combined_data %>%
        st_drop_geometry() %>%
        mutate(date = as.Date(date)) %>%
        select(AQSID, date, Smoke_Intensity) %>%
        distinct() %>%  # Remove duplicates from smoke data
        left_join(pm25_join, by = c("AQSID", "date" = "Valid_date")) %>%
        filter(!is.na(Averaging_period)) %>%  # Remove rows where join didn't match
        mutate(Smoke_Intensity = gsub("Smoke \\((.*)\\)", "\\1", Smoke_Intensity)) %>%  # Remove "Smoke ()" from intensity
        mutate(smoke_intensity_value = case_when(
          Smoke_Intensity == "Heavy" ~ 3,
          Smoke_Intensity == "Medium" ~ 2,
          Smoke_Intensity == "Light" ~ 1,
          TRUE ~ 0
        )) %>%
        group_by(AQSID, date, Averaging_period) %>%
        slice_max(order_by = smoke_intensity_value, n = 1, with_ties = FALSE) %>%
        ungroup() %>%
        select(-smoke_intensity_value) %>%
        arrange(AQSID, date, desc(factor(Smoke_Intensity, levels = c("Heavy", "Medium", "Light"))), Averaging_period)
      
      combinedData(combined_data)
    })
  })
  
  output$combinedDataTable <- renderDT({
    req(combinedData())
    combinedData() %>%
      mutate(date = format(date, "%Y-%m-%d")) %>%
      select(AQSID, date, Smoke_Intensity, Averaging_period, Value, Sitename) %>%
      datatable(options = list(pageLength = 15, 
                               lengthMenu = c(15, 30, 50), 
                               scrollX = TRUE))
  })
  
  output$hmsPlot <- renderPlot({
    req(combinedData())
    req(input$selectedSitenames)
    
    filtered_data <- combinedData() %>%
      filter(!is.na(Sitename),
             Sitename %in% input$selectedSitenames) %>%
      mutate(
        Averaging_period = factor(Averaging_period,
                                  levels = c(24),
                                  labels = c("24-hour")),
        Smoke_Intensity = factor(Smoke_Intensity, 
                                 levels = c("Light", "Medium", "Heavy"))
      )
    
    color_mapping <- c("Light" = "lightblue", "Medium" = "darkgrey", "Heavy" = "black")
    
    ggplot(filtered_data, aes(x = date, y = Value, color = Smoke_Intensity)) +
      geom_point(size = 3, na.rm = TRUE) +
      geom_text(aes(label = round(Value, 1)), vjust = -1, size = 3, na.rm = TRUE) +
      scale_color_manual(values = color_mapping) +
      theme_minimal() +
      theme(
        axis.text.x = element_text(angle = 45, hjust = 1, size = 8),
        axis.text.y = element_text(size = 8),
        strip.text = element_text(size = 10),
        axis.title = element_text(size = 12),
        legend.title = element_text(size = 10),
        legend.text = element_text(size = 8),
        plot.margin = margin(5, 5, 5, 5),
        panel.spacing = unit(1, "lines")
      ) +
      labs(x = "Date", y = "PM2.5 (μg/m³)", color = "Smoke Intensity") +
      facet_wrap(~ Sitename, scales = "free_y", ncol = min(3, length(input$selectedSitenames))) +
      scale_x_date(date_breaks = "1 day", date_labels = "%b %d") +
      coord_cartesian(clip = "off") +
      labs(subtitle = paste("Averaging Period:", unique(filtered_data$Averaging_period)))
  }, res = 96)
  
  # New reactive for filtered data
  filteredData <- reactive({
    req(combinedData())
    req(input$pm25Threshold)
    req(input$filteredSmokeIntensity)
    
    combinedData() %>%
      filter(Value >= input$pm25Threshold,
             Smoke_Intensity %in% input$filteredSmokeIntensity)
  })
  
  # Render the filtered data table
  output$filteredDataTable <- renderDT({
    req(filteredData())
    filteredData() %>%
      mutate(date = format(date, "%Y-%m-%d")) %>%
      select(AQSID, date, Smoke_Intensity, Averaging_period, Value, Sitename) %>%
      datatable(options = list(pageLength = 15, 
                               lengthMenu = c(15, 30, 50), 
                               scrollX = TRUE))
  })
  
  # Download handler for filtered data
  output$downloadFilteredData <- downloadHandler(
    filename = function() {
      paste0("filtered_data_", Sys.Date(), ".csv")
    },
    content = function(file) {
      data_to_save <- filteredData()
      write.csv(data_to_save, file, row.names = FALSE)
    },
    contentType = "text/csv"
  )
}

shinyApp(ui = ui, server = server)