#!/bin/bash
# ==========================================
# Written by Edwin Navarro Monserrat
# Optimized Grandeur Run in HP Z8 Workstation
# Detects CPU cores & RAM automatically
# Script accepts raw reads, fastq.gz or assembled genomes, fasta
# For WGS analysis
# Usage:
#   bash run_grandeur_optimized.sh reads /path/to/reads /path/to/output
#   bash run_grandeur_optimized.sh fastas /path/to/fasta_dir /path/to/output
# ==========================================

set -eou pipefail

echo "Script runs Grandeur, a Nextflow pipeline developed by E.Young from UPHL"

# ===== 1. Check Arguments =====
if [ "$#" -ne 3 ]; then
    echo "Usage:"
    echo "  $0 reads /path/to/reads /path/to/output"
    echo "  $0 fastas /path/to/fasta_dir /path/to/output"
    exit 1
fi

INPUT_TYPE=$1
INPUT_PATH=$(realpath "$2")
OUTDIR=$(realpath "$3")

# ===== 2. Detect System Resources =====
# Detect total CPUs and leave 2 free for system
TOTAL_CPUS=$(nproc)
USE_CPUS=$((TOTAL_CPUS - 2))
if [ "$USE_CPUS" -lt 2 ]; then USE_CPUS=2; fi

# Detect total system memory (in GB) and allocate ~90%
TOTAL_MEM_GB=$(free -g | awk '/^Mem:/{print $2}')
USE_MEM_GB=$((TOTAL_MEM_GB * 90 / 100))
if [ "$USE_MEM_GB" -lt 4 ]; then USE_MEM_GB=4; fi

echo "[INFO] Detected $TOTAL_CPUS CPUs, assigning $USE_CPUS to Nextflow."
echo "[INFO] Detected $TOTAL_MEM_GB GB RAM, assigning $USE_MEM_GB GB to Nextflow."

# ===== 3. Activate StaPH-B Toolkit =====
#mamba activate /home/edwin/.local/share/mamba/envs/stahpb-tk # do before running script

# ===== 4. Run Grandeur =====
export NXF_DEFAULT_CPUS=$USE_CPUS
export NXF_DEFAULT_MEMORY=${USE_MEM_GB}.GB

if [ "$INPUT_TYPE" == "reads" ]; then
    echo "[INFO] Running Grandeur on paired-end FASTQ reads..."
    staphb-tk grandeur \
        --reads "$INPUT_PATH" \
        --outdir "$OUTDIR"

elif [ "$INPUT_TYPE" == "fastas" ]; then
    echo "[INFO] Running Grandeur on FASTA assemblies..."# ===== 3. Activate StaPH-B Toolkit =====
mamba activate /home/edwin/.local/share/mamba/envs/stahpb-tk
    staphb-tk grandeur \
        --fastas "$INPUT_PATH" \
        --outdir "$OUTDIR"
else
    echo "[ERROR] Input type must be either 'reads' or 'fastas'"
    exit 1
fi

echo "[INFO] Grandeur finished! Results saved to: $OUTDIR"