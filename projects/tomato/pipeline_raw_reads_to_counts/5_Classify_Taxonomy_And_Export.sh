#!/usr/bin/env bash
#SBATCH --job-name=tomato05_taxonomy
#SBATCH --partition=batch
#SBATCH --ntasks=1
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

# Shotgun branch: only mandatory when the cohort actually includes shotgun
# runs (see the matching guard and comment in Script 4).
if awk -F '\t' 'NR>1 && $1=="YES" && $2=="shotgun" {found=1} END{exit !found}' "${PROJECT_ROOT}/data/run_manifest.tsv"; then
  require_cmd kraken2
  require_cmd bracken
  require_cmd python3
  [[ -s "${KRAKEN2_DB}/hash.k2d" ]] || die "Kraken2 database not found: ${KRAKEN2_DB}"
  mkdir -p "${OUTPUT_DIR}/shotgun/kraken" "${OUTPUT_DIR}/shotgun/bracken"
  awk -F '\t' 'NR>1 && $1=="YES" && $2=="shotgun" {print $4}' "${PROJECT_ROOT}/data/run_manifest.tsv" | while read -r analysis_id; do
    r1="${OUTPUT_DIR}/shotgun/host_removed/${analysis_id}_R1.fastq.gz"
    r2="${OUTPUT_DIR}/shotgun/host_removed/${analysis_id}_R2.fastq.gz"
    require_file "${r1}"; require_file "${r2}"
    kraken2 --db "${KRAKEN2_DB}" --threads "${THREADS}" --paired --gzip-compressed \
      --report "${OUTPUT_DIR}/shotgun/kraken/${analysis_id}.report" \
      --output "${OUTPUT_DIR}/shotgun/kraken/${analysis_id}.classifications" "${r1}" "${r2}"
    bracken -d "${KRAKEN2_DB}" -i "${OUTPUT_DIR}/shotgun/kraken/${analysis_id}.report" \
      -o "${OUTPUT_DIR}/shotgun/bracken/${analysis_id}.species.tsv" \
      -r "${BRACKEN_READ_LENGTH}" -l S
  done
  # merge_bracken.py reads the raw Kraken2 .report files (not just Bracken's
  # species.tsv) so it can derive each taxon's real domain from the report's
  # own rank-code hierarchy, instead of assuming every hit is Bacteria -- a
  # kraken2 database is never guaranteed to be bacteria-only (see
  # references/README.md).
  python3 "${SCRIPT_DIR}/utils/merge_bracken.py" \
    --input-dir "${OUTPUT_DIR}/shotgun/bracken" \
    --kraken-dir "${OUTPUT_DIR}/shotgun/kraken" \
    --counts "${OUTPUT_DIR}/exported/shotgun/feature_counts.tsv" \
    --taxonomy "${OUTPUT_DIR}/exported/shotgun/taxonomy.tsv"
else
  note "No shotgun runs included in this cohort. Skipping Kraken2/Bracken classification."
fi
record_versions
note "Feature counts and taxonomy are exported for R. Continue to Script 6."
