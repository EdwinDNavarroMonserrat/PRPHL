#!/bin/bash
#SBATCH --account=bphl-umbrella
#SBATCH --qos=bphl-umbrella
#SBATCH --job-name=phoenix
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=40
#SBATCH --mem=200gb
#SBATCH --time=48:00:00
#SBATCH --output=phoenix_%j.out
#SBATCH --error=phoenix_%j.err
#SBATCH --mail-type=END,FAIL
#SBATCH --mail-user=enavarro.monserrat@salud.pr.gov

set -euo pipefail

echo "This script runs PHoeNIx."

# Load required modules
module load nextflow/25.10.4
module load singularity
module load apptainer/1.4.2

# Export  singularity cache
export NXF_SINGULARITY_CACHEDIR="/blue/bphl-puertorico/enavarromonserra/singularity/nextflow"
export APPTAINER_CACHEDIR="/blue/bphl-puertorico/enavarromonserra/singularity/apptainer"
export APPTAINER_TMPDIR="/blue/bphl-puertorico/enavarromonserra/singularity/tmp"

export SINGULARITY_CACHEDIR="$APPTAINER_CACHEDIR"
export SINGULARITY_TMPDIR="$APPTAINER_TMPDIR"

mkdir -p "$NXF_SINGULARITY_CACHEDIR"
mkdir -p "$APPTAINER_CACHEDIR"
mkdir -p "$APPTAINER_TMPDIR"

# Check arguments
if [[ "$#" -ne 3 ]]; then
    echo "Usage:"
    echo "  $0 reads /path/to/fastq_directory /path/to/output"
    echo "  $0 scaffolds /path/to/fasta_directory /path/to/output"
    exit 1
fi

MODE="$1"
INPUT="$(realpath "$2")"

mkdir -p "$3"
OUTDIR="$(realpath "$3")"

# Path to cloned PHoeNIx repository
PHOENIX_REPO="/blue/bphl-puertorico/enavarromonserra/repos/phoenix"

# PHoeNIx samplesheet generator
PERL_SCRIPT="$PHOENIX_REPO/bin/create_samplesheet.pl"

# Kraken2 database
KRAKEN_DB="$PHOENIX_REPO/assets/databases"

# Resources
USE_CPUS="${SLURM_CPUS_PER_TASK:-8}"
USE_MEM_GB=64

echo "[INFO] Mode: $MODE"
echo "[INFO] Input: $INPUT"
echo "[INFO] Output: $OUTDIR"

if [[ "$MODE" == "reads" ]]; then

    echo "[INFO] Creating PHoeNIx samplesheet..."

    NOHEADER_SAMPLESHEET="$OUTDIR/samplesheet.noheader.csv"
    SAMPLESHEET="$OUTDIR/samplesheet.csv"

    perl "$PERL_SCRIPT" \
        -i "$INPUT" \
        -o "$NOHEADER_SAMPLESHEET"

    {
        echo "sample,fastq_1,fastq_2"
        cat "$NOHEADER_SAMPLESHEET"
    } > "$SAMPLESHEET"

    echo "[INFO] Samplesheet created:"
    cat "$SAMPLESHEET"

    nextflow run "$PHOENIX_REPO" \
        -profile singularity \
        --mode PHOENIX \
        --input "$SAMPLESHEET" \
        --kraken2db "$KRAKEN_DB" \
        --outdir "$OUTDIR" \
        --max_cpus "$USE_CPUS" \
        --max_memory "${USE_MEM_GB}.GB" \
        -resume

elif [[ "$MODE" == "scaffolds" ]]; then

    echo "[INFO] Running PHoeNIx on FASTA scaffolds..."

    SCAFFOLD_EXT=".fasta.gz"

    nextflow run "$PHOENIX_REPO" \
        -profile singularity \
        --mode SCAFFOLDS \
        --indir "$INPUT" \
        --scaffold_ext "$SCAFFOLD_EXT" \
        --kraken2db "$KRAKEN_DB" \
        --outdir "$OUTDIR" \
        --max_cpus "$USE_CPUS" \
        --max_memory "${USE_MEM_GB}.GB" \
        -resume

else
    echo "[ERROR] Mode must be 'reads' or 'scaffolds'."
    exit 1
fi

echo "[INFO] PHoeNIx finished successfully."
echo "[INFO] Results saved to: $OUTDIR"
