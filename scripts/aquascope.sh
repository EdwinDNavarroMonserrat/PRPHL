#!/usr/bin/env bash
# =====================================================================
# Written by Edwin Daniel Navarro Monserrat
#
# run_aquascope_local.sh
# Runs CDCgov/aquascope using local Nextflow + Docker
# Reference: https://github.com/CDCgov/aquascope
# =====================================================================

set -euo pipefail

PIPELINE_DIR="${PIPELINE_DIR:-/home/edwin/.nextflow/assets/CDCgov/aquascope}"
BEDFILE="${BEDFILE:-/home/edwin/.nextflow/assets/CDCgov/aquascope/SARS-CoV-2.primer.bed}"

PROFILE="${PROFILE:-docker}"
ENTRY="${ENTRY:-AQUASCOPE}"
OUTDIR="${OUTDIR:-aquascope_results}"
SAMPLESHEET="${SAMPLESHEET:-samplesheet.csv}"

export NXF_VER="${NXF_VER:-25.10.2}"
export NXF_OFFLINE="${NXF_OFFLINE:-true}"
export NXF_OPTS="${NXF_OPTS:--Xms1g -Xmx4g}"

# Detect resources
TOTAL_CPUS="$(nproc)"
USE_CPUS=$((TOTAL_CPUS - 2))
[[ "$USE_CPUS" -lt 2 ]] && USE_CPUS=2

TOTAL_MEM_GB="$(free -g | awk '/^Mem:/{print $2}')"
USE_MEM_GB=$((TOTAL_MEM_GB * 90 / 100))
[[ "$USE_MEM_GB" -lt 4 ]] && USE_MEM_GB=4

export NXF_DEFAULT_CPUS="${NXF_DEFAULT_CPUS:-$USE_CPUS}"
export NXF_DEFAULT_MEMORY="${NXF_DEFAULT_MEMORY:-${USE_MEM_GB}.GB}"
export NXF_EXECUTOR_QUEUE_SIZE="${NXF_EXECUTOR_QUEUE_SIZE:-100}"

usage() {
  echo "Usage:"
  echo "  $0 <reads_directory> [outdir]"
  echo
  echo "Examples:"
  echo "  $0 reads/"
  echo "  $0 reads/ aquascope_results"
  echo "  NXF_DEFAULT_CPUS=32 NXF_DEFAULT_MEMORY=64.GB $0 reads/ results"
  exit 1
}

[[ $# -ge 1 ]] || usage

READ_DIR="$(realpath "$1")"
if [[ $# -ge 2 ]]; then
  OUTDIR="$2"
fi
OUTDIR="$(mkdir -p "$OUTDIR" && realpath "$OUTDIR")"
SAMPLESHEET="$OUTDIR/$SAMPLESHEET"

[[ -d "$READ_DIR" ]] || { echo "[ERROR] Reads directory not found: $READ_DIR"; exit 1; }
[[ -f "$BEDFILE" ]] || { echo "[ERROR] BED file not found: $BEDFILE"; exit 1; }
[[ -f "$PIPELINE_DIR/main.nf" ]] || { echo "[ERROR] Aquascope main.nf not found: $PIPELINE_DIR/main.nf"; exit 1; }

if [[ "$PROFILE" == "docker" ]]; then
  command -v docker >/dev/null 2>&1 || { echo "[ERROR] Docker not found but PROFILE=docker."; exit 2; }
fi

echo "[INFO] Pipeline dir       : $PIPELINE_DIR"
echo "[INFO] Reads dir          : $READ_DIR"
echo "[INFO] Output dir         : $OUTDIR"
echo "[INFO] Samplesheet        : $SAMPLESHEET"
echo "[INFO] BED file           : $BEDFILE"
echo "[INFO] Nextflow version   : $NXF_VER"
echo "[INFO] Offline mode       : $NXF_OFFLINE"
echo "[INFO] Profile            : $PROFILE"
echo "[INFO] Entry              : $ENTRY"
echo "[INFO] Detected CPUs      : $TOTAL_CPUS"
echo "[INFO] Assigned CPUs      : $NXF_DEFAULT_CPUS"
echo "[INFO] Detected RAM       : ${TOTAL_MEM_GB} GB"
echo "[INFO] Assigned RAM       : $NXF_DEFAULT_MEMORY"

echo "sample,platform,fastq_1,fastq_2,lr,bam_file,bedfile" > "$SAMPLESHEET"

found=0

for r1 in "$READ_DIR"/*_R1*.fastq.gz "$READ_DIR"/*_1*.fastq.gz; do
  [[ -e "$r1" ]] || continue

  r2="${r1/_R1/_R2}"
  r2="${r2/_1/_2}"

  if [[ ! -f "$r2" ]]; then
    echo "[WARN] Missing R2 pair for $r1"
    continue
  fi

  sample="$(basename "$r1")"
  sample="${sample%%_R1*}"
  sample="${sample%%_1*}"
  sample="${sample// /_}"

  echo "${sample},illumina,${r1},${r2},,,${BEDFILE}" >> "$SAMPLESHEET"
  found=$((found + 1))
done

if [[ "$found" -eq 0 ]]; then
  echo "[ERROR] No paired FASTQ files found in $READ_DIR"
  echo "Expected names like:"
  echo "  Sample_R1.fastq.gz / Sample_R2.fastq.gz"
  echo "  Sample_1.fastq.gz  / Sample_2.fastq.gz"
  exit 1
fi

echo "[INFO] Added $found samples to $SAMPLESHEET"
echo "[INFO] Running Aquascope..."

nextflow run "$PIPELINE_DIR/main.nf" \
  -profile "$PROFILE" \
  -entry "$ENTRY" \
  --input "$SAMPLESHEET" \
  --outdir "$OUTDIR" 
  

echo "[INFO] Done. Results in: $OUTDIR"
