#!/usr/bin/env bash
#SBATCH --job-name=tiftuf02_fastqc
#SBATCH --partition=batch
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=2
#SBATCH --mem=4G
#SBATCH --time=00:30:00
###############################################################################
# 2_Interpret_FastQC_Diagnostics.sh
#
# Runs FastQC on the verified pilot and writes an interpretation worksheet.
# Primer trimming and DADA2 truncation values must follow these diagnostics
# and the required paired-read overlap; they must not be copied blindly.
###############################################################################
set -euo pipefail
SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
source "${SCRIPT_DIR}/lib/common.sh"
require_cmd fastqc
require_cmd multiqc
validate_reviewed_manifest "${PROJECT_ROOT}/data/run_manifest.tsv"

QC_DIR="${OUTPUT_DIR}/qc/pilot_raw"
mkdir -p "${QC_DIR}"
pilot_id=$(awk -F '\t' -v assay="${PILOT_ASSAY}" 'NR>1 && $1=="YES" && $2==assay {print $4; exit}' \
  "${PROJECT_ROOT}/data/run_manifest.tsv")
[[ -n "${pilot_id}" ]] || die "No reviewed pilot row for assay ${PILOT_ASSAY}"
pilot_files=("${RAW_DIR}/${pilot_id}_R1.fastq.gz" "${RAW_DIR}/${pilot_id}_R2.fastq.gz")
require_file "${pilot_files[0]}"; require_file "${pilot_files[1]}"
fastqc --threads 2 --extract --outdir "${QC_DIR}" "${pilot_files[@]}"
multiqc --force --outdir "${QC_DIR}" "${QC_DIR}"

worksheet="${QC_DIR}/FASTQC_INTERPRETATION.md"
printf '# Pilot FastQC interpretation\n\n' > "${worksheet}"
printf -- '- Study: TifTuf bermudagrass drought microbiome capstone\n- Pilot assay: %s\n- Files: %s\n\n' "${PILOT_ASSAY}" "${pilot_files[*]}" >> "${worksheet}"
printf 'Record the last high-quality position in each mate, expected amplicon length, retained overlap after trimming, adapter or primer evidence, and the final truncation decision. Keep ITS variable-length reads untruncated unless the observed quality requires otherwise.\n' >> "${worksheet}"
note "Inspect ${QC_DIR}/multiqc_report.html and complete ${worksheet} before Script 4."
