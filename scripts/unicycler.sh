#!/bin/bash

# === USAGE CHECK ===
if [ "$#" -ne 2 ]; then
    echo "Usage: $0 <trimmed_reads_dir> <unicycler_output_dir>"
    exit 1
fi

# === READ ARGUMENTS ===
TRIM_DIR="$1"
OUT_DIR="$2"
THREADS=8

mkdir -p "$OUT_DIR"

# === RUN UNICYCLER PER SAMPLE ===
for R1 in ${TRIM_DIR}/*_R1.trimmed.fastq.gz; do
    SAMPLE=$(basename "$R1" _R1.trimmed.fastq.gz)
    R2="${TRIM_DIR}/${SAMPLE}_R2.trimmed.fastq.gz"
    SAMPLE_OUT="${OUT_DIR}/${SAMPLE}"

    echo "🛠️  Running Unicycler on sample: $SAMPLE"

    mkdir -p "$SAMPLE_OUT"

    unicycler \
      -1 "$R1" \
      -2 "$R2" \
      -o "$SAMPLE_OUT" \
      -t "$THREADS" \
      --mode normal
done

echo "All assemblies completed. Results in: $OUT_DIR"
