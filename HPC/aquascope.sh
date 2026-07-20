#!/bin/bash
#SBATCH --account=bphl-umbrella
#SBATCH --qos=bphl-umbrella
#SBATCH --job-name=aquascope
#SBATCH --cpus-per-task=8
#SBATCH --mem=64G
#SBATCH --time=48:00:00
#SBATCH --output=aquascope_%j.out
#SBATCH --error=aquascope_%j.err
#SBATCH --mail-type=END,FAIL
#SBATCH --mail-user=enavarro.monserrat@salud.pr.gov

set -euo pipefail

module purge
module load apptainer
module load nextflow/25.10.4

# ===== Paths =====
BASE="/blue/bphl-puertorico/enavarromonserra/WW_analyses"
PIPELINE="/blue/bphl-puertorico/enavarromonserra/repos/aquascope"

READ_DIR="${BASE}/fastq"
BEDFILE="${BASE}/SARS-CoV-2.primer.bed"
SAMPLESHEET="${BASE}/samplesheet.csv"

OUTDIR="${BASE}/results"
WORKDIR="${BASE}/work"

# ===== Apptainer / Nextflow cache =====
export APPTAINER_CACHEDIR="${BASE}/apptainer_cache"
export APPTAINER_TMPDIR="${BASE}/apptainer_tmp"
export NXF_SINGULARITY_CACHEDIR="${BASE}/nextflow_images"
export NXF_OPTS="-Xms1g -Xmx4g"

mkdir -p \
    "$OUTDIR" \
    "$WORKDIR" \
    "$APPTAINER_CACHEDIR" \
    "$APPTAINER_TMPDIR" \
    "$NXF_SINGULARITY_CACHEDIR"

# ===== Validate paths =====
if [[ ! -d "$PIPELINE" ]]; then
    echo "[ERROR] AquaScope repository not found:"
    echo "        $PIPELINE"
    exit 1
fi

if [[ ! -f "$PIPELINE/main.nf" ]]; then
    echo "[ERROR] AquaScope main.nf not found:"
    echo "        $PIPELINE/main.nf"
    exit 1
fi

if [[ ! -d "$READ_DIR" ]]; then
    echo "[ERROR] FASTQ directory not found:"
    echo "        $READ_DIR"
    exit 1
fi

if [[ ! -f "$BEDFILE" ]]; then
    echo "[ERROR] BED file not found:"
    echo "        $BEDFILE"
    exit 1
fi

# ===== Create samplesheet =====
echo "[INFO] Creating AquaScope samplesheet."
echo "[INFO] FASTQ directory: $READ_DIR"
echo "[INFO] BED file: $BEDFILE"

echo "sample,platform,fastq_1,fastq_2,lr,bam_file,bedfile" > "$SAMPLESHEET"

found=0
shopt -s nullglob

R1_FILES=(
    "$READ_DIR"/*_R1*.fastq.gz
    "$READ_DIR"/*_1.fastq.gz
)

for r1 in "${R1_FILES[@]}"; do

    filename="$(basename "$r1")"

    if [[ "$filename" == *_R1* ]]; then
        r2="${r1/_R1/_R2}"
        sample="${filename%%_R1*}"

    elif [[ "$filename" == *_1.fastq.gz ]]; then
        r2="${r1%_1.fastq.gz}_2.fastq.gz"
        sample="${filename%_1.fastq.gz}"

    else
        continue
    fi

    if [[ ! -f "$r2" ]]; then
        echo "[WARNING] Missing R2 for sample: $sample"
        echo "[WARNING] R1: $r1"
        echo "[WARNING] Expected R2: $r2"
        continue
    fi

    sample="${sample// /_}"

    echo "${sample},illumina,${r1},${r2},,,${BEDFILE}" >> "$SAMPLESHEET"

    found=$((found + 1))
done

if [[ "$found" -eq 0 ]]; then
    echo "[ERROR] No complete paired FASTQ samples were found in:"
    echo "        $READ_DIR"
    exit 1
fi

echo "[INFO] Created samplesheet with $found samples:"
echo "[INFO] $SAMPLESHEET"
cat "$SAMPLESHEET"

# ===== Run AquaScope =====
echo "[INFO] Launching AquaScope."

nextflow run "$PIPELINE/main.nf" \
    -entry AQUASCOPE \
    -profile singularity \
    --input "$SAMPLESHEET" \
    --outdir "$OUTDIR" \
    -work-dir "$WORKDIR" \
    -resume

echo "[INFO] AquaScope completed successfully."
echo "[INFO] Results are in: $OUTDIR"

