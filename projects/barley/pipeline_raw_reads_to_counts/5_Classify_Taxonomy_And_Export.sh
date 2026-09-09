#!/usr/bin/env bash
#SBATCH --job-name=barley05_taxonomy
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
SCRIPT_DIR="${PIPELINE_SCRIPT_DIR:-${SLURM_SUBMIT_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)}}"
source "${SCRIPT_DIR}/lib/common.sh"
require_cmd qiime
require_cmd biom
# Real, confirmed gotcha on teach-sub1 (see Script 3's own comment for the
# full diagnosis): a PYTHONPATH left over from another module loaded
# alongside QIIME2 (FastQC/MultiQC/R, via load_modules.sh) leaks a
# python-version-mismatched numpy build into qiime's own bundled python.
unset PYTHONPATH
# Real, confirmed on teach-sub1 (see Script 3's own comment for the full
# diagnosis): qiime's internal PluginManager eagerly loads q2-composition
# (unused here), whose rpy2 dependency conflicts with our separately
# module-loaded R/4.5.1-gfbf-2025a. QIIME2 handles R internally on its
# own; this module is only needed for the later R/phyloseq stage.
module unload R 2>/dev/null || true
mkdir -p "${OUTPUT_DIR}/exported"

while IFS=$'\037' read -r assay workflow layout forward reverse truncf truncr refseq reftax; do
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
done < <(tr '\t' '\037' < "${PROJECT_ROOT}/config/assays.tsv")

record_versions
note "Feature counts and taxonomy are exported for R. Continue to Script 6."
