#!/bin/bash
# ==========================================
# Written by Edwin Navarro Monserrat 
# Wrapper for Nextflow pipeline execution
# Usage:
#   bash walkercreek.sh samplesheet.csv /path/to/output
# Change platform as needed
# ==========================================

echo "Script runs Walkercreek, a Nextflow pipeline from UPHL-BioNGS"

# ===== 1. Check Arguments =====
if [ "$#" -ne 2 ]; then
    echo "[ERROR] Incorrect number of arguments."
    echo "Usage: bash run_walkercreek.sh samplesheet.csv /path/to/output"
    exit 1
fi

SAMPLESHEET="$1"
OUTDIR="$2"

# ===== 2. Validate Inputs =====
if [ ! -f "$SAMPLESHEET" ]; then
    echo "[ERROR] Samplesheet not found: $SAMPLESHEET"
    exit 1
fi

mkdir -p "$OUTDIR"

echo "[INFO] Samplesheet: $SAMPLESHEET"
echo "[INFO] Output dir : $OUTDIR"


# ===== 3. Run Walkercreek =====
echo "[INFO] Launching Walkercreek pipeline..."

#    -c custom.config \ # add below to trim reads below 100bp

nextflow run UPHL-BioNGS/walkercreek \
    -profile docker \
    -c custom.config \
    --platform flu_illumina \
    --input "$SAMPLESHEET" \
    --outdir "$OUTDIR"

# ===== 5. Exit status =====
if [ $? -eq 0 ]; then
    echo "[INFO] Walkercreek finished successfully!"
    echo "[INFO] Results saved to: $OUTDIR"
else
    echo "[ERROR] Walkercreek failed. Check .nextflow.log"
    exit 1
fi