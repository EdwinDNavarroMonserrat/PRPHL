#!/usr/bin/env bash
# Simple bash script to aggregate Freyja results
set -euo pipefail

INPUT_DIR="${1:-.}"
OUTPUT="${2:-aggregated-freyja.tsv}"

echo -e "\tsummarized\tlineages\tabundances\tresid\tcoverage" > "$OUTPUT"

for file in "$INPUT_DIR"/*.tsv; do
    [[ -e "$file" ]] || continue

    sample=$(basename "$file")
    sample="${sample/.variants.tsv/_variants.tsv}"

    summarized=$(awk -F'\t' '$1=="summarized"{print $2}' "$file")
    lineages=$(awk -F'\t' '$1=="lineages"{print $2}' "$file")
    abundances=$(awk -F'\t' '$1=="abundances"{print $2}' "$file")
    resid=$(awk -F'\t' '$1=="resid"{print $2}' "$file")
    coverage=$(awk -F'\t' '$1=="coverage"{print $2}' "$file")

    echo -e "${sample}\t${summarized}\t${lineages}\t${abundances}\t${resid}\t${coverage}" >> "$OUTPUT"
done

echo "Created: $OUTPUT"