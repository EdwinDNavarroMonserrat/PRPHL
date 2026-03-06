#!/bin/bash

# === USAGE CHECK ===
if [ "$#" -ne 2 ]; then
    echo "Usage: $0 <raw_reads_dir> <output_dir>"
    exit 1
fi

# === READ ARGUMENTS ===
RAW_DIR="$1"
OUT_DIR="$2"
TRIM_DIR="${OUT_DIR}/trimmed_reads"
REPORT_DIR="${OUT_DIR}/fastp_reports"
THREADS=4

# === CREATE OUTPUT FOLDERS ===
mkdir -p "$TRIM_DIR" "$REPORT_DIR"

# === PROCESS EACH SAMPLE ===
for R1 in ${RAW_DIR}/*_R1_001.fastq.gz; do
    SAMPLE=$(basename "$R1" _R1_001.fastq.gz)
    R2="${RAW_DIR}/${SAMPLE}_R2_001.fastq.gz"

    echo "Processing sample: $SAMPLE"

    fastp \
      -i "$R1" \
      -I "$R2" \
      -o "${TRIM_DIR}/${SAMPLE}_R1.trimmed.fastq.gz" \
      -O "${TRIM_DIR}/${SAMPLE}_R2.trimmed.fastq.gz" \
      --html "${REPORT_DIR}/${SAMPLE}_fastp.html" \
      --json "${REPORT_DIR}/${SAMPLE}_fastp.json" \
      --thread "$THREADS"
done

echo "Fastp ran succesfully"

