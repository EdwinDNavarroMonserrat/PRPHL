!/usr/bin/env bash
# ============================================================
# Written by EDNM
# Wrapper for: staphb-tk mycosnp
# - Detects CPU cores & RAM automatically
# - Sets Nextflow defaults (NXF_DEFAULT_CPUS / NXF_DEFAULT_MEMORY)
# - Requires: --workflow, --input, --outdir
# - Passes any other args straight through to staphb-tk mycosnp
#
# Examples:
#   bash mycosnp.sh --workflow PRE_MYCOSNP --input samples.csv --outdir results/
#   bash mycosnp.sh --workflow NFCORE_MYCOSNP --input samples.csv --outdir results/ \
#       --species "Candida auris" --ref_dir /path/to/refdir --snpeff --iqtree
#
# Notes:
# - Activate the StaPH-B toolkit env BEFORE running:
#     mamba activate /home/edwin/.local/share/mamba/envs/stahpb-tk
# ============================================================


set -euo pipefail

script_name="$(basename "$0")"

die() { echo "[ERROR] $*" >&2; exit 1; }

usage() {
  cat <<USAGE
Usage:
  $script_name --workflow <PRE_MYCOSNP|NFCORE_MYCOSNP> --input <samples.csv> --outdir <output_dir> [additional mycosnp params]

Required:
  --workflow   Name of workflow to run: PRE_MYCOSNP or NFCORE_MYCOSNP
  --input      Path to comma-separated samplesheet for the run
  --outdir     Output directory

Common optional examples (all are forwarded to staphb-tk mycosnp):
  --email <addr>                 Completion email
  --email_on_fail <addr>         Email only if fails
  --add_sra_file <file.csv>      Download SRA ids (Name,SRAID)
  --add_vcf_file <file.csv>      (NFCORE_MYCOSNP only) List of VCFs to include
  --ref_dir <dir>                Use pre-built reference directory
  --fasta <ref.fasta>            Reference FASTA (if not using --ref_dir)
  --species <name>               Species name
  --snpeff                        Run snpEff
  --iqtree|--fasttree|--rapidnj    Phylogeny method flags

Tip: to see full mycosnp parameters:
  staphb-tk mycosnp --help
USAGE
}

# -------------------- Parse args --------------------
WORKFLOW=""
INPUT=""
OUTDIR=""
PASSTHRU=()

while [[ $# -gt 0 ]]; do
  case "$1" in
    -h|--help)
      usage; exit 0;;
    --workflow)
      [[ $# -ge 2 ]] || die "--workflow requires a value"
      WORKFLOW="$2"; shift 2;;
    --input)
      [[ $# -ge 2 ]] || die "--input requires a value"
      INPUT="$2"; shift 2;;
    --outdir)
      [[ $# -ge 2 ]] || die "--outdir requires a value"
      OUTDIR="$2"; shift 2;;
    --) # end of our parsing; rest is passthrough
      shift
      PASSTHRU+=("$@"); break;;
    *)
      # Anything else: forward directly (keeps your original flags)
      PASSTHRU+=("$1")
      shift;;
  esac
done

[[ -n "$WORKFLOW" ]] || die "Missing required --workflow"
[[ -n "$INPUT" ]]    || die "Missing required --input"
[[ -n "$OUTDIR" ]]   || die "Missing required --outdir"

# Normalize/validate paths (don't require outdir to exist)
INPUT_REAL="$(realpath "$INPUT")"
OUTDIR_REAL="$(realpath -m "$OUTDIR")"

# -------------------- Detect resources --------------------
TOTAL_CPUS="$(nproc)"
USE_CPUS=$((TOTAL_CPUS - 2))
(( USE_CPUS < 2 )) && USE_CPUS=2

TOTAL_MEM_GB="$(free -g | awk '/^Mem:/{print $2}')"
USE_MEM_GB=$((TOTAL_MEM_GB * 90 / 100))
(( USE_MEM_GB < 4 )) && USE_MEM_GB=4

echo "[INFO] Detected $TOTAL_CPUS CPUs, assigning $USE_CPUS to Nextflow."
echo "[INFO] Detected $TOTAL_MEM_GB GB RAM, assigning $USE_MEM_GB GB to Nextflow."

export NXF_DEFAULT_CPUS="$USE_CPUS"
export NXF_DEFAULT_MEMORY="${USE_MEM_GB}.GB"

# -------------------- Basic workflow sanity checks --------------------
case "$WORKFLOW" in
  PRE_MYCOSNP|NFCORE_MYCOSNP) ;;
  *) die "Invalid --workflow '$WORKFLOW' (must be PRE_MYCOSNP or NFCORE_MYCOSNP)";;
esac

# NFCORE_MYCOSNP-only param guard: if user passes --add_vcf_file with PRE_MYCOSNP, warn
if [[ "$WORKFLOW" == "PRE_MYCOSNP" ]]; then
  for a in "${PASSTHRU[@]}"; do
    if [[ "$a" == "--add_vcf_file" ]]; then
      echo "[WARN] You passed --add_vcf_file but workflow is PRE_MYCOSNP (parameter is intended for main workflow)."
      break
    fi
  done
fi

# -------------------- Run pipeline --------------------
command -v staphb-tk >/dev/null 2>&1 || die "staphb-tk not found in PATH. Activate your environment first."

echo "[INFO] Running MycoSNP ($WORKFLOW)"
echo "[INFO] Input : $INPUT_REAL"
echo "[INFO] Outdir: $OUTDIR_REAL"

set -x
staphb-tk mycosnp \
  --workflow "$WORKFLOW" \
  --input "$INPUT_REAL" \
  --outdir "$OUTDIR_REAL" \
  "${PASSTHRU[@]}"
set +x

echo "[INFO] MycoSNP finished! Results saved to: $OUTDIR_REAL"
