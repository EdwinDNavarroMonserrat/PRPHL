#!/bin/bash
#SBATCH --account=bphl-umbrella
#SBATCH --qos=bphl-umbrella
#SBATCH --job-name=SRA_download
#SBATCH --cpus-per-task=8
#SBATCH --mem=50G
#SBATCH --time=8:00:00
#SBATCH --output=SRA_dl_%j.out
#SBATCH --error=SRA_dl_%j.err
#SBATCH --mail-type=END,FAIL
#SBATCH --mail-user=enavarro.monserrat@salud.pr.gov

set -euo pipefail

echo "This script downloads raw reads from NCBI SRA and compresses them."

module load sra/3.2.1

SRR_LIST="SRRs.txt"
OUTDIR="fastq"
TMPDIR="${SLURM_TMPDIR:-/tmp/fasterq_${SLURM_JOB_ID}}"

if [[ ! -f "$SRR_LIST" ]]; then
    echo "[ERROR] Cannot find $SRR_LIST"
    exit 1
fi

mkdir -p "$OUTDIR"
mkdir -p "$TMPDIR"

echo "[INFO] Downloading and compressing reads."

download_srr() {
    SRR="$1"

    echo "[INFO] Downloading $SRR"

    mkdir -p "$TMPDIR/$SRR"

    fasterq-dump "$SRR" \
        --split-files \
        --threads 4 \
        --temp "$TMPDIR/$SRR" \
        --outdir "$OUTDIR"

    echo "[INFO] Compressing $SRR"

    pigz -p 4 "$OUTDIR/${SRR}"_*.fastq

    echo "[INFO] Finished $SRR"
}

export -f download_srr
export OUTDIR TMPDIR

grep -v '^[[:space:]]*$' "$SRR_LIST" |
    sed 's/\r$//' |
    xargs -P 2 -I {} bash -c 'download_srr "$1"' _ {}

echo "[INFO] All downloads completed."
echo "[INFO] FASTQ files are available in: $OUTDIR"

echo "[INFO] Renaming files to Illumina convention (_R1/_R2)..."

for f in fastq/*_1.fastq.gz; do
    mv "$f" "${f/_1.fastq.gz/_R1.fastq.gz}"
done

for f in fastq/*_2.fastq.gz; do
    mv "$f" "${f/_2.fastq.gz/_R2.fastq.gz}"
done

echo "[INFO] Renaming complete."