#!/usr/bin/env bash
#SBATCH --job-name=barley04_features
#SBATCH --partition=batch
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=8
#SBATCH --mem=32G
#SBATCH --time=16:00:00
###############################################################################
# 4_Primer_Trim_And_Infer_ASVs.sh
#
# Removes the published assay primers and runs DADA2 independently for each
# amplicon marker. Truncation defaults to zero; change it only after Script 2
# and the full demultiplex summaries show that quality trimming is needed.
###############################################################################
set -euo pipefail
SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
source "${SCRIPT_DIR}/lib/common.sh"
require_cmd qiime
mkdir -p "${OUTPUT_DIR}/qiime_artifacts"

while IFS=$'\t' read -r assay workflow layout forward reverse truncf truncr refseq reftax; do
  [[ "${assay}" == "assay" ]] && continue
  [[ "${workflow}" == "amplicon" ]] || continue
  require_file "${OUTPUT_DIR}/qiime_artifacts/${assay}_demux.qza"
  qiime cutadapt trim-paired \
    --i-demultiplexed-sequences "${OUTPUT_DIR}/qiime_artifacts/${assay}_demux.qza" \
    --p-front-f "${forward}" --p-front-r "${reverse}" --p-discard-untrimmed \
    --p-cores "${THREADS}" \
    --o-trimmed-sequences "${OUTPUT_DIR}/qiime_artifacts/${assay}_trimmed.qza"
  qiime demux summarize --i-data "${OUTPUT_DIR}/qiime_artifacts/${assay}_trimmed.qza" \
    --o-visualization "${OUTPUT_DIR}/qiime_artifacts/${assay}_trimmed_summary.qzv"
  qiime dada2 denoise-paired \
    --i-demultiplexed-seqs "${OUTPUT_DIR}/qiime_artifacts/${assay}_trimmed.qza" \
    --p-trunc-len-f "${truncf}" --p-trunc-len-r "${truncr}" \
    --p-n-threads "${DADA2_N_THREADS}" \
    --o-table "${OUTPUT_DIR}/qiime_artifacts/${assay}_feature_table.qza" \
    --o-representative-sequences "${OUTPUT_DIR}/qiime_artifacts/${assay}_rep_seqs.qza" \
    --o-denoising-stats "${OUTPUT_DIR}/qiime_artifacts/${assay}_denoising_stats.qza"
  qiime metadata tabulate --m-input-file "${OUTPUT_DIR}/qiime_artifacts/${assay}_denoising_stats.qza" \
    --o-visualization "${OUTPUT_DIR}/qiime_artifacts/${assay}_denoising_stats.qzv"
done < "${PROJECT_ROOT}/config/assays.tsv"

note "ASV inference and any study-specific read preprocessing are complete. Continue to Script 5."
