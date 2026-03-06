#!/bin/bash
# ==========================================
# PHoeNIx Runner (StaPH-B Toolkit)
# Written by Edwin Navarro Monserrat
# ==========================================

echo "Running PHoeNIx via StaPH-B Toolkit"

# ===== 1. Check Arguments =====
if [ "$#" -ne 3 ]; then
    echo "Usage:"
    echo "  $0 reads /path/to/samplesheet.csv /path/to/output"
    echo "  $0 scaffolds /path/to/fasta_dir /path/to/output"
    exit 1
fi

MODE=$1
INPUT=$(realpath "$2")
OUTDIR=$(realpath "$3")

# ===== 2. Kraken2 DB Path =====
KRAKEN_DB="$HOME/assets/CDCgov/phoenix/assets/databases/"
echo "[INFO] Using Kraken2 DB at: $KRAKEN_DB"

# ===== 3. Detect System Resources =====
TOTAL_CPUS=$(nproc)
USE_CPUS=$((TOTAL_CPUS - 2))
if [ "$USE_CPUS" -lt 2 ]; then USE_CPUS=2; fi

TOTAL_MEM_GB=$(free -g | awk '/^Mem:/{print $2}')
USE_MEM_GB=$((TOTAL_MEM_GB * 90 / 100))
if [ "$USE_MEM_GB" -lt 4 ]; then USE_MEM_GB=4; fi

echo "[INFO] CPUs: $TOTAL_CPUS → using $USE_CPUS"
echo "[INFO] RAM:  $TOTAL_MEM_GB GB → using $USE_MEM_GB GB"

# ===== 4. Export Nextflow Defaults =====
export NXF_DEFAULT_CPUS=$USE_CPUS
export NXF_DEFAULT_MEMORY=${USE_MEM_GB}.GB

# ===== 5. Build PHoeNIx Command =====
CMD="staphb-tk phoenix \
    -entry PHOENIX \
    --kraken2db \"$KRAKEN_DB\" \
    --outdir \"$OUTDIR\" \
    --max_cpus \"$USE_CPUS\" \
    --max_memory \"${USE_MEM_GB}.GB\""

if [ "$MODE" == "reads" ]; then
    echo "[INFO] Running PHoeNIx on FASTQ reads..."
    CMD+=" --input \"$INPUT\""

elif [ "$MODE" == "scaffolds" ]; then
    echo "[INFO] Running PHoeNIx on FASTA scaffolds..."
    CMD="staphb-tk phoenix \
        -entry SCAFFOLDS \
        --scaffold_ext \"$INPUT\" \
        --kraken2db \"$KRAKEN_DB\" \
        --outdir \"$OUTDIR\" \
        --max_cpus \"$USE_CPUS\" \
        --max_memory \"${USE_MEM_GB}.GB\""
else
    echo "[ERROR] Mode must be 'reads' or 'scaffolds'"
    exit 1
fi

# ===== 6. Run PHoeNIx =====
echo "[INFO] Launching PHoeNIx pipeline..."
eval $CMD

echo "PHoeNIx finished! Results saved to: $OUTDIR"
