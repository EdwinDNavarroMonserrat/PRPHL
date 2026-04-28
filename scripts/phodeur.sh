#!/bin/bash
# ==========================================
# Bash wrapper script that combines PHoeNIx + grandeur
# PHoNIx gives genome assembly + NCBI submission components
# Grandeur gives MSA, SNPdist, and some extra stuff
#
# Usage:
#   bash phodeur.sh reads /path/to/samplesheet.csv /path/to/output_root [grandeur args...]
#
# Example:
#   bash phodeur.sh reads samples.csv results --reference ref.fasta --min_cov 10
#
# Output layout:
#   output_root/
#   ├── phoenix/
#   ├── grandeur_fastas/
#   └── grandeur/
# Written by Edwin Navarro Monserrat
# ==========================================

set -Eeuo pipefail

echo "Running PHodeur: PHoeNIx -> Grandeur"

# ---------- helpers ----------
die() {
    echo "[ERROR] $*" >&2
    exit 1
}

need_cmd() {
    command -v "$1" >/dev/null 2>&1 || die "Required command not found: $1"
}

abs_path() {
    realpath "$1"
}

# ---------- args ----------
if [ "$#" -lt 3 ]; then
    echo "Usage:"
    echo "  $0 reads /path/to/samplesheet.csv /path/to/output_root [grandeur args...]"
    exit 1
fi

MODE="$1"
INPUT="$(abs_path "$2")"
OUTROOT="$(abs_path "$3")"
shift 3

# Everything left becomes extra args for grandeur
GRANDEUR_EXTRA_ARGS=("$@")

[ "$MODE" = "reads" ] || die "Mode must be 'reads'"

mkdir -p "$OUTROOT"

# ---------- requirements ----------
need_cmd staphb-tk
need_cmd realpath
need_cmd find
need_cmd awk
need_cmd free
need_cmd nproc
need_cmd gzip
need_cmd cp

# ---------- resources ----------
TOTAL_CPUS=$(nproc)
USE_CPUS=$((TOTAL_CPUS - 2))
if [ "$USE_CPUS" -lt 2 ]; then USE_CPUS=2; fi

TOTAL_MEM_GB=$(free -g | awk '/^Mem:/{print $2}')
USE_MEM_GB=$((TOTAL_MEM_GB * 90 / 100))
if [ "$USE_MEM_GB" -lt 4 ]; then USE_MEM_GB=4; fi

export NXF_DEFAULT_CPUS="$USE_CPUS"
export NXF_DEFAULT_MEMORY="${USE_MEM_GB}.GB"

echo "[INFO] Detected $TOTAL_CPUS CPUs, using $USE_CPUS"
echo "[INFO] Detected $TOTAL_MEM_GB GB RAM, using $USE_MEM_GB GB"

# ---------- paths ----------
PHX_OUT="$OUTROOT/phoenix"
GRANDEUR_FASTAS="$OUTROOT/grandeur_fastas"
GRANDEUR_OUT="$OUTROOT/grandeur"

mkdir -p "$PHX_OUT" "$GRANDEUR_FASTAS" "$GRANDEUR_OUT"

# ---------- config ----------
KRAKEN_DB="$HOME/assets/CDCgov/phoenix/assets/databases/"
echo "[INFO] Using Kraken2 DB at: $KRAKEN_DB"

# ---------- run PHoeNIx ----------
echo "[INFO] Launching PHoeNIx on reads..."
staphb-tk phoenix \
    -entry PHOENIX \
    --input "$INPUT" \
    --kraken2db "$KRAKEN_DB" \
    --outdir "$PHX_OUT" \
    --create_ncbi_sheet \
    --max_cpus "$USE_CPUS" \
    --max_memory "${USE_MEM_GB}.GB"

echo "[INFO] PHoeNIx complete."

# ---------- collect assemblies ----------
echo "[INFO] Collecting PHoeNIx assemblies for Grandeur..."

FOUND=0

while IFS= read -r sample_dir; do
    sample_name="$(basename "$sample_dir")"
    assembly_dir="$sample_dir/assembly"

    [ -d "$assembly_dir" ] || continue

    src=""
    if compgen -G "$assembly_dir/*.filtered.scaffolds.fa.gz" > /dev/null; then
        src="$(ls "$assembly_dir"/*.filtered.scaffolds.fa.gz | head -n 1)"
    elif compgen -G "$assembly_dir/*.renamed.scaffolds.fa.gz" > /dev/null; then
        src="$(ls "$assembly_dir"/*.renamed.scaffolds.fa.gz | head -n 1)"
    elif compgen -G "$assembly_dir/*.scaffolds.fa.gz" > /dev/null; then
        src="$(ls "$assembly_dir"/*.scaffolds.fa.gz | head -n 1)"
    elif compgen -G "$assembly_dir/*.filtered.scaffolds.fa" > /dev/null; then
        src="$(ls "$assembly_dir"/*.filtered.scaffolds.fa | head -n 1)"
    elif compgen -G "$assembly_dir/*.renamed.scaffolds.fa" > /dev/null; then
        src="$(ls "$assembly_dir"/*.renamed.scaffolds.fa | head -n 1)"
    elif compgen -G "$assembly_dir/*.scaffolds.fa" > /dev/null; then
        src="$(ls "$assembly_dir"/*.scaffolds.fa | head -n 1)"
    fi

    if [ -n "$src" ]; then
        dest="$GRANDEUR_FASTAS/${sample_name}.fasta"

        case "$src" in
            *.gz)
                echo "[INFO] Decompressing $src -> $dest"
                gzip -cd "$src" > "$dest"
                ;;
            *)
                echo "[INFO] Copying $src -> $dest"
                cp "$src" "$dest"
                ;;
        esac

        FOUND=$((FOUND + 1))
    else
        echo "[WARN] No usable assembly found for sample: $sample_name"
    fi
done < <(find "$PHX_OUT" -mindepth 1 -maxdepth 1 -type d ! -name multiqc ! -name pipeline_info | sort)

[ "$FOUND" -gt 0 ] || die "No assemblies were collected from PHoeNIx output."

echo "[INFO] Collected $FOUND assemblies into: $GRANDEUR_FASTAS"

# ---------- run Grandeur ----------
echo "[INFO] Launching Grandeur on PHoeNIx assemblies..."
if [ "${#GRANDEUR_EXTRA_ARGS[@]}" -gt 0 ]; then
    echo "[INFO] Extra Grandeur args: ${GRANDEUR_EXTRA_ARGS[*]}"
fi

staphb-tk grandeur \
    --fastas "$GRANDEUR_FASTAS" \
    --outdir "$GRANDEUR_OUT" \
    "${GRANDEUR_EXTRA_ARGS[@]}"

echo
echo "[INFO] PHodeur finished successfully."
echo "[INFO] PHoeNIx results:   $PHX_OUT"
echo "[INFO] FASTA bridge dir:  $GRANDEUR_FASTAS"
echo "[INFO] Grandeur results:  $GRANDEUR_OUT"