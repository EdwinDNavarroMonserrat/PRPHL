# =========================================================
# Author: Edwin Daniel Navarro Monserrat
# Description: PulseNet data parser
# Requires: tidyverse, ggthemes, gt, readxl
# Note: Make PN_metadata.csv with samples you want to analyze
# Note: Make Distribution data .csv if doing Distributions
# Note: See AMR section for AMR viz
# Note: This script can be sourced from Pulsenet_report.qmd 
# =========================================================

## Libraries
library(tidyverse)
library(ggthemes)
library(gt)
library(readxl)
library(lubridate)
library(randomcoloR)
library(viridis)
library(ggtree)
library(ape)
library(ggtreeExtra)
library(ggnewscale)

## ---------------------------------------------------------
## Read PulseNet files
## ---------------------------------------------------------

## Working directory (folder that contains PN files for samples you want to analyze)
setwd("~/Downloads/PN_analysis_request")

## Metadata (downloaded from PN and renamed to PN_metadata.csv)
PN_metadata <- read_csv("PN_metadata.csv")

## Genotyping data
PN_metadata_genotyping <- PN_metadata |>
  select(
    Key, Genus, Species, Serotype_wgs, AntigenForm_wgs,
    MLST_ST, Allele_Code, NCBI_ACCESSION
  )

## Epidemiologic metadata
PN_metadata_epi <- PN_metadata |>
  select(
    Key, SourceCity, SourceCounty, SourceSite,
    PatientSex, PatientAgeYears, PatientAgeMonths,
    CollectionDate, PHL_ReceivedDate
  )

## AMR genes (downloaded from PN and renamed to PN_AMR.csv)
PN_AMR <- read_csv("PN_AMR.csv")

## Plasmids (downloaded from PN and renamed to PN_plasmids.csv)
PN_plasmids <- read_csv("PN_plasmids.csv")

## ---------------------------------------------------------
## Build AMR summary table
## Assumption: AMR file has one row per isolate, one column
## per gene, and 1 means present
## ---------------------------------------------------------

PN_AMR_summary <- PN_AMR |>
  pivot_longer(
    cols = -sampleKey,
    names_to = "gene",
    values_to = "present"
  ) |>
  filter(!is.na(present), present == 1) |>
  group_by(sampleKey) |>
  summarise(
    gene_list = paste(gene, collapse = " | "),
    .groups = "drop"
  )

## ---------------------------------------------------------
## Build plasmid summary table
## Assumption: plasmid file has one row per isolate, one
## column per plasmid, where 1 = present and 2 = absent
## ---------------------------------------------------------

PN_plasmid_summary <- PN_plasmids |>
  pivot_longer(
    cols = -sampleKey,
    names_to = "plasmid",
    values_to = "present"
  ) |>
  filter(!is.na(present), present == 1) |>
  group_by(sampleKey) |>
  summarise(
    plasmid_list = paste(plasmid, collapse = " | "),
    .groups = "drop"
  )

## ---------------------------------------------------------
## Combine AMR + plasmid results for reporting
## ---------------------------------------------------------

PN_AMR_plasmid_report <- PN_metadata |>
  select(Key) |>
  left_join(PN_AMR_summary, by = c("Key" = "sampleKey")) |>
  left_join(PN_plasmid_summary, by = c("Key" = "sampleKey")) |>
  mutate(
    AMR_gene_list = replace_na(gene_list, "NA"),
    plasmid_list = replace_na(plasmid_list, "NA")
  ) |> 
  select(c(Key, AMR_gene_list, plasmid_list))



## ---------------------------------------------------------
## Distributions --- Added 05/07/2026
## ---------------------------------------------------------
### Specify input file - if its the same as PN_metadata just copy the path
Epi_curve_data <- PN_metadata

Epi_curve_data <- Epi_curve_data |> 
  mutate(CollectionDate = as.Date(CollectionDate),
         Genus_species = paste(Genus, Species)) |>
  filter(!is.na(CollectionDate))
  


### Distribution (genus + species)
ggplot(Epi_curve_data, aes(x = CollectionDate, fill = Genus_species)) +
  geom_histogram(binwidth = 7, color = "black") +
  labs(
    title = "Distribution by Genus+Species 2026",
    x = 'Collection date',
    y = "No. of isolates",
    fill = "Genus species") +
  theme_clean()

### Distribution (genus + species) 30 day interval
ggplot(Epi_curve_data, aes(x = CollectionDate, fill = Genus_species)) +
  geom_histogram(binwidth = 30, color = "black") +
  labs(
    title = "Distribution by Genus+Species 2026",
    x = 'Collection date',
    y = "No. of isolates",
    fill = "Genus species") +
  theme_clean()


### Distribution (serotype) (distributed across intervals of 7 days)
n_serotypes <- length(unique(Epi_curve_data$Serotype_wgs))

ggplot(Epi_curve_data,
       aes(x = CollectionDate,
           fill = Serotype_wgs)) +
  geom_histogram(
    binwidth = 7,
    color = "black"
  ) +
  scale_fill_manual(
    values = distinctColorPalette(n_serotypes)
  ) +
  labs(
    title = "Distribution by S. enterica Serotype",
    x = "Collection date",
    y = "No. of isolates",
    fill = "Serotype"
  ) +
  theme_clean() +
  theme(
    legend.position = "right",
    legend.text = element_text(size = 8),
    legend.title = element_text(face = "bold")
  )

### Distribution (serotype) (distributed across intervals of 30 days)
n_serotypes <- length(unique(Epi_curve_data$Serotype_wgs))

ggplot(Epi_curve_data,
       aes(x = CollectionDate,
           fill = Serotype_wgs)) +
  geom_histogram(
    binwidth = 30,
    color = "black"
  ) +
  scale_fill_manual(
    values = distinctColorPalette(n_serotypes)
  ) +
  labs(
    title = "Distribution by S. enterica Serotype",
    x = "Collection date",
    y = "No. of isolates",
    fill = "Serotype"
  ) +
  theme_clean() +
  theme(
    legend.position = "right",
    legend.text = element_text(size = 8),
    legend.title = element_text(face = "bold")
  )



## Distribution (MLST-ST)
n_mlst <- length(unique(Epi_curve_data$MLST_ST))

ggplot(Epi_curve_data,
       aes(x = CollectionDate,
           fill = MLST_ST)) +
  geom_histogram(
    binwidth = 7,
    color = "black"
  ) +
  scale_fill_manual(
    values = distinctColorPalette(n_mlst)
  ) +
  labs(
    title = "Distribution by MLST-ST",
    x = "Collection date",
    y = "No. of isolates",
    fill = "MLST-ST"
  ) +
  theme_clean()

## Distribution (MLST-ST) (30 day intervals)
n_mlst <- length(unique(Epi_curve_data$MLST_ST))

ggplot(Epi_curve_data,
       aes(x = CollectionDate,
           fill = MLST_ST)) +
  geom_histogram(
    binwidth = 30,
    color = "black"
  ) +
  scale_fill_manual(
    values = distinctColorPalette(n_mlst)
  ) +
  labs(
    title = "Distribution by MLST-ST",
    x = "Collection date",
    y = "No. of isolates",
    fill = "MLST-ST"
  ) +
  theme_clean()


## Distribution but with subset dataset (example enteriditis serotype)
Subset_Epi <- Epi_curve_data |> 
  filter(grepl("Enteritidis", Serotype_wgs))

ggplot(Subset_Epi, 
       aes(x = CollectionDate,
           fill = MLST_ST)) +
  geom_histogram(color = "black", binwidth = 30) +
  scale_fill_manual(
    values = "firebrick"
  ) +
  labs(
    title = "Distribution of Enteritidis by MLST-ST",
    x = "Collection date",
    y = "No. of isolates",
    fill = "MLST-ST"
  ) +
  theme_clean()


## ---------------------------------------------------------
## Distance Matrix --- Added 05/07/2026
## ---------------------------------------------------------

DistanceMatrix <- read_csv("DistanceMatrix.csv")

DM_mat <- DistanceMatrix |>
  column_to_rownames(var = colnames(DistanceMatrix)[1]) |>
  as.matrix()

DM_mat <- apply(DM_mat, 2, as.numeric)
rownames(DM_mat) <- DistanceMatrix[[1]]

hc <- hclust(as.dist(DM_mat), method = "average")

sample_order <- hc$labels[hc$order]

distance_long <- DistanceMatrix |>
  rename(sample_1 = 1) |>
  pivot_longer(
    cols = -sample_1,
    names_to = "sample_2",
    values_to = "distance"
  ) |>
  mutate(
    distance = as.numeric(distance),
    sample_1 = factor(sample_1, levels = rev(sample_order)),
    sample_2 = factor(sample_2, levels = sample_order)
  )


DM <- ggplot(
  distance_long,
  aes(
    x = sample_2,
    y = sample_1,
    fill = distance
  )
) +
  geom_tile(
    color = "black",
    linewidth = 0.2,
    alpha = 0.6   # fixed transparency for tiles
  ) +
  geom_text(
    aes(label = distance),
    size = 3
  ) +
  scale_fill_viridis_c(
    option = "mako",
    direction = -1,
    name = "cgMLST\ndistance",
    guide = guide_colourbar(
      override.aes = list(alpha = 0.6)   # makes the legend match the plot
    )
  ) +
  labs(
    title = "cgMLST Distance Matrix",
    x = NULL,
    y = NULL
  ) +
  theme_minimal(base_size = 12) +
  theme(
    panel.grid = element_blank(),
    axis.text.x = element_text(
      angle = 90,
      hjust = 1,
      vjust = 0.5
    ),
    axis.text.y = element_text(size = 8)
  )



## ---------------------------------------------------------
## Dendrogram --- Added 06/11/2026
## Based on PN cgMLST
## Set target seqs (i.e. samples of interest)
## removes samples with >50 allele differences
## ---------------------------------------------------------

## Load tree
PN_tree <- read.tree("newickcgMLST.txt")

## Get tree metadata
tree_metadata <- PN_metadata |>
  select(
    Key,
    SourceType,
    SourceSite,
    Serotype_wgs,
    CollectionDate,
    SourceCity
  ) |>
  mutate(
    CollectionDate = as.Date(CollectionDate),
    annotation = paste(
      SourceType,
      SourceSite,
      Serotype_wgs,
      CollectionDate,
      SourceCity,
      sep = " | "
    )
  ) |>
  rename(label = Key)

## Target sample(s)
target_samples <- c("26-281", "26-282", "26-283", "26-284", "26-285", "26-286", "26-288", "26-289", "26-290")   # adjust as needed

## Allele-distance cutoff
allele_cutoff <- 50

## Read distance matrix
DistanceMatrix <- read_csv("DistanceMatrix.csv")

distance_long <- DistanceMatrix |>
  rename(sample_1 = 1) |>
  pivot_longer(
    cols = -sample_1,
    names_to = "sample_2",
    values_to = "distance"
  ) |>
  mutate(distance = as.numeric(distance))

## Samples within cutoff of target sample(s)
keep_tips <- distance_long |>
  filter(
    sample_1 %in% target_samples,
    distance <= allele_cutoff
  ) |>
  pull(sample_2) |>
  unique()

## Always keep target samples
keep_tips <- union(keep_tips, target_samples)

## Prune tree
PN_tree_subset <- keep.tip(
  PN_tree,
  intersect(PN_tree$tip.label, keep_tips)
)

## Subset metadata too
tree_metadata_subset <- tree_metadata |>
  filter(label %in% PN_tree_subset$tip.label)

## Plot
Final_tree <- ggtree(PN_tree_subset, layout = "rectangular") %<+% tree_metadata_subset +
  geom_tiplab(
    aes(label = annotation),
    as_ylab = T, 
    size = 10,
    face = "bold"
  ) +
  scale_x_continuous(
    expand = expansion(mult = c(0.02, 0.35))
  ) +
  geom_tiplab(size = 5) +
  labs(
    title = "cgMLST dendrogram",
    subtitle = paste0(
      "Samples within ",
      allele_cutoff,
      " alleles of target sample(s): ",
      paste(target_samples, collapse = ", ")
    )
  ) 

# Set path so that qmd (Quarto) template so that logo inclution in quarto report is done correctly
setwd("/home/edwin/Analisis_bioinformaticos/Scripts/R_scripts/Automated_reports")
