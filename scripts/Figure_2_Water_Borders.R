# Figure 2: U.S. aridity and flux towers, with white lakes and faint state lines.
# Aridity: Zomer et al. (2022), https://doi.org/10.1038/s41597-022-01493-1
# Lake and boundary files: Natural Earth, already saved in data/map_boundaries.

# Run once if needed:
# install.packages(c("dplyr", "ggplot2", "ggspatial", "terra", "sf"))
library(dplyr)
library(ggplot2)
library(ggspatial)
library(terra)
library(sf)

# 1. File locations -----------------------------------------------------------
project_dir <- "C:/Users/keyke/Documents/GitHub/diurnal-divergence-factor"
raster_file <- "//ewa-fluxfp1/fluxtower/Ameriflux_Data/Update_08_2025/Step2_Metadata/Step1b_AridityIndex/Step2_extract/Global-AI_ET0__annual_v3_1/ai_v31_yr.tif"
output_dir <- file.path(project_dir, "figures")
boundary_dir <- file.path(project_dir, "data", "map_boundaries")
dir.create(output_dir, showWarnings = FALSE)

# 2. Tower locations and map boundaries --------------------------------------
data <- read.csv(file.path(project_dir, "data", "DDF_Data.csv")) %>%
  dplyr::mutate(Lat = Latitude, Long = Longitude) %>%
  dplyr::select(sitename, Veg, Lat, Long, AI_cat) %>%
  unique()

us <- readRDS(file.path(boundary_dir, "ne_50m_admin_0_countries.rds")) %>%
  dplyr::filter(admin == "United States of America")
lakes <- readRDS(file.path(boundary_dir, "ne_50m_lakes.rds"))
states <- readRDS(file.path(boundary_dir, "ne_50m_admin_1_states_provinces_lines.rds")) %>%
  dplyr::filter(adm0_a3 == "USA")

# 3. Crop to the U.S. and clear lakes -----------------------------------------
aridity <- terra::rast(raster_file)
us_extent <- terra::ext(-125, -66.5, 24.4, 49.4)
rast_cropped <- terra::crop(aridity, us_extent)
rast_cropped <- terra::ifel(rast_cropped == 0, NA, rast_cropped)
rast_us <- terra::mask(rast_cropped, terra::vect(us), touches = FALSE)
rast_land <- terra::mask(rast_us, terra::vect(lakes), inverse = TRUE)

# Keep missing cells so geom_raster has a regular grid.
rast_cropped_df <- as.data.frame(rast_land, xy = TRUE, na.rm = FALSE)
names(rast_cropped_df)[3] <- "aridity_raw"
rast_cropped_df$layer_scaled <- rast_cropped_df$aridity_raw * 0.0001
breaks <- c(0, 0.1, 0.2, 0.3, 0.4, 0.5, 0.6, 0.7, 0.8, 0.9, 1, 1.1, 1.2, 1.3, Inf)
colors <- c("#ffd1d1", "#ffdfae", "#fff3cb", "#f7edd5", "#ebf0e1", "#deeaf6",
            "#c1d7f0", "#a6c8ea", "#8cb9e4", "#72aae1", "#589cd7", "#3f8ecc",
            "#2683c1", "#1069b6")
rast_cropped_df$layer_bins <- cut(rast_cropped_df$layer_scaled, breaks = breaks,
                                  include.lowest = TRUE, right = FALSE)

# 4. Make the map -------------------------------------------------------------
plot1 <- ggplot() +
  geom_raster(data = rast_cropped_df, aes(x = x, y = y, fill = layer_bins)) +
  scale_fill_manual(values = setNames(colors, levels(rast_cropped_df$layer_bins)),
                    breaks = levels(rast_cropped_df$layer_bins),
                    na.value = "transparent", name = "Aridity index", drop = FALSE) +
  geom_sf(data = states, color = "black", alpha = 0.45, linewidth = 0.12) +
  geom_point(
    data = data,
    aes(x = Long, y = Lat, shape = AI_cat),
    fill = ifelse(data$Veg == "DBF", "#753bbd",
             ifelse(data$Veg == "ENF", "#2F80ED",
               ifelse(data$Veg == "GRA", "#2dc84d",
                 ifelse(data$Veg == "SHR", "#ff7f41", "#e03c31")))),
    color = "black", size = 5, stroke = 0.6
  ) +
  scale_shape_manual(values = c("Arid" = 21, "Humid" = 24), name = "Site climate") +
  labs(title = "Flux Tower Locations", x = "Longitude", y = "Latitude") +
  annotation_scale() +
  coord_sf(crs = 4326, xlim = c(-125, -66.5), ylim = c(24.4, 49.4), expand = FALSE) +
  theme_void() +
  theme(panel.background = element_rect(fill = "transparent", color = NA),
        plot.background = element_rect(fill = "transparent", color = NA))

print(plot1)

# 5. Save --------------------------------------------------------------------
ggsave(file.path(output_dir, "Figure_2_Water_Borders.png"), plot = plot1,
       width = 10, height = 8, units = "in", bg = "transparent", dpi = 1000)
