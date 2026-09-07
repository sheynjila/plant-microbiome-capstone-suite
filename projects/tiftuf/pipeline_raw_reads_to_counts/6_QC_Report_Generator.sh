#!/usr/bin/env bash
#SBATCH --job-name=tiftuf06_qc
#SBATCH --partition=batch
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=2
#SBATCH --mem=8G
#SBATCH --time=02:00:00
###############################################################################
# 6_QC_Report_Generator.sh
#
# Produces QIIME2 feature-table summaries, consolidates MultiQC inputs, and
# hashes exported deliverables. Review this report before beginning R.
###############################################################################
set -euo pipefail
SCRIPT_DIR="${PIPELINE_SCRIPT_DIR:-${SLURM_SUBMIT_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)}}"
source "${SCRIPT_DIR}/lib/common.sh"
require_cmd qiime
require_cmd sha256sum
mkdir -p "${OUTPUT_DIR}/qc/final"

while IFS=$'\t' read -r assay workflow layout forward reverse truncf truncr refseq reftax; do
  [[ "${assay}" == "assay" ]] && continue
  [[ "${workflow}" == "amplicon" ]] || continue
  require_file "${OUTPUT_DIR}/qiime_artifacts/${assay}_feature_table.qza"
  qiime feature-table summarize \
    --i-table "${OUTPUT_DIR}/qiime_artifacts/${assay}_feature_table.qza" \
    --o-visualization "${OUTPUT_DIR}/qiime_artifacts/${assay}_feature_table_summary.qzv"
  qiime feature-table tabulate-seqs \
    --i-data "${OUTPUT_DIR}/qiime_artifacts/${assay}_rep_seqs.qza" \
    --o-visualization "${OUTPUT_DIR}/qiime_artifacts/${assay}_rep_seqs.qzv"
done < "${PROJECT_ROOT}/config/assays.tsv"

if command -v multiqc >/dev/null 2>&1; then
  multiqc --force --outdir "${OUTPUT_DIR}/qc/final" "${OUTPUT_DIR}" || true
fi
record_versions
find "${OUTPUT_DIR}/exported" -type f -print0 | sort -z | xargs -0 sha256sum \
  > "${OUTPUT_DIR}/provenance/exported_files.sha256"
cp "${PROJECT_ROOT}/data/run_manifest.tsv" "${OUTPUT_DIR}/provenance/run_manifest.tsv"
cp "${PROJECT_ROOT}/config/assays.tsv" "${OUTPUT_DIR}/provenance/assays.tsv"
note "QC gate: inspect every QZV and the final MultiQC report, reconcile sample counts, then run R Script 01."
