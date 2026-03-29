#IMPORTANT: This script requires the aridity index ai_v31_yr.tif which needs to be acquired externally
#Change "E:/Github/diurnal-divergence-factor/" to your own file location on line 36 and 97



#Download and call the Aridity Index file (it was too large to include in the github directory). 
#Information here:
#Global Aridity Index and Potential Evapotranspiration (ET0) Database: Version 3 
#Zomer, R.J.; Xu, J.; Trabuco, A. 2022. Version 3 of the Global Aridity Index and Potential Evapotranspiration Database. Scientific Data 9, 409. https://www.nature.com/articles/s41597-022-01493-1
#https://figshare.com/articles/dataset/Global_Aridity_Index_and_Potential_Evapotranspiration_ET0_Climate_Database_v2/7504448/6
#https://doi.org/10.57760/sciencedb.nbsdc.00086
rast <- rast("//FILE_LOCATION_HERE/Global-AI_ET0__annual_v3_1/ai_v31_yr.tif")



#Relevant packages installation
packages <- c(
  "dplyr", "ggplot2", "ggspatial",
  "terra", "sf")

to_install <- packages[!packages %in% installed.packages()[, "Package"]]

if (length(to_install) > 0) {
  install.packages(to_install)
}

invisible(lapply(packages, library, character.only = TRUE))

library(dplyr)
library(ggplot2)
library(ggspatial) 
library(terra)
library(sf)

#Call masterfile here:
data <- read.csv("E:/Github/diurnal-divergence-factor/data/Masterfile.csv") %>%
  dplyr::mutate(Lat = Latitude,
                Long = Longitude) %>%
  dplyr::select(sitename, Veg, Lat, Long, AI_cat)%>%
  unique()

tibble::as_tibble(data)

# Define the extent for the US
us_extent <- ext(c(-125, -66.5, 24.4, 49.4))  # Rough bounds for the continental US

# Crop the raster to the US extent
rast_cropped <- crop(rast, us_extent)

rast_cropped_df <- as.data.frame(rast_cropped, xy=TRUE)

breaks <- c(0, 0.1, 0.2, 0.3, 0.4, 0.5, 0.6, 0.7, 0.8, 0.9, 1, 1.1, 1.2, 1.3, Inf)
colors <- c("#ffd1d1",  
            "#ffdfae",  
            "#fff3cb",  
            "#f7edd5", 
            "#ebf0e1",  
            "#deeaf6",  
            "#c1d7f0", 
            "#a6c8ea",  
            "#8cb9e4",  
            "#72aae1",  
            "#589cd7",  
            "#3f8ecc",  
            "#2683c1", 
            "#1069b6")  



rast_cropped_df$layer_scaled <- ifelse(rast_cropped_df$awi_pm_sr_yr ==0, NA, rast_cropped_df$awi_pm_sr_yr* 0.0001)
rast_cropped_df$layer_bins <- cut(rast_cropped_df$layer_scaled, breaks = breaks, include.lowest = TRUE, right = FALSE)

plot1 <- ggplot() +
  geom_raster(data = rast_cropped_df, aes(x = x, y = y, fill = factor(layer_bins))) +
  scale_fill_manual(values = colors, na.value = "NA") +
  geom_point(
    data = data,
    aes(x = Long, y = Lat, shape = AI_cat),
    fill = ifelse(data$Veg == "DBF", "#753bbd", 
                  ifelse(data$Veg == "ENF", "#2F80ED", 
                         ifelse(data$Veg == "GRA", "#2dc84d", 
                                ifelse(data$Veg == "SHR", "#ff7f41", "#e03c31")))),
    color = "black",
    size = 3,
    stroke = 0.6
  )+
  scale_shape_manual(values = c("Arid"=21, "Humid"=24)) +
  labs(title = "Flux Tower Locations", x = "Longitude", y = "Latitude",) +
  annotation_scale()+
  coord_sf(crs="+proj=longlat +datum=WGS84 +no_defs", xlim = c(-125, -66.5), ylim = c(24.4, 49.4)) +
  theme_void()+
  theme(
    panel.background = element_rect(fill = NA, colour = NA)) 

plot1

ggsave("E:/Github/diurnal-divergence-factor/figures/Figure_2.png", plot = plot1, width = 10, height = 8, units = "in", bg = "transparent", dpi = 1000)