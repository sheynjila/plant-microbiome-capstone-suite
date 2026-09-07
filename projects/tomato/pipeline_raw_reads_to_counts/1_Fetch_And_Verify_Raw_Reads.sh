#!/usr/bin/env bash
#SBATCH --job-name=tomato01_fetch
#SBATCH --partition=batch
#SBATCH --cpus-per-task=2
#SBATCH --mem=4G
#SBATCH --time=01:00:00
###############################################################################
# 1_Fetch_And_Verify_Raw_Reads.sh
#
# Fetches the ENA run report, creates an auditable review manifest, and
# downloads exactly one pilot run after the assay label has been reviewed.
# The manifest is the control point: biological groups are never inferred
# from file order. BioProjects: PRJNA787039 PRJNA789467.
###############################################################################
set -euo pipefail
SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=lib/common.sh
source "${SCRIPT_DIR}/lib/common.sh"
require_cmd awk
require_cmd sha256sum

REPORT="${PROJECT_ROOT}/data/ena_run_report.tsv"
MANIFEST="${PROJECT_ROOT}/data/run_manifest.tsv"
mkdir -p "${PROJECT_ROOT}/data"

tmp_report="${WORKDIR}/ena_run_report.tsv"
first=1
for project in "${BIOPROJECTS[@]}"; do
  part="${WORKDIR}/${project}_ena.tsv"
  curl --fail --location --retry 5 "$(ena_url "${project}")" --output "${part}"
  require_file "${part}"
  if [[ $first -eq 1 ]]; then
    cp "${part}" "${tmp_report}"
    first=0
  else
    tail -n +2 "${part}" >> "${tmp_report}"
  fi
done
cp "${tmp_report}" "${REPORT}"
sha256sum "${REPORT}" > "${REPORT}.sha256"

expected_header=$'run_accession\tstudy_accession\tsample_accession\texperiment_accession\tsample_title\texperiment_title\tlibrary_name\tlibrary_strategy\tlibrary_source\tlibrary_selection\tlibrary_layout\tinstrument_model\tread_count\tbase_count\tfastq_ftp\tfastq_md5\tfastq_bytes'
observed_header=$(head -n 1 "${REPORT}" | tr -d '\r')
[[ "${observed_header}" == "${expected_header}" ]] \
  || die "ENA run-report columns changed; update the header-aware parser before continuing"

# Script 3 reads this same file after a human has hand-reviewed and edited
# it (see the README's documented sequence). Re-running Script 1 must never
# silently discard that review -- regenerating from scratch requires an
# explicit, deliberate opt-in.
if [[ -s "${MANIFEST}" && "${FORCE_REGENERATE_MANIFEST:-0}" != "1" ]]; then
  die "${MANIFEST} already exists. It may contain reviewed include/assay decisions. \
Move or rename it first, or re-run with FORCE_REGENERATE_MANIFEST=1 to overwrite it deliberately."
fi

printf 'include\tassay\trun_accession\tanalysis_id\tsample_accession\tlibrary_layout\tlibrary_strategy\tfastq_ftp\tfastq_md5\tread_count\tsample_title\texperiment_title\n' > "${MANIFEST}"
tail -n +2 "${REPORT}" | while IFS=$'\t' read -r run study sample experiment sample_title experiment_title library_name strategy source selection layout instrument reads bases ftp md5 bytes; do
  assay=$(classify_assay "${strategy}" "${sample_title} ${experiment_title} ${library_name}")
  include=NO
  [[ "${assay}" == "16S" || "${assay}" == "ITS" || "${assay}" == "shotgun" ]] && include=YES
  [[ "${assay}" == "REVIEW_REQUIRED" || "${assay}" == "exclude_rnaseq" ]] && include=NO
  printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
    "${include}" "${assay}" "${run}" "${run}" "${sample}" "${layout}" \
    "${strategy}" "${ftp}" "${md5}" "${reads}" "${sample_title}" "${experiment_title}" >> "${MANIFEST}"
done

note "Created ${MANIFEST}. Review every include, assay, and analysis_id value."
validate_reviewed_manifest "${MANIFEST}"

pilot=$(awk -F '\t' -v assay="${PILOT_ASSAY}" 'NR>1 && $1=="YES" && $2==assay {print; exit}' "${MANIFEST}")
[[ -n "${pilot}" ]] || die "No reviewed pilot row for assay ${PILOT_ASSAY}"
IFS=$'\t' read -r include assay run analysis_id sample layout strategy ftp md5 reads sample_title experiment_title <<< "${pilot}"
IFS=';' read -r -a urls <<< "${ftp}"
IFS=';' read -r -a sums <<< "${md5}"
[[ ${#urls[@]} -eq ${#sums[@]} ]] || die "FASTQ URL and MD5 counts differ for ${run}"
[[ ${#urls[@]} -eq 2 ]] || die "Expected exactly two paired FASTQ files for ${run}; found ${#urls[@]}"
for i in "${!urls[@]}"; do
  mate=$((i + 1))
  destination="${RAW_DIR}/${analysis_id}_R${mate}.fastq.gz"
  download_one "${urls[$i]}" "${sums[$i]}" "${destination}"
done
note "Pilot ${run} downloaded and verified. Continue to Script 2."
