#!/bin/bash


# === READ ARGUMENTS ===
REPORT_DIR="$1"
OUT_DIR="$2"

# === RUN MULTIQC ===
echo "Generating MultiQC report..."
multiqc "$REPORT_DIR" -o "${OUT_DIR}/multiqc_report"

echo "Done! Output saved in $OUT_DIR"
