#grabbing SWC metadata

library(dplyr)
library(readr)
library(stringr)

library(dplyr)
library(readr)
library(stringr)

# -----------------------------
# Paths
# -----------------------------

ameriflux_metadata_file <- r"(\\ewa-fluxfp1\fluxtower\Ameriflux_Data\Update_08_2025\Step3_Ameriflux_Data\metadata\Ameriflux_clean_mapping_summary.csv)"

fluxnet_metadata_file <- r"(\\ewa-fluxfp1\fluxtower\Ameriflux_Data\Update_08_2025\Step4_Fluxnet_Data\Metadata\fluxnet_clean_mapping_summary.csv)"

masterfile_file <- r"(C:\Users\keyke\Documents\GitHub\diurnal-divergence-factor\data\Masterfile.csv)"

output_file <- r"(C:\Users\keyke\Documents\GitHub\diurnal-divergence-factor\data\combined_selected_variable_metadata.csv)"


# -----------------------------
# Helpers
# -----------------------------

lower_names <- function(df) {
  names(df) <- names(df) %>%
    str_trim() %>%
    str_to_lower()
  df
}

add_missing_cols <- function(df, cols) {
  for (cc in cols) {
    if (!cc %in% names(df)) {
      df[[cc]] <- NA_character_
    }
  }
  df
}


# -----------------------------
# Read metadata
# -----------------------------

ameriflux_metadata <- read_csv(ameriflux_metadata_file, show_col_types = FALSE) %>%
  lower_names() %>%
  mutate(metadata_source = "Ameriflux")

fluxnet_metadata <- read_csv(fluxnet_metadata_file, show_col_types = FALSE) %>%
  lower_names() %>%
  mutate(metadata_source = "Fluxnet")


# -----------------------------
# Stack metadata
# -----------------------------

combined_metadata <- bind_rows(
  ameriflux_metadata,
  fluxnet_metadata
) %>%
  add_missing_cols(c("sitename", "swc", "swc_f", "swc_qc")) %>%
  mutate(
    swc_original = coalesce(swc, swc_f)
  )


# -----------------------------
# Read masterfile sites
# -----------------------------

master_sites <- read_csv(masterfile_file, show_col_types = FALSE) %>%
  lower_names() %>%
  distinct(sitename)


# -----------------------------
# Keep metadata only for sites in Masterfile
# -----------------------------

combined_metadata_subset <- combined_metadata %>%
  semi_join(master_sites, by = "sitename") %>%
  arrange(sitename, metadata_source) %>%
  select(
    sitename,
    metadata_source,
    swc_original,
    swc,
    swc_f,
    swc_qc,
    everything()
  )


# -----------------------------
# Save
# -----------------------------

write_csv(combined_metadata_subset, output_file)

cat("Saved combined metadata with original SWC names to:\n", output_file, "\n")



######################
library(dplyr)
library(readr)
library(stringr)
library(tidyr)
library(purrr)

# ============================================================
# BADM SWC HEIGHT JOIN ONLY
# ============================================================

# -----------------------------
# Paths
# -----------------------------

combined_metadata_file <- r"(C:\Users\keyke\Documents\GitHub\diurnal-divergence-factor\temporary\combined_selected_variable_metadata.csv)"

badm_file <- r"(C:\Users\keyke\Documents\GitHub\diurnal-divergence-factor\temporary\BASE_MeasurementHeight_20260527.csv)"

output_file <- r"(C:\Users\keyke\Documents\GitHub\diurnal-divergence-factor\temporary\combined_selected_variable_metadata.csv)"

backup_file <- r"(C:\Users\keyke\Documents\GitHub\diurnal-divergence-factor\temporary\combined_selected_variable_metadata_before_BADM_join.csv)"

missing_options_file <- r"(C:\Users\keyke\Documents\GitHub\diurnal-divergence-factor\temporary\BADM_SWC_options_for_missing_matches.csv)"


# -----------------------------
# Check files exist
# -----------------------------

if (!file.exists(combined_metadata_file)) {
  stop("combined_metadata_file does not exist:\n", combined_metadata_file)
}

if (!file.exists(badm_file)) {
  stop("badm_file does not exist:\n", badm_file)
}


# -----------------------------
# Helpers
# -----------------------------

lower_names <- function(df) {
  names(df) <- names(df) %>%
    str_trim() %>%
    str_to_lower()
  df
}

add_missing_cols <- function(df, cols) {
  for (cc in cols) {
    if (!cc %in% names(df)) {
      df[[cc]] <- NA_character_
    }
  }
  df
}

make_swc_candidates <- function(x) {
  
  if (is.na(x) || x == "") {
    return(character(0))
  }
  
  x <- str_trim(str_to_upper(x))
  
  # Remove processing tags but preserve the sensor/layer indices
  stripped <- x %>%
    str_replace("^SWC_PI_F_", "SWC_") %>%
    str_replace("^SWC_PI_", "SWC_") %>%
    str_replace("^SWC_F_MDS_", "SWC_") %>%
    str_replace("^SWC_F_", "SWC_")
  
  # Collapse things like SWC_1_1_1 to SWC_1 as a fallback
  collapsed_to_layer <- stripped %>%
    str_replace("^(SWC_\\d+)_.*$", "\\1")
  
  candidates <- c(
    x,
    
    # For SWC_PI_F_1_1_1, try SWC_PI_1_1_1 before removing PI
    str_replace(x, "^SWC_PI_F_", "SWC_PI_"),
    
    # Remove processing tags
    stripped,
    
    # Collapse to first-layer style
    collapsed_to_layer,
    
    # Last fallback
    "SWC"
  )
  
  candidates <- unique(candidates)
  candidates <- candidates[!is.na(candidates) & candidates != ""]
  
  return(candidates)
}


# -----------------------------
# Read combined selected-variable metadata
# -----------------------------

combined_metadata <- read_csv(combined_metadata_file, show_col_types = FALSE) %>%
  lower_names() %>%
  
  # Remove old BADM join columns if you are rerunning this script
  select(
    -any_of(c(
      "badm_swc_variable",
      "swc_candidate_used",
      "swc_badm_match_type",
      "swc_height",
      "swc_instrument_model",
      "swc_instrument_model2",
      "swc_start_date",
      "swc_comment"
    ))
  ) %>%
  add_missing_cols(c("sitename", "metadata_source", "swc_original", "swc", "swc_f"))

# Save backup before modifying
write_csv(combined_metadata, backup_file)

combined_metadata <- combined_metadata %>%
  mutate(
    swc_original = coalesce(
      as.character(swc_original),
      as.character(swc),
      as.character(swc_f)
    ),
    sitename_join = str_trim(str_to_upper(sitename)),
    row_id = row_number()
  )


# -----------------------------
# Read BADM measurement-height metadata
# -----------------------------

badm <- read_csv(badm_file, show_col_types = FALSE) %>%
  lower_names() %>%
  add_missing_cols(c(
    "site_id",
    "variable",
    "start_date",
    "height",
    "instrument_model",
    "instrument_model2",
    "comment",
    "base_version"
  )) %>%
  mutate(
    site_id_join = str_trim(str_to_upper(site_id)),
    variable_join = str_trim(str_to_upper(variable))
  )


# -----------------------------
# Keep BADM SWC rows only for sites in combined metadata
# -----------------------------

selected_sites <- combined_metadata %>%
  distinct(sitename_join)

badm_swc <- badm %>%
  semi_join(
    selected_sites,
    by = c("site_id_join" = "sitename_join")
  ) %>%
  filter(str_detect(variable_join, "^SWC"))


# -----------------------------
# Collapse BADM rows to avoid duplicate joins
# -----------------------------
# If BADM has multiple rows for the same site + variable,
# this keeps all unique values separated by "; ".

badm_swc_collapsed <- badm_swc %>%
  group_by(site_id_join, variable_join) %>%
  summarise(
    badm_swc_variable = paste(unique(na.omit(variable)), collapse = "; "),
    swc_height = paste(unique(na.omit(as.character(height))), collapse = "; "),
    swc_instrument_model = paste(unique(na.omit(instrument_model)), collapse = "; "),
    swc_instrument_model2 = paste(unique(na.omit(instrument_model2)), collapse = "; "),
    swc_start_date = paste(unique(na.omit(as.character(start_date))), collapse = "; "),
    swc_comment = paste(unique(na.omit(comment)), collapse = "; "),
    .groups = "drop"
  ) %>%
  mutate(
    across(
      c(
        badm_swc_variable,
        swc_height,
        swc_instrument_model,
        swc_instrument_model2,
        swc_start_date,
        swc_comment
      ),
      ~ na_if(.x, "")
    )
  )


# -----------------------------
# Build candidate SWC variable names for each selected SWC
# -----------------------------
# Example:
# SWC_F_MDS_1        -> SWC_F_MDS_1, SWC_1, SWC
# SWC_PI_1           -> SWC_PI_1, SWC_1, SWC
# SWC_1_1_1          -> SWC_1_1_1, SWC_1, SWC
# SWC_PI_F_1_1_1     -> SWC_PI_F_1_1_1, SWC_PI_1_1_1, SWC_1_1_1, SWC_1, SWC

swc_candidates <- combined_metadata %>%
  select(row_id, sitename_join, swc_original) %>%
  mutate(candidate_variable = map(swc_original, make_swc_candidates)) %>%
  unnest(candidate_variable) %>%
  group_by(row_id) %>%
  mutate(match_rank = row_number()) %>%
  ungroup()


# -----------------------------
# Join candidates to BADM and choose best-ranked match
# -----------------------------

badm_matches <- swc_candidates %>%
  left_join(
    badm_swc_collapsed,
    by = c(
      "sitename_join" = "site_id_join",
      "candidate_variable" = "variable_join"
    )
  ) %>%
  filter(!is.na(badm_swc_variable)) %>%
  group_by(row_id) %>%
  arrange(match_rank, .by_group = TRUE) %>%
  slice(1) %>%
  ungroup() %>%
  mutate(
    swc_badm_match_type = case_when(
      match_rank == 1 ~ "exact",
      match_rank == 2 ~ "candidate_rank_2",
      match_rank == 3 ~ "candidate_rank_3",
      match_rank == 4 ~ "candidate_rank_4",
      match_rank == 5 ~ "candidate_rank_5",
      TRUE ~ paste0("candidate_rank_", match_rank)
    ),
    swc_candidate_used = candidate_variable
  ) %>%
  select(
    row_id,
    badm_swc_variable,
    swc_candidate_used,
    swc_badm_match_type,
    swc_height,
    swc_instrument_model,
    swc_instrument_model2,
    swc_start_date,
    swc_comment
  )


# -----------------------------
# Join BADM match back to combined metadata
# -----------------------------

combined_with_badm <- combined_metadata %>%
  left_join(badm_matches, by = "row_id") %>%
  select(
    sitename,
    metadata_source,
    swc_original,
    badm_swc_variable,
    swc_candidate_used,
    swc_badm_match_type,
    swc_height,
    swc_instrument_model,
    swc_instrument_model2,
    swc_start_date,
    swc_comment,
    everything(),
    -any_of(c(
      "row_id",
      "sitename_join"
    ))
  )


# -----------------------------
# Save updated metadata
# -----------------------------

write_csv(combined_with_badm, output_file)

cat("Saved updated metadata with BADM SWC matches to:\n", output_file, "\n")
cat("Backup saved to:\n", backup_file, "\n")


# -----------------------------
# QA checks
# -----------------------------

cat("\nBADM SWC match summary:\n")
print(
  combined_with_badm %>%
    count(swc_badm_match_type, sort = TRUE)
)

cat("\nRows still missing BADM SWC height:\n")
still_missing <- combined_with_badm %>%
  filter(is.na(swc_height)) %>%
  select(
    sitename,
    metadata_source,
    swc_original,
    badm_swc_variable,
    swc_candidate_used,
    swc_height
  )

print(still_missing, n = Inf)


# -----------------------------
# Optional: save BADM SWC options for missing sites
# -----------------------------

missing_sites <- still_missing %>%
  distinct(sitename) %>%
  mutate(sitename_join = str_trim(str_to_upper(sitename)))

badm_options_for_missing <- badm_swc %>%
  semi_join(
    missing_sites,
    by = c("site_id_join" = "sitename_join")
  ) %>%
  arrange(site_id, variable) %>%
  select(
    site_id,
    variable,
    height,
    instrument_model,
    instrument_model2,
    start_date,
    comment
  )

write_csv(badm_options_for_missing, missing_options_file)

cat("\nSaved BADM SWC options for missing sites to:\n", missing_options_file, "\n")