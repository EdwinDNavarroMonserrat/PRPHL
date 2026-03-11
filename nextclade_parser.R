# =====================================
# Script for automated influenza reporting
# Written by Edwin Daniel Navarro Monserrat
# Automated influenza Nextclade cleanup script
# Reads all .tsv files from H1 and H3 folders,
# extracts Sample ID and Segment from seqName,
# keeps selected columns, and writes one CSV.
# =====================================

# Software
library(tidyverse)

# ---- folders ----
h1_dir <- "~/nextclade_H1_results"
h3_dir <- "~/nextclade_H3_results"
out_dir <- "~/Analisis_bioinformaticos/Influenza_reports"

dir.create(out_dir, showWarnings = FALSE)

# ---- function to read all nextclade files from one folder ----
read_nextclade_folder <- function(folder, subtype_label = NA_character_) {
  files <- list.files(folder, pattern = "\\.tsv$", full.names = TRUE)
  
  if (length(files) == 0) {
    message("No TSV files found in: ", folder)
    return(tibble())
  }
  
  map_dfr(files, function(f) {
    read_tsv(f, show_col_types = FALSE) |>
      mutate(
        subtype = subtype_label,
        source_file = basename(f)
      )
  })
}

# ---- read H1 and H3 results ----
h1_df <- read_nextclade_folder(h1_dir, "H1")
h3_df <- read_nextclade_folder(h3_dir, "H3")

all_df <- bind_rows(h1_df, h3_df)

# ---- stop if no data found ----
if (nrow(all_df) == 0) {
  stop("No Nextclade TSV files were found in H1 or H3 folders.")
}

# ---- make Sample ID and Segment from seqName ----
# assumes seqName looks like SAMPLEID_SEGMENT
# if there are extra underscores, everything after the first underscore
# is merged into Segment
all_df <- all_df |>
  separate(
    col = seqName,
    into = c("Sample ID", "Segment"),
    sep = "_",
    extra = "merge",
    fill = "right",
    remove = FALSE
  )

# ---- selected columns ----
wanted_cols <- c(
  "Sample ID",
  "Segment",
  "clade",
  "proposedSubclade",
  "short-clade",
  "subclade",
  "legacy-clade",
  "qc.overallStatus"
)

present_cols <- wanted_cols[wanted_cols %in% names(all_df)]

missing_cols <- setdiff(wanted_cols, names(all_df))
if (length(missing_cols) > 0) {
  message("These columns were not found and will be skipped: ",
          paste(missing_cols, collapse = ", "))
}

final_df <- all_df |>
  select(all_of(present_cols)) |>
  arrange(`Sample ID`, Segment)

# ---- write csv ----
write_csv(final_df, file.path(out_dir, "influenza_typing_summary.csv"))

message("Done. File written to: ", file.path(out_dir, "influenza_typing_summary.csv"))