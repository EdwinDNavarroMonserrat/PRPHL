#!/bin/bash
#SBATCH --account=bphl-umbrella
#SBATCH --qos=bphl-umbrella
#SBATCH --job-name=sanibel
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=40
#SBATCH --mem=200gb
#SBATCH --time=48:00:00
#SBATCH --output=sanibel_%j.out
#SBATCH --error=sanibel_%j.err
#SBATCH --mail-type=END,FAIL
#SBATCH --mail-user=enavarro.monserrat@salud.pr.gov

set -euo pipefail

echo "This script runs SANIBEL, a bacterial WGS pipeline developed by BPHL."
echo "[INFO] Make sure that the parmams.yaml file has the correct paths before running"

# ===== Modules =====
module purge
module load conda
module load apptainer
module load nextflow/25.10.4

# ===== Sanibel repository =====
SANIBEL_REPO="/blue/bphl-puertorico/enavarromonserra/repos/Sanibel"

# ===== Shared container directories =====
export NXF_APPTAINER_CACHEDIR="/blue/bphl-puertorico/enavarromonserra/singularity/nextflow"
export NXF_SINGULARITY_CACHEDIR="$NXF_APPTAINER_CACHEDIR"

export APPTAINER_CACHEDIR="/blue/bphl-puertorico/enavarromonserra/singularity/apptainer"
export APPTAINER_TMPDIR="/blue/bphl-puertorico/enavarromonserra/singularity/tmp"

mkdir -p \
    "$NXF_APPTAINER_CACHEDIR" \
    "$APPTAINER_CACHEDIR" \
    "$APPTAINER_TMPDIR"

# ===== Activate Sanibel environment =====
conda activate SANIBEL

echo "Sanibel conda environment activated."

# ===== Validate repository files =====
if [[ ! -d "$SANIBEL_REPO" ]]; then
    echo "[ERROR] Sanibel repository not found:"
    echo "        $SANIBEL_REPO"
    exit 1
fi

if [[ ! -f "$SANIBEL_REPO/sanibel.nf" ]]; then
    echo "[ERROR] sanibel.nf not found:"
    echo "        $SANIBEL_REPO/sanibel.nf"
    exit 1
fi

if [[ ! -f "$SANIBEL_REPO/params.yaml" ]]; then
    echo "[ERROR] params.yaml not found:"
    echo "        $SANIBEL_REPO/params.yaml"
    exit 1
fi

cd "$SANIBEL_REPO"

echo "[INFO] Repository: $SANIBEL_REPO"
echo "[INFO] Parameters:"
cat params.yaml

# ===== Run Sanibel =====
nextflow run sanibel.nf \
    -profile apptainer \
    -params-file params.yaml 
#   -resume

echo "[INFO] Sanibel completed successfully."