# Dataset metadata and variable dictionary

**Manuscript:** Earlier peak daily evapotranspiration under water stress: evidence across 40 eddy covariance sites
**Repository:** https://github.com/kesondrakey/diurnal-divergence-factor  
**Archive record supplied for this project:** https://zenodo.org/records/22313015

These processed datasets contain the columns used by `Figures.Rmd`, `Statistics.Rmd`, and `Figure_2_REQUIRES_EXTERNAL_FILE.R`, with ET and VPD additionally retained in DDF_Data. Column subsetting preserves every source record and retained value. The original data processing steps are described in the manuscript Methods.

**Draft:** Confirm the DDF_Data ET conversion/unit and the time conventions below before publication. Confirm that the final archived release contains these versions of the files and metadata.

## `data/DDF_Data.csv`

49,644 unique site-date records from 40 sites, covering May–October observations between 2001-05-01 and 2024-10-31. There are 19 columns.
| Variable | Description | Units or format |
|---|---|---|
| `sitename` | Flux tower site identifier | Unitless |
| `Date` | Date of daily analysis record | YYYY-MM-DD |
| `Year` | Calendar year of Date | YYYY |
| `Latitude` | Site latitude | Decimal degrees north |
| `Longitude` | Site longitude; western longitudes are negative | Decimal degrees east |
| `Veg` | Study vegetation group: DBF = deciduous broadleaf forest; ENF = evergreen needleleaf forest; GRA = grassland; SHR = shrubland | Unitless category |
| `mean_AI` | Site mean aridity index; see manuscript Section 2.3.1 | Dimensionless |
| `AI_cat` | Site aridity category: Arid or Humid | Unitless |
| `Terrain` | Site terrain class; values listed below | Unitless |
| `data_source` | Source product: Ameriflux = AmeriFlux BASE; Fluxnet = AmeriFlux FLUXNET | Unitless |
| `ET` | Evapotranspiration flux summary used in the daily analysis | kg H₂O m⁻² s⁻¹, provisional: confirm conversion |
| `VPD` | Vapor pressure deficit, standardized for analysis | kPa |
| `DDF` | Diurnal divergence factor: ET peak hour minus VPD peak hour | h |
| `Drought` | Drought classification: ND = non-drought; Drought = drought | Unitless |
| `drought_cat` | Drought severity: ND = non-drought; LS = less severe; MS = more severe | Unitless |
| `Cluster` | Site-specific drought-cluster identifier | Integer identifier; Unitless |
| `DroughtNo` | Alternative site-specific drought-event number | Integer identifier; Unitless |
| `ClusterStart` | Recorded drought-event start date | YYYY-MM-DD |
| `min_scaled_SWC` | Minimum scaled soil water content associated with the drought event; scaling follows manuscript Methods | unitless |

`Terrain` values are `FLAT`, `GENTLE SLOPE (<2 %)`, `MEDIUM SLOPE (>2 %, <5%)`, and `UNDULATED/VARIABLE`; `NA` means unavailable. Study vegetation groups may differ from original IGBP classes.

A negative DDF means ET peaks earlier than VPD; for example, 12:00 minus 15:30 gives −3.5 h. This subtraction order was verified against the peak-hour columns in the full source file.

The four event fields (`Cluster`, `DroughtNo`, `ClusterStart`, `min_scaled_SWC`) are `NA` on non-drought records. Combine event identifiers with `sitename`; identifiers are not globally unique. Both number fields identify the same event groups with different numbering in this export.

## `data/US-SRS.csv`

140,256 half-hourly records from US-SRS Santa Rita Savanna, covering 2011–2018, retained for Figure 1. There are 5 columns.

| Variable | Description | Units or format |
|---|---|---|
| `DateTime` | Observation date and time; source metadata associates the site with America/Phoenix (UTC−7) | YYYY-MM-DD HH:MM:SS; midnight may be date-only |
| `Hour` | Decimal hour of day, 0–23.5 in 0.5-hour steps | h |
| `LE_f` | Gap-filled latent heat flux | W m⁻² |
| `NETRAD` | Net radiation | W m⁻² |
| `VPD_f` | Gap-filled vapor pressure deficit retained at source scale | hPa |

## Conventions and source citations

Missing values are `NA` in both files.

Full site-specific source-data citations and DOIs are provided in manuscript Table 1 and References. Cite the products and versions used. Figure 2 additionally requires the externally obtained aridity raster identified in `Figure_2_REQUIRES_EXTERNAL_FILE.R`.
