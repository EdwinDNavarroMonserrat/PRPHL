#!/usr/bin/env bash
# =====================================================================
# Written by Edwin Daniel Navarro Monserrat
# run_cecret_tk.sh — wrapper for StaPH-B Toolkit's Cecret workflow
#
# DEFAULT PRIMERS: ARTIC v5.3.2  (--primer_set ncov_V5.3.2)
# DEFAULT REFERENCE GENOME (Wuhan-Hu-1, MN908947.3)
#
# Added defaults (documented in Cecret README):
#   --aci true
#   --relatedness true
#   --msa nextclade
# Usage:
#   ./run_cecret_tk.sh paired      /path/to/reads_dir        /path/to/outdir [extra cecret args...]
#   ./run_cecret_tk.sh single      /path/to/single_reads_dir /path/to/outdir [extra cecret args...]
#   ./run_cecret_tk.sh ont         /path/to/ont_dir          /path/to/outdir [extra cecret args...]
#   ./run_cecret_tk.sh fastas      /path/to/fastas_dir       /path/to/outdir [extra cecret args...]
#   ./run_cecret_tk.sh multifastas /path/to/multifastas_dir  /path/to/outdir [extra cecret args...]
#   ./run_cecret_tk.sh sheet       /path/to/SampleSheet.csv  /path/to/outdir [extra cecret args...]
#
# Examples:
#   ./run_cecret_tk.sh paired ./reads ./cecret_out
#   ./run_cecret_tk.sh paired ./reads ./cecret_out --minimum_depth 50
#   ./run_cecret_tk.sh sheet  ./SampleSheet.csv ./cecret_out --relatedness true
# =====================================================================

set -euo pipefail

# ---- Defaults you can edit ---------------------------------------------------
PRIMER_SET="ncov_V5.3.2"
REFERENCE_GENOME="/home/edwin/assets/UPHL-BioNGS/Cecret/genomes/MN908947.3.fasta"
# -----------------------------------------------------------------------------

if [[ $# -lt 3 ]]; then
  echo "Usage:"
  echo "  $0 {paired|single|ont|fastas|multifastas|sheet} <INPUT_PATH> <OUTDIR> [extra cecret args...]"
  exit 1
fi

MODE="$1"
INPUT_PATH="$2"
OUTDIR="$3"
shift 3
EXTRA_ARGS=("$@")   # passthrough to staphb-tk cecret

# ---- Helpers ----------------------------------------------------------------
to_abs() {
  if command -v realpath >/dev/null 2>&1; then
    realpath "$1"
  else
    python3 - <<PY
import os,sys
print(os.path.abspath(sys.argv[1]))
PY
  fi
}
INPUT_PATH_ABS="$(to_abs "$INPUT_PATH")"
OUTDIR_ABS="$(to_abs "$OUTDIR")"
REF_ABS="$(to_abs "$REFERENCE_GENOME")"

# ---- Preflight checks --------------------------------------------------------
if [[ "$MODE" == "sheet" ]]; then
  [[ -f "$INPUT_PATH_ABS" ]] || { echo "[ERROR] Sample sheet not found: $INPUT_PATH_ABS"; exit 2; }
else
  [[ -d "$INPUT_PATH_ABS" ]] || { echo "[ERROR] Input directory not found: $INPUT_PATH_ABS"; exit 2; }
fi
[[ -f "$REF_ABS" ]] || { echo "[ERROR] Reference genome not found: $REF_ABS"; exit 2; }
[[ -r "$REF_ABS" ]] || { echo "[ERROR] Reference genome not readable: $REF_ABS"; exit 2; }
mkdir -p "$OUTDIR_ABS"

# ---- Light Nextflow resource hints ------------------------------------------
TOTAL_CPUS="$(nproc 2>/dev/null || echo 4)"
USE_CPUS=$(( TOTAL_CPUS>2 ? TOTAL_CPUS-2 : 2 ))
TOTAL_MEM_GB="$(free -g 2>/dev/null | awk '/^Mem:/{print $2}' || echo 8)"
USE_MEM_GB=$(( TOTAL_MEM_GB*90/100 ))
[[ $USE_MEM_GB -lt 4 ]] && USE_MEM_GB=4

export NXF_DEFAULT_CPUS="$USE_CPUS"
export NXF_DEFAULT_MEMORY="${USE_MEM_GB}.GB"

echo "[INFO] NXF_DEFAULT_CPUS=$NXF_DEFAULT_CPUS"
echo "[INFO] NXF_DEFAULT_MEMORY=$NXF_DEFAULT_MEMORY"
echo "[INFO] OUTDIR=$OUTDIR_ABS"
echo "[INFO] Primer scheme: $PRIMER_SET"
echo "[INFO] Reference: $REF_ABS"

# ---- Optional pairing sanity for 'paired' mode -------------------------------
if [[ "$MODE" == "paired" ]]; then
  if ! compgen -G "${INPUT_PATH_ABS}/*{_1,_R1}.f*q.gz" >/dev/null; then
    echo "[WARN] Could not find typical R1 filenames in $INPUT_PATH_ABS (expected *_1.fastq.gz or *R1*.fastq.gz)."
  fi
fi

# ---- Dispatch to Cecret via staphb-tk ---------------------------------------
case "$MODE" in
  paired)
    echo "[INFO] Running Cecret with paired-end reads: $INPUT_PATH_ABS"
    staphb-tk cecret \
      --reads "$INPUT_PATH_ABS" \
      --outdir "$OUTDIR_ABS" \
      --primer_set "$PRIMER_SET" \
      --reference_genome "$REF_ABS" \
      --aci true \
      --relatedness true \
      --msa nextclade \
      --iqtree true \
      --heatcluster true \
      --phytreeviz true \
      "${EXTRA_ARGS[@]}" 
    ;;
  single)
    echo "[INFO] Running Cecret with single-end reads: $INPUT_PATH_ABS"
    staphb-tk cecret \
      --single_reads "$INPUT_PATH_ABS" \
      --outdir "$OUTDIR_ABS" \
      --primer_set "$PRIMER_SET" \
      --reference_genome "$REF_ABS" \
      --aci true \
      --relatedness true \
      --msa nextclade \
      "${EXTRA_ARGS[@]}"
    ;;
  ont)
    echo "[INFO] Running Cecret with Nanopore reads: $INPUT_PATH_ABS"
    staphb-tk cecret \
      --nanopore "$INPUT_PATH_ABS" \
      --outdir "$OUTDIR_ABS" \
      --primer_set "$PRIMER_SET" \
      --reference_genome "$REF_ABS" \
      --aci true \
      --relatedness true \
      --msa nextclade \
      "${EXTRA_ARGS[@]}"
    ;;
  fastas)
    echo "[INFO] Running Cecret on FASTA directory: $INPUT_PATH_ABS"
    staphb-tk cecret \
      --fastas "$INPUT_PATH_ABS" \
      --outdir "$OUTDIR_ABS" \
      --primer_set "$PRIMER_SET" \
      --reference_genome "$REF_ABS" \
      --aci true \
      --relatedness true \
      --msa nextclade \
      "${EXTRA_ARGS[@]}"
    ;;
  multifastas)
    echo "[INFO] Running Cecret on MultiFASTA directory: $INPUT_PATH_ABS"
    staphb-tk cecret \
      --multifastas "$INPUT_PATH_ABS" \
      --outdir "$OUTDIR_ABS" \
      --primer_set "$PRIMER_SET" \
      --reference_genome "$REF_ABS" \
      --aci true \
      --relatedness true \
      --msa nextclade \
      "${EXTRA_ARGS[@]}"
    ;;
  sheet)
    echo "[INFO] Running Cecret with sample sheet: $INPUT_PATH_ABS"
    staphb-tk cecret \
      --sample_sheet "$INPUT_PATH_ABS" \
      --outdir "$OUTDIR_ABS" \
      --primer_set "$PRIMER_SET" \
      --reference_genome "$REF_ABS" \
      --aci true \
      --relatedness true \
      --msa nextclade \
      "${EXTRA_ARGS[@]}"
    ;;
  *)
    echo "[ERROR] MODE must be one of: paired | single | ont | fastas | multifastas | sheet"
    exit 3
    ;;
esac

echo "[INFO] Done. Results in: $OUTDIR_ABS"

