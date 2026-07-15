#!/usr/bin/env bash
# Written by Edwin Daniel Navarro Monserrat
# Simple bash script to create a samplesheet for CDC aquascope pipeline

set -euo pipefail

READ_DIR="$1"
BEDFILE="$2"
OUTPUT="${3:-samplesheet.csv}"

echo "sample,platform,fastq_1,fastq_2,lr,bam_file,bedfile" > "$OUTPUT"

for r1 in "$READ_DIR"/*_R1*.fastq.gz; do
    [[ -e "$r1" ]] || continue

    r2="${r1/_R1/_R2}"

    if [[ ! -f "$r2" ]]; then
        echo "Missing mate for $r1"
        continue
    fi

    sample=$(basename "$r1")
    sample=${sample%%_R1*}

    echo "${sample},illumina,$r1,$r2,,,$BEDFILE" >> "$OUTPUT"
done

echo "Created $OUTPUT"