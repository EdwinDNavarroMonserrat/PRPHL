#!/bin/bash

# === USAGE CHECK ===
if [ "$#" -ne 2 ]; then
    echo "Usage: $0 <unicycler_output_dir> <checkm_output_dir>"
    exit 1
fi

INPUT_DIR="$1"
CHECKM_OUT_DIR="$2"
THREADS=4

mkdir -p "$CHECKM_OUT_DIR"/genomes

# === COPY ASSEMBLIES TO FLAT DIR FOR CHECKM ===
echo "Collecting assemblies..."
for asm in "$INPUT_DIR"/*/assembly.fasta; do
    SAMPLE=$(basename "$(dirname "$asm")")
    cp "$asm" "$CHECKM_OUT_DIR/genomes/${SAMPLE}.fasta"
done

# === RUN CHECKM ===
echo "Running CheckM lineage workflow..."
checkm lineage_wf \
    "$CHECKM_OUT_DIR/genomes" \
    "$CHECKM_OUT_DIR/checkm_lineage" \
    -x fasta \
    -t "$THREADS"

echo "CheckM complete. Results in: $CHECKM_OUT_DIR/checkm_lineage"
