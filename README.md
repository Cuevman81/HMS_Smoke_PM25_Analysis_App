# HMS_Smoke_PM25_Analysis_App
This Shiny R app pulls and visualizes PM2.5 air quality data from the EPA's air quality system and incorporates HMS Smoke data.

This is a continuous work in progress as I strive to improve and make the app more useful, especially for agencies needing to perform Exceptional Event Demonstrations for PM2.5 revised NAAQS. Any ideas to enhance the app's functionality are always welcome.

---

# PM2.5 and HMS Smoke Visualization Shiny App

## Overview

This Shiny R app is designed to pull and visualize PM2.5 air quality data from the EPA's air quality system and incorporate HMS Smoke data. It provides an intuitive interface for users to explore and analyze air quality trends and the impact of smoke from fires.

## Features

- **Data Retrieval**: Automatically pulls the latest PM2.5 data from the EPA's air quality system.
- **HMS Smoke Integration**: Incorporates data from the Hazard Mapping System (HMS) Smoke product to visualize smoke plumes and their impact on air quality.
- **Interactive Visualizations**: Provides various plots and charts to help users understand air quality trends over time and space.
- **User-Friendly Interface**: Designed with ease of use in mind, allowing users to interact with the data without needing advanced technical skills.

## Installation

To run this Shiny app locally, follow these steps:

1. **Clone the repository**:
    ```bash
    git clone https://github.com/Cuevman81/HMS_Smoke_PM25_Analysis_App.git
    cd HMS_Smoke_PM25_Analysis_App
    ```

2. **Install required packages**:
    Open your R console or RStudio and run:
    ```R
    install.packages(c("shiny", "dplyr", "ggplot2", "leaflet", "httr", "jsonlite", "maps", "sf", "DT", "lubridate"))
    ```

3. **Run the app**:
    ```R
    shiny::runApp("path/to/your/app/directory")
    ```

## Usage

Once the app is running, users can:

1. **Select Date Range**: Choose the time period for which they want to view the air quality data.
2. **View PM2.5 Data**: Visualize PM2.5 concentrations through various plots and maps.
3. **Analyze Smoke Impact**: Examine the overlay of HMS Smoke data on PM2.5 measurements to understand the correlation between smoke and air quality.
4. **Export Data**: Download the data for further analysis.

![Example_HMS_PM25_Plot](https://github.com/user-attachments/assets/0ee82602-de67-4a90-836a-b20e5a6bf390)

## Data Sources

- **AirNow File Products**: AirNow file products provide various data outputs to members of the broad user community who want access to real-time air quality data and air quality forecasts. Several types of data products and formats are available. File Products can be accessed at files.airnowtech.org. 
- **Hazard Mapping System (HMS) Smoke**: Offers data on smoke plumes detected via satellite, which can be correlated with air quality measurements.


## Contributing

We welcome contributions to enhance the functionality and usability of this app. If you would like to contribute, please follow these steps:

1. Fork the repository.
2. Create a new branch (`git checkout -b feature-branch`).
3. Make your changes and commit them (`git commit -am 'Add new feature'`).
4. Push to the branch (`git push origin feature-branch`).
5. Create a new Pull Request.

## License

This project is licensed under the MIT License. See the [LICENSE](LICENSE) file for details.

## Contact

For questions or feedback, please contact Rodney Cuevas at [RCuevas@mdeq.ms.gov](mailto:RCuevas@mdeq.ms.gov).

---

Feel free to modify any part of this README to better suit your project's specifics or add any additional information you think is necessary.
