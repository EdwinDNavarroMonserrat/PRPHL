#!/bin/bash
#SBATCH --account=bphl-umbrella
#SBATCH --qos=bphl-umbrella
#SBATCH --job-name=corge
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=40
#SBATCH --mem=200gb
#SBATCH --time=48:00:00
#SBATCH --output=corge_%j.out
#SBATCH --error=corge_%j.err
#SBATCH --mail-type=END,FAIL
#SBATCH --mail-user=enavarro.monserrat@salud.pr.gov

set -euo pipefail

# ==========================================
# CorGe+ Runner
# HPC / SLURM / Apptainer
# Written by Edwin Navarro Monserrat
#
# Usage:
#
# Download cgMLST schemas:
#   sbatch corge.sh download_schema s1,s20 /path/to/output
#
# Run CorGe+:
#   sbatch corge.sh run /path/to/manifest.csv /path/to/output /path/to/cgmlst_schemas.csv
#
# Examples:
#
#   sbatch corge.sh download_schema s1,s20 corge_schemas
#
#   sbatch corge.sh run \
#       manifest.csv \
#       corge_results \
#       /blue/bphl-puertorico/enavarromonserra/corge_schemas/cgmlst_schemas/cgmlst_schemas.csv
#
# ==========================================

echo "=========================================="
echo " CorGe+ Runner"
echo "=========================================="

# ------------------------------------------
# Load modules
# ------------------------------------------

module load nextflow/25.10.4
module load singularity
module load apptainer/1.4.2

# ------------------------------------------
# Container caches
# ------------------------------------------

export NXF_SINGULARITY_CACHEDIR="/blue/bphl-puertorico/enavarromonserra/singularity/nextflow"
export APPTAINER_CACHEDIR="/blue/bphl-puertorico/enavarromonserra/singularity/apptainer"
export APPTAINER_TMPDIR="/blue/bphl-puertorico/enavarromonserra/singularity/tmp"

export SINGULARITY_CACHEDIR="$APPTAINER_CACHEDIR"
export SINGULARITY_TMPDIR="$APPTAINER_TMPDIR"

mkdir -p "$NXF_SINGULARITY_CACHEDIR"
mkdir -p "$APPTAINER_CACHEDIR"
mkdir -p "$APPTAINER_TMPDIR"

# ------------------------------------------
# CorGe repository
# ------------------------------------------

CORGE_REPO="/blue/bphl-puertorico/enavarromonserra/repos/corge"

if [[ ! -d "$CORGE_REPO" ]]; then
    echo "[ERROR] CorGe repository not found:"
    echo "        $CORGE_REPO"
    exit 1
fi

# ------------------------------------------
# Resources
# ------------------------------------------

USE_CPUS="${SLURM_CPUS_PER_TASK:-8}"

# Keep below total SLURM allocation
USE_MEM_GB=180

echo "[INFO] CorGe repo: $CORGE_REPO"
echo "[INFO] CPUs: $USE_CPUS"
echo "[INFO] Memory limit: ${USE_MEM_GB} GB"

# ==========================================
# Check mode
# ==========================================

if [[ "$#" -lt 1 ]]; then
    echo
    echo "Usage:"
    echo
    echo "  Download schemas:"
    echo "    $0 download_schema schema_ids /path/to/output"
    echo
    echo "  Run CorGe+:"
    echo "    $0 run manifest.csv /path/to/output /path/to/cgmlst_schemas.csv"
    echo
    exit 1
fi

MODE="$1"

# ==========================================
# DOWNLOAD SCHEMA MODE
# ==========================================

if [[ "$MODE" == "download_schema" ]]; then

    if [[ "$#" -ne 3 ]]; then
        echo "Usage:"
        echo "  $0 download_schema schema_ids /path/to/output"
        echo
        echo "Example:"
        echo "  $0 download_schema s1,s20 corge_schemas"
        exit 1
    fi

    SCHEMA_IDS="$2"

    mkdir -p "$3"
    OUTDIR="$(realpath "$3")"

    echo
    echo "[INFO] Mode: download_schema"
    echo "[INFO] Schema IDs: $SCHEMA_IDS"
    echo "[INFO] Output: $OUTDIR"
    echo

    nextflow run "$CORGE_REPO" \
        -profile apptainer \
        --mode download_schema \
        --schema_ids "$SCHEMA_IDS" \
        --outdir "$OUTDIR" \
        -resume

# ==========================================
# RUN CORGE MODE
# ==========================================

elif [[ "$MODE" == "run" ]]; then

    if [[ "$#" -ne 4 ]]; then
        echo "Usage:"
        echo "  $0 run manifest.csv /path/to/output /path/to/cgmlst_schemas.csv"
        exit 1
    fi

    MANIFEST="$(realpath "$2")"

    mkdir -p "$3"
    OUTDIR="$(realpath "$3")"

    SCHEMA_CSV="$(realpath "$4")"

    if [[ ! -f "$MANIFEST" ]]; then
        echo "[ERROR] Manifest not found:"
        echo "        $MANIFEST"
        exit 1
    fi

    if [[ ! -f "$SCHEMA_CSV" ]]; then
        echo "[ERROR] cgMLST schema CSV not found:"
        echo "        $SCHEMA_CSV"
        exit 1
    fi

    echo
    echo "[INFO] Mode: CorGe+ analysis"
    echo "[INFO] Manifest: $MANIFEST"
    echo "[INFO] Schemas: $SCHEMA_CSV"
    echo "[INFO] Output: $OUTDIR"
    echo

    nextflow run "$CORGE_REPO" \
        -profile apptainer \
        --input "$MANIFEST" \
        --cgmlst_schemas "$SCHEMA_CSV" \
        --outdir "$OUTDIR" \
        -resume

else

    echo "[ERROR] Unknown mode: $MODE"
    echo
    echo "Valid modes:"
    echo "  download_schema"
    echo "  run"
    exit 1

fi

echo
echo "=========================================="
echo "[INFO] CorGe+ finished successfully."
echo "=========================================="