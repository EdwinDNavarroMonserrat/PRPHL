#!/bin/bash
# ==========================================
# CorGe+ local runner
# Nextflow + Docker
#
# Usage:
#   bash corge.sh run manifest.csv /path/to/output [metadata.csv]
#
# Examples:
#   bash corge.sh run manifest.csv corge_results
#   bash corge.sh run manifest.csv corge_results metadata.csv
#
# Written by Edwin Navarro Monserrat
# ==========================================

set -Eeuo pipefail

echo "=========================================="
echo " CorGe+ Local Runner"
echo "=========================================="

# ---------- helpers ----------
die() {
    echo "[ERROR] $*" >&2
    exit 1
}

need_cmd() {
    command -v "$1" >/dev/null 2>&1 || die "Required command not found: $1"
}

# ---------- requirements ----------
need_cmd nextflow
need_cmd docker
need_cmd realpath
need_cmd free
need_cmd nproc

# ---------- paths ----------
CORGE_REPO="$HOME/.nextflow/assets/corge"
SCHEMA_CSV="$CORGE_REPO/cgmlst_schemas.csv"

[[ -d "$CORGE_REPO" ]] || die "CorGe repository not found: $CORGE_REPO"
[[ -f "$CORGE_REPO/main.nf" ]] || die "CorGe main.nf not found: $CORGE_REPO/main.nf"
[[ -f "$SCHEMA_CSV" ]] || die "cgMLST schema CSV not found: $SCHEMA_CSV"

# ---------- arguments ----------
if [[ "$#" -lt 3 || "$#" -gt 4 ]]; then
    echo
    echo "Usage:"
    echo "  $0 run /path/to/manifest.csv /path/to/output [metadata.csv]"
    echo
    echo "Examples:"
    echo "  $0 run manifest.csv corge_results"
    echo "  $0 run manifest.csv corge_results metadata.csv"
    echo
    exit 1
fi

MODE="$1"

[[ "$MODE" == "run" ]] || die "Mode must be 'run'"

MANIFEST="$(realpath "$2")"

mkdir -p "$3"
OUTDIR="$(realpath "$3")"

[[ -f "$MANIFEST" ]] || die "Manifest not found: $MANIFEST"

# ---------- optional metadata ----------
METADATA=""

if [[ "$#" -eq 4 ]]; then
    METADATA="$(realpath "$4")"
    [[ -f "$METADATA" ]] || die "Metadata not found: $METADATA"
fi

# ---------- resources ----------
TOTAL_CPUS=$(nproc)

USE_CPUS=$((TOTAL_CPUS - 2))
if [[ "$USE_CPUS" -lt 2 ]]; then
    USE_CPUS=2
fi

TOTAL_MEM_GB=$(free -g | awk '/^Mem:/{print $2}')

USE_MEM_GB=$((TOTAL_MEM_GB * 90 / 100))
if [[ "$USE_MEM_GB" -lt 4 ]]; then
    USE_MEM_GB=4
fi

export NXF_DEFAULT_CPUS="$USE_CPUS"
export NXF_DEFAULT_MEMORY="${USE_MEM_GB}.GB"

# Match the local Nextflow version used by the other workflows
export NXF_VER=25.10.2

# ---------- run information ----------
echo
echo "[INFO] CorGe repository: $CORGE_REPO"
echo "[INFO] Manifest:         $MANIFEST"
echo "[INFO] Schemas:          $SCHEMA_CSV"
echo "[INFO] Output:           $OUTDIR"

if [[ -n "$METADATA" ]]; then
    echo "[INFO] Metadata:         $METADATA"
else
    echo "[INFO] Metadata:         none"
fi

echo
echo "[INFO] Detected CPUs:    $TOTAL_CPUS"
echo "[INFO] Using CPUs:       $USE_CPUS"
echo "[INFO] Detected RAM:     ${TOTAL_MEM_GB} GB"
echo "[INFO] Memory limit:     ${USE_MEM_GB} GB"
echo

# ---------- Docker check ----------
if ! docker info >/dev/null 2>&1; then
    die "Docker is installed but the Docker daemon is not available."
fi

echo "[INFO] Docker is available."

# ---------- schema path check ----------
echo
echo "[INFO] Checking cgMLST schema paths..."

MISSING=0

while IFS=, read -r species path; do

    # Remove Windows carriage returns if present
    species="${species//$'\r'/}"
    path="${path//$'\r'/}"

    [[ "$species" == "species" ]] && continue
    [[ -z "$species" ]] && continue

    if [[ -d "$path" ]]; then
        echo "[OK] $species"
    else
        echo "[MISSING] $species -> $path"
        MISSING=$((MISSING + 1))
    fi

done < "$SCHEMA_CSV"

if [[ "$MISSING" -gt 0 ]]; then
    die "$MISSING cgMLST schema path(s) could not be found."
fi

# ---------- build CorGe arguments ----------
CORGE_ARGS=(
    -profile docker
    --input "$MANIFEST"
    --cgmlst_schemas "$SCHEMA_CSV"
    --outdir "$OUTDIR"
    --max_cpus "$USE_CPUS"
    --max_memory "${USE_MEM_GB}.GB"
)

# Add metadata only when provided
if [[ -n "$METADATA" ]]; then
    CORGE_ARGS+=(
        --metadata "$METADATA"
    )
fi

# ---------- run CorGe ----------
echo
echo "=========================================="
echo " Launching CorGe+"
echo "=========================================="
echo

nextflow run "$CORGE_REPO" \
    "${CORGE_ARGS[@]}" \
    -resume

echo
echo "=========================================="
echo " CorGe+ finished successfully"
echo "=========================================="
echo
echo "[INFO] Results:"
echo "       $OUTDIR"
