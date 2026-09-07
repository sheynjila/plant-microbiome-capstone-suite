#!/usr/bin/env bash
#SBATCH --job-name=tiftuf05_taxonomy
#SBATCH --partition=batch
#SBATCH --cpus-per-task=8
#SBATCH --mem=48G
#SBATCH --time=12:00:00
###############################################################################
# 5_Classify_Taxonomy_And_Export.sh
#
# Assigns taxonomy against explicitly named reference artifacts and exports
# count, taxonomy, and representative-sequence files for R. Classification
# databases are inputs whose versions and checksums belong in provenance.
###############################################################################
set -euo pipefail
SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
source "${SCRIPT_DIR}/lib/common.sh"
require_cmd qiime
require_cmd biom
mkdir -p "${OUTPUT_DIR}/exported"

while IFS=$'\t' read -r assay workflow layout forward reverse truncf truncr refseq reftax; do
  [[ "${assay}" == "assay" ]] && continue
  [[ "${workflow}" == "amplicon" ]] || continue
  refseq=${refseq//'$REFERENCE_ROOT'/${REFERENCE_ROOT}}
  reftax=${reftax//'$REFERENCE_ROOT'/${REFERENCE_ROOT}}
  require_file "${refseq}"; require_file "${reftax}"
  require_file "${OUTPUT_DIR}/qiime_artifacts/${assay}_feature_table.qza"
  qiime feature-classifier classify-consensus-vsearch \
    --i-query "${OUTPUT_DIR}/qiime_artifacts/${assay}_rep_seqs.qza" \
    --i-reference-reads "${refseq}" --i-reference-taxonomy "${reftax}" \
    --p-threads "${THREADS}" \
    --o-classification "${OUTPUT_DIR}/qiime_artifacts/${assay}_taxonomy.qza" \
    --o-search-results "${OUTPUT_DIR}/qiime_artifacts/${assay}_taxonomy_hits.qza"
  out="${OUTPUT_DIR}/exported/${assay}"
  mkdir -p "${out}/feature_table" "${out}/taxonomy" "${out}/rep_seqs"
  qiime tools export --input-path "${OUTPUT_DIR}/qiime_artifacts/${assay}_feature_table.qza" --output-path "${out}/feature_table"
  qiime tools export --input-path "${OUTPUT_DIR}/qiime_artifacts/${assay}_taxonomy.qza" --output-path "${out}/taxonomy"
  qiime tools export --input-path "${OUTPUT_DIR}/qiime_artifacts/${assay}_rep_seqs.qza" --output-path "${out}/rep_seqs"
  biom add-metadata -i "${out}/feature_table/feature-table.biom" \
    -o "${out}/feature_table/feature-table-with-taxonomy.biom" \
    --observation-metadata-fp "${out}/taxonomy/taxonomy.tsv" \
    --sc-separated taxonomy --observation-header-fields 'Feature ID,taxonomy,Confidence'
done < "${PROJECT_ROOT}/config/assays.tsv"

record_versions
note "Feature counts and taxonomy are exported for R. Continue to Script 6."
