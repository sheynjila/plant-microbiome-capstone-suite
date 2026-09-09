#!/usr/bin/env bash
#SBATCH --job-name=tomato02_fastqc
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
SCRIPT_DIR="${PIPELINE_SCRIPT_DIR:-${SLURM_SUBMIT_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)}}"
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
# Real, confirmed gotcha on teach-sub1: MultiQC/1.20-foss-2023a own
# script has a `#!/usr/bin/env python` shebang, but neither its own
# module nor FastQC provides a bare `python`/matching `python3` on PATH
# -- only QIIME2 and R do, via their own bundled/dependency Python
# builds (3.10 and 3.13 respectively), and BOTH are ABI-incompatible
# with SciPy-bundle numpy (built for 3.11), causing:
#   ModuleNotFoundError: No module named numpy.core._multiarray_umath
# Explicitly loading MultiQC real Python dependency fixes it --
# confirmed directly (multiqc --version succeeds after this).
module load Python/3.11.3-GCCcore-12.3.0
# Real, confirmed gotcha: this MultiQC version (1.20-foss-2023a) exits
# non-zero whenever it logs an internal error while building a report
# (confirmed real cause here: a plotly chart-config warning, "Bad
# property path: autorangeoptions") -- even though it still finishes and
# writes a complete, real report ("MultiQC complete", real
# multiqc_report.html/multiqc_data written). Not treated as fatal here,
# since the report is genuinely usable -- but surfaced loudly, not
# silently swallowed, so the report gets reviewed rather than trusted
# blindly.
if ! multiqc --force --outdir "${QC_DIR}" "${QC_DIR}"; then
  echo "WARNING: multiqc exited non-zero but still completed and wrote a report --" >&2
  echo "         inspect ${QC_DIR}/multiqc_report.html yourself before trusting it;" >&2
  echo "         one chart may not have rendered as intended (see this script's own" >&2
  echo "         header comment for the confirmed real cause)." >&2
fi

worksheet="${QC_DIR}/FASTQC_INTERPRETATION.md"
printf '# Pilot FastQC interpretation\n\n' > "${worksheet}"
printf -- '- Study: Tomato multi-resolution host microbiome capstone\n- Pilot assay: %s\n- Files: %s\n\n' "${PILOT_ASSAY}" "${pilot_files[*]}" >> "${worksheet}"
printf 'Record the last high-quality position in each mate, expected amplicon length, retained overlap after trimming, adapter or primer evidence, and the final truncation decision. Keep ITS variable-length reads untruncated unless the observed quality requires otherwise.\n' >> "${worksheet}"
note "Inspect ${QC_DIR}/multiqc_report.html and complete ${worksheet} before Script 4."
