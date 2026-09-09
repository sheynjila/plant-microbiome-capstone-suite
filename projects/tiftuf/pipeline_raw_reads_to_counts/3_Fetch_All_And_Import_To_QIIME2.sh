#!/usr/bin/env bash
#SBATCH --job-name=tiftuf03_import
#SBATCH --partition=batch
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=4
#SBATCH --mem=12G
#SBATCH --time=08:00:00
###############################################################################
# 3_Fetch_All_And_Import_To_QIIME2.sh
#
# Downloads every included run, verifies the deposited MD5 checksum, and
# imports each amplicon assay into its own QIIME2 artifact. Shotgun reads are
# staged but never imported as amplicons.
###############################################################################
set -euo pipefail
SCRIPT_DIR="${PIPELINE_SCRIPT_DIR:-${SLURM_SUBMIT_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)}}"
source "${SCRIPT_DIR}/lib/common.sh"
require_cmd qiime
manifest="${PROJECT_ROOT}/data/run_manifest.tsv"
validate_reviewed_manifest "${manifest}"
mkdir -p "${OUTPUT_DIR}/qiime_artifacts"

tail -n +2 "${manifest}" | tr '\t' '\037' | while IFS=$'\037' read -r include assay run analysis_id sample layout strategy ftp md5 reads sample_title experiment_title; do
  [[ "${include}" == "YES" ]] || continue
  IFS=';' read -r -a urls <<< "${ftp}"
  IFS=';' read -r -a sums <<< "${md5}"
  [[ ${#urls[@]} -eq ${#sums[@]} ]] || die "FASTQ URL and MD5 counts differ for ${run}"
  [[ ${#urls[@]} -eq 2 ]] || die "Expected exactly two paired FASTQ files for ${run}; found ${#urls[@]}"
  for i in "${!urls[@]}"; do
    mate=$((i + 1))
    download_one "${urls[$i]}" "${sums[$i]}" "${RAW_DIR}/${analysis_id}_R${mate}.fastq.gz"
  done
done

while IFS=$'\037' read -r assay workflow layout forward reverse truncf truncr refseq reftax; do
  [[ "${assay}" == "assay" ]] && continue
  [[ "${workflow}" == "amplicon" ]] || continue
  qmanifest="${WORKDIR}/manifests/${assay}_qiime_manifest.csv"
  printf 'sample-id,forward-absolute-filepath,reverse-absolute-filepath\n' > "${qmanifest}"
  awk -F '\t' -v a="${assay}" 'NR>1 && $1=="YES" && $2==a {print $4}' "${manifest}" | while read -r analysis_id; do
    require_file "${RAW_DIR}/${analysis_id}_R1.fastq.gz"
    require_file "${RAW_DIR}/${analysis_id}_R2.fastq.gz"
    printf '%s,%s,%s\n' "${analysis_id}" "${RAW_DIR}/${analysis_id}_R1.fastq.gz" "${RAW_DIR}/${analysis_id}_R2.fastq.gz" >> "${qmanifest}"
  done
  qiime tools import --type 'SampleData[PairedEndSequencesWithQuality]' \
    --input-path "${qmanifest}" --input-format PairedEndFastqManifestPhred33V2 \
    --output-path "${OUTPUT_DIR}/qiime_artifacts/${assay}_demux.qza"
  qiime demux summarize --i-data "${OUTPUT_DIR}/qiime_artifacts/${assay}_demux.qza" \
    --o-visualization "${OUTPUT_DIR}/qiime_artifacts/${assay}_demux_summary.qzv"
done < <(tr '\t' '\037' < "${PROJECT_ROOT}/config/assays.tsv")
record_versions
note "All reviewed reads are verified; amplicon branches are imported. Continue to Script 4."
