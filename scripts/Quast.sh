#!/bin/bash

# === USAGE CHECK ===
if [ "$#" -ne 2 ]; then
    echo "Usage: $0 <unicycler_output_dir> <quast_output_dir>"
    exit 1
fi

INPUT_DIR="$1"
QUAST_OUT_DIR="$2"
THREADS=4

mkdir -p "$QUAST_OUT_DIR"

# === LOOP THROUGH EACH ASSEMBLY ===
for ASSEMBLY in "$INPUT_DIR"/*/assembly.fasta; do
    SAMPLE=$(basename "$(dirname "$ASSEMBLY")")
    OUTDIR="${QUAST_OUT_DIR}/${SAMPLE}"

    echo "Running QUAST on $SAMPLE"

    quast "$ASSEMBLY" \
        -o "$OUTDIR" \
        -t "$THREADS" \
        --labels "$SAMPLE"
done

echo "All QUAST reports saved in: $QUAST_OUT_DIR"
