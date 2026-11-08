# Figure 2: contiguous U.S. aridity and flux towers, with clear lakes and state lines.
# This is a separate version of Figure_2_REQUIRES_EXTERNAL_FILE.R.
# Aridity source: Zomer, Xu & Trabuco (2022), https://doi.org/10.1038/s41597-022-01493-1
# Boundary/lake source: Natural Earth, 1:50 million (cached after the first run).
# https://www.naturalearthdata.com/downloads/50m-physical-vectors/50m-lakes-reservoirs/
# https://www.naturalearthdata.com/downloads/50m-cultural-vectors/50m-admin-0-countries-2/
# https://www.naturalearthdata.com/downloads/50m-cultural-vectors/50m-admin-1-states-provinces/

packages <- c("dplyr", "ggplot2", "ggspatial", "terra", "sf")
missing_packages <- packages[!vapply(packages, requireNamespace, logical(1), quietly = TRUE)]
if (length(missing_packages)) {
  stop("Install these packages first: ", paste(missing_packages, collapse = ", "))
}
invisible(lapply(packages, library, character.only = TRUE))

# --------------------------- Settings to edit -------------------------------
show_states <- TRUE            # FALSE removes the faint U.S. state lines.
map_background <- "white"      # Use "transparent" for transparent lakes/ocean.
state_line_width <- 0.12
raster_file <- Sys.getenv("AI_RASTER_PATH", paste0(
  "//ewa-fluxfp1/fluxtower/Ameriflux_Data/Update_08_2025/Step2_Metadata/",
  "Step1b_AridityIndex/Step2_extract/Global-AI_ET0__annual_v3_1/ai_v31_yr.tif"))

# Locate the repository when sourced from RStudio or run with Rscript.
find_project <- function() {
  script_args <- grep("^--file=", commandArgs(FALSE), value = TRUE)
  script_path <- if (length(script_args)) sub("^--file=", "", script_args[1]) else ""
  source_paths <- vapply(sys.frames(), function(frame) {
    if (is.null(frame$ofile)) "" else as.character(frame$ofile)[1]
  }, character(1))
  starts <- c(Sys.getenv("FIGURE2_REPO_ROOT"), getwd(),
    dirname(c(script_path, source_paths[nzchar(source_paths)])),
    "C:/Users/keyke/Documents/GitHub/diurnal-divergence-factor")
  for (start in starts[nzchar(starts)]) {
    if (!dir.exists(start)) next
    candidate <- normalizePath(start, winslash = "/")
    repeat {
      if (file.exists(file.path(candidate, "data", "Masterfile.csv"))) return(candidate)
      parent <- dirname(candidate)
      if (identical(parent, candidate)) break
      candidate <- parent
    }
  }
  stop("Cannot locate data/Masterfile.csv. Set FIGURE2_REPO_ROOT to the repository.")
}
project_dir <- find_project()
output_dir <- Sys.getenv("FIGURE2_OUTPUT_DIR", file.path(project_dir, "figures"))
cache_dir <- Sys.getenv("FIGURE2_CACHE_DIR", file.path(project_dir, "data", "map_boundaries"))
figure_dpi <- as.integer(Sys.getenv("FIGURE2_DPI", "1000"))
dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)
dir.create(cache_dir, recursive = TRUE, showWarnings = FALSE)
if (!file.exists(raster_file)) stop("Cannot access the aridity raster: ", raster_file)

# Natural Earth provides both the lake polygons and matching border geometry.
# RDS caches avoid downloads on later runs; no R packages are installed here.
read_boundary <- function(layer, category) {
  cache_file <- file.path(cache_dir, paste0(layer, ".rds"))
  if (file.exists(cache_file)) return(readRDS(cache_file))
  url <- paste0("https://naciscdn.org/naturalearth/50m/", category, "/", layer, ".zip")
  zip_file <- tempfile(fileext = ".zip")
  unpack_dir <- tempfile(pattern = "naturalearth_")
  dir.create(unpack_dir)
  download.file(url, zip_file, mode = "wb", quiet = TRUE)
  unzip(zip_file, exdir = unpack_dir)
  boundary <- sf::st_read(file.path(unpack_dir, paste0(layer, ".shp")), quiet = TRUE)
  names(boundary) <- tolower(names(boundary))
  saveRDS(boundary, cache_file)
  boundary
}
countries <- read_boundary("ne_50m_admin_0_countries", "cultural")
lakes <- read_boundary("ne_50m_lakes", "physical")
country_borders <- countries %>%
  filter(admin == "United States of America")
if (show_states) {
  state_borders <- read_boundary("ne_50m_admin_1_states_provinces_lines", "cultural") %>%
    filter(adm0_a3 == "USA")
}

# Keep the original map extent, site selection, aridity bins and color palette.
map_extent <- terra::ext(-125, -66.5, 24.4, 49.4)
site_data <- read.csv(file.path(project_dir, "data", "Masterfile.csv")) %>%
  mutate(Lat = Latitude, Long = Longitude) %>%
  select(sitename, Veg, Lat, Long, AI_cat) %>% distinct()
vegetation_colors <- c(DBF = "#753bbd", ENF = "#2F80ED", GRA = "#2dc84d", SHR = "#ff7f41")
site_data$point_fill <- unname(vegetation_colors[site_data$Veg])
site_data$point_fill[is.na(site_data$point_fill)] <- "#e03c31"

# Select lakes in the map area without altering their shoreline geometry.
lake_bounds <- lapply(sf::st_geometry(lakes), sf::st_bbox)
lake_in_map <- vapply(lake_bounds, function(b) {
  b["xmax"] >= -125 && b["xmin"] <= -66.5 && b["ymax"] >= 24.4 && b["ymin"] <= 49.4
}, logical(1))
lakes_in_map <- lakes[lake_in_map, ]

aridity <- terra::rast(raster_file)
aridity_cropped <- terra::crop(aridity, map_extent)
# Zero was already treated as missing in the original Figure 2 script.
aridity_cropped <- terra::ifel(aridity_cropped == 0, NA, aridity_cropped)
# Blank everything outside the U.S., then remove lake pixels within the U.S.
# Canada, Mexico, lakes and ocean all use the selected background color.
aridity_us <- terra::mask(aridity_cropped, terra::vect(country_borders), touches = FALSE)
aridity_land <- terra::mask(aridity_us, terra::vect(lakes_in_map), inverse = TRUE)
# Retain missing cells so geom_raster receives a regular grid after clipping.
aridity_df <- as.data.frame(aridity_land, xy = TRUE, na.rm = FALSE)
names(aridity_df)[3] <- "aridity_raw"
aridity_df$layer_scaled <- aridity_df$aridity_raw * 0.0001
breaks <- c(0, 0.1, 0.2, 0.3, 0.4, 0.5, 0.6, 0.7, 0.8, 0.9, 1, 1.1, 1.2, 1.3, Inf)
colors <- c("#ffd1d1", "#ffdfae", "#fff3cb", "#f7edd5", "#ebf0e1", "#deeaf6",
            "#c1d7f0", "#a6c8ea", "#8cb9e4", "#72aae1", "#589cd7", "#3f8ecc",
            "#2683c1", "#1069b6")
aridity_df$layer_bins <- cut(aridity_df$layer_scaled, breaks = breaks,
                            include.lowest = TRUE, right = FALSE)

plot1 <- ggplot() +
  geom_raster(data = aridity_df, aes(x = x, y = y, fill = layer_bins)) +
  scale_fill_manual(values = setNames(colors, levels(aridity_df$layer_bins)),
                    breaks = levels(aridity_df$layer_bins),
                    na.value = "transparent", name = "Aridity index", drop = FALSE)
if (show_states) {
  plot1 <- plot1 + geom_sf(data = state_borders, color = "black", alpha = 0.45,
                          linewidth = state_line_width, inherit.aes = FALSE)
}
plot1 <- plot1 +
  geom_point(data = site_data, aes(x = Long, y = Lat, shape = AI_cat),
               fill = site_data$point_fill, color = "black", size = 3, stroke = 0.6) +
  scale_shape_manual(values = c(Arid = 21, Humid = 24), name = "Site climate") +
  labs(title = "Flux Tower Locations", x = "Longitude", y = "Latitude") +
  ggspatial::annotation_scale() +
  coord_sf(crs = sf::st_crs(4326), xlim = c(-125, -66.5), ylim = c(24.4, 49.4),
             expand = FALSE) +
  theme_void() +
  theme(panel.background = element_rect(fill = map_background, color = NA),
        plot.background = element_rect(fill = map_background, color = NA))

print(plot1)
ggsave(file.path(output_dir, "Figure_2_Water_Borders.png"), plot1,
         width = 10, height = 8, units = "in", bg = map_background, dpi = figure_dpi)
ggsave(file.path(output_dir, "Figure_2_Water_Borders.pdf"), plot1,
         width = 10, height = 8, units = "in", bg = map_background, device = cairo_pdf)
