# =====================================
# Script for automated bacterial pathogens reporting
# Written by Edwin Daniel Navarro Monserrat
# Automated Phodeur parser script
# edit directories as needed
# results been pulled from grandeur should be 
# in directory within phodeur_dir called grandeur
# phoenix results should also be in phodeur directory
# =====================================

library(tidyverse)
library(fs)
library(jsonlite)
library(ape)
library(ggplot2)
library(grid)
library(ggtree)

# set this to your Phodeur results directory
phodeur_dir <- "~/Analisis_bioinformaticos/HAI-AR/trial2"

# file paths
phoenix_file <- fs::path(phodeur_dir, "phoenix", "Phoenix_Summary.tsv")
grandeur_file <- fs::path(phodeur_dir, "grandeur", "grandeur_summary.tsv")
amr_file <- fs::path(phodeur_dir, "grandeur", "amrfinder", "amrfinderplus_summary.txt")
plasmid_file <- fs::path(phodeur_dir, "grandeur", "plasmidfinder", "plasmidfinder_result.json")
snps_ska_file <- fs::path(phodeur_dir, "grandeur", "heatcluster", "heatcluster_snpdists_ska_alignment_sorted.csv") 
snps_panaroo_file <- fs::path(phodeur_dir, "grandeur", "heatcluster", "heatcluster_snpdists_core_gene_alignment_sorted.csv")
iqtree_file <- fs::path(phodeur_dir, "grandeur", "iqtree", "iqtree_core_gene_alignment.treefile.nwk")

# -------------------------
# Functions
# -------------------------
## Cleaning up ID names (we typically name our fastq with Key-PR-Instrument-DateSequenced, 
## this will just leave key, remove instances of this function in tables if ypu want to keep OG names)
clean_id <- function(x) {
  stringr::str_remove(x, "-PR.*$")
}

# -------------------------
# 1. sample typing table
# -------------------------

phoenix_tbl <- readr::read_tsv(phoenix_file, show_col_types = FALSE) |>
  select(ID, Species, Taxa_Confidence)

# NOTE: grandeur generates different results depending on the organisms analyzed
grandeur_tbl <- readr::read_tsv(grandeur_file, show_col_types = FALSE) |>
  select(any_of(c(
    "sample",
    "mlst_st",
    "seqsero2_predicted_serotype",
    "serotypefinder_Serotype_O",
    "serotypefinder_Serotype_H",
    "shigatyper_prediction",
    "shigapass_predicted_serotype"
  )))

sample_typing <- phoenix_tbl |>
  left_join(grandeur_tbl, by = c("ID" = "sample")) |> 
  mutate(ID = clean_id(ID))


## Clean up ID names (Keep just everything before "-PR")

# -------------------------
# 2. amr table
# -------------------------

amrfinder_tbl <- readr::read_tsv(amr_file, show_col_types = FALSE)

amr_table <- amrfinder_tbl |>
  filter(Type == "AMR") |>
  filter(is.na(Subclass) | Subclass != "EFFLUX") |>
  transmute(
    Sample = Name,
    gene = `Element symbol`,
    gene_name = `Element name`,
    subclass = Subclass
  ) |>
  distinct() |> 
  mutate(ID = clean_id(Sample)) |> 
  select(c(ID, gene, gene_name, subclass))

## make secondary table were genes are shown separate by "|" in a list style format

# -------------------------
# 3. virulence table
# -------------------------

virulence_table <- amrfinder_tbl |>
  filter(Type == "VIRULENCE") |>
  transmute(
    ID = Name,
    gene = `Element symbol`,
    gene_name = `Element name`
  ) |>
  mutate(ID = clean_id(ID)) |> 
  distinct()

# -------------------------
# 4. plasmid table
# -------------------------

plasmid_table <- if (fs::file_exists(plasmid_file)) {
  
  # Read concatenated JSON text
  txt <- readLines(plasmid_file, warn = FALSE, encoding = "UTF-8")
  txt <- paste(txt, collapse = "")
  
  # Split concatenated objects: }{
  txt <- gsub("\\}\\{", "\\}\n\\{", txt)
  json_chunks <- strsplit(txt, "\n")[[1]]
  
  # Parse each JSON object safely
  parsed <- purrr::map(json_chunks, \(x) {
    tryCatch(jsonlite::fromJSON(x, simplifyVector = TRUE), error = function(e) NULL)
  }) |>
    purrr::compact()
  
  # Extract sample ID and plasmid hits
  plasmid_table_raw <- purrr::map_dfr(parsed, function(obj) {
    
    # sample name from infile, outdir, or out_json
    sample_name <- NA_character_
    
    if (!is.null(obj$software_executions) && length(obj$software_executions) > 0) {
      exec <- obj$software_executions[[1]]
      
      if (!is.null(exec$parameters$infile) && length(exec$parameters$infile) > 0) {
        sample_name <- fs::path_ext_remove(basename(exec$parameters$infile[[1]]))
      } else if (!is.null(exec$parameters$outdir)) {
        sample_name <- basename(exec$parameters$outdir)
      } else if (!is.null(exec$parameters$out_json)) {
        sample_name <- stringr::str_remove(
          basename(exec$parameters$out_json),
          "^results_|_plasmidfinder\\.json$"
        )
      }
    }
    
    # No hits
    if (is.null(obj$aln_hits) || length(obj$aln_hits) == 0) {
      return(tibble(
        ID = clean_id(sample_name),
        plasmid = NA_character_
      ))
    }
    
    # Hits present
    hit_names <- names(obj$aln_hits)
    
    if (is.null(hit_names) || length(hit_names) == 0) {
      return(tibble(
        ID = clean_id(sample_name),
        plasmid = NA_character_
      ))
    }
    
    tibble(
      ID = clean_id(sample_name),
      plasmid = hit_names
    )
  })
  
  plasmid_table_raw |>
    filter(!is.na(ID), !is.na(plasmid), plasmid != "") |>
    distinct()
  
} else {
  message("PlasmidFinder JSON file not found — skipping plasmid table")
  tibble(
    ID = character(),
    plasmid = character()
  )
}

## make secondary table were genes are shown separate by "|" in a list style format

# -------------------------
# 5. sample-level gene/plasmid lists
# -------------------------

ARG_list <- amr_table|>
  group_by(ID)|>
  summarise(
    AR_gene_list = paste(sort(unique(gene)), collapse = " | "),
    .groups = "drop"
  )

AR_class <- amr_table |> 
  group_by(ID)|>
  summarise(
    AR_antibiotic = paste(sort(unique(subclass)), collapse = " | "),
    .groups = "drop"
  )

virulence_list <- virulence_table|>
  group_by(ID)|>
  summarise(
    virulence_gene_list = paste(sort(unique(gene)), collapse = " | "),
    .groups = "drop"
  )

plasmid_list <- plasmid_table|>
  group_by(ID)|>
  summarise(
    plasmid_list = paste(sort(unique(plasmid)), collapse = " | "),
    .groups = "drop"
  )


# Table with AR, ARG, Virulence genes and plasmid replicons
sample_gene_lists <- sample_typing |>
  transmute(ID = ID)|>
  full_join(ARG_list, by = "ID")|>
  full_join(AR_class, by = "ID") |> 
  full_join(virulence_list, by = "ID")|>
  full_join(plasmid_list, by = "ID")|>
  distinct()


# Table with just ARG
sample_ARGS <- sample_typing |>
  transmute(ID = ID)|>
  full_join(ARG_list, by = "ID")|>
  distinct()

# Table with just Plasmid replicons


# -------------------------
# 6. Distance Matrix of selected samples
# -------------------------

## Check if snp dist - ska alignments and/or panaroo distance matrices are available
if (fs::file_exists(snps_ska_file)) {
  snps_ska_tbl <- readr::read_csv(snps_ska_file, show_col_types = FALSE)
} else {
  message("SKA SNP file not found — skipping distance matrix")
}


if (fs::file_exists(snps_panaroo_file)) {
  snps_panaroo_tbl <- readr::read_csv(snps_panaroo_file, show_col_types = FALSE)
} else {
  message("Panaroo SNP file not found — skipping distance matrix")
}


# -------------------------
# 7. Newick tree generated by IQ-Tree
# -------------------------
tree <- ape::read.tree(iqtree_file)


# Set path so that qmd (Quarto markdown) template so that logo inclution in quarto report is done correctly
setwd("/home/edwin/Analisis_bioinformaticos/Scripts/R_scripts/Automated_reports")
