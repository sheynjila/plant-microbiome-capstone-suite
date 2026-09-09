#!/usr/bin/env bash
#SBATCH --job-name=tomato06_qc
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
# Real, confirmed gotcha on teach-sub1 (see Script 3's own comment for the
# full diagnosis): a PYTHONPATH left over from another module loaded
# alongside QIIME2 (FastQC/MultiQC/R, via load_modules.sh) leaks a
# python-version-mismatched numpy build into qiime's own bundled python.
# Safe to clear here too, before the module-load'd multiqc call further
# below, since multiqc gets its own explicit Python module, not PYTHONPATH.
unset PYTHONPATH
# Real, confirmed on teach-sub1 (see Script 3's own comment for the full
# diagnosis): qiime's internal PluginManager eagerly loads q2-composition
# (unused here), whose rpy2 dependency conflicts with our separately
# module-loaded R/4.5.1-gfbf-2025a. QIIME2 handles R internally on its
# own; this module is only needed for the later R/phyloseq stage. Safe
# to unload here too, before the qiime calls below and well before the
# module-loaded multiqc call further down, which needs its own explicit
# Python module, not R.
module unload R 2>/dev/null || true
mkdir -p "${OUTPUT_DIR}/qc/final"

while IFS=$'\037' read -r assay workflow layout forward reverse truncf truncr refseq reftax; do
  [[ "${assay}" == "assay" ]] && continue
  [[ "${workflow}" == "amplicon" ]] || continue
  require_file "${OUTPUT_DIR}/qiime_artifacts/${assay}_feature_table.qza"
  qiime feature-table summarize \
    --i-table "${OUTPUT_DIR}/qiime_artifacts/${assay}_feature_table.qza" \
    --o-visualization "${OUTPUT_DIR}/qiime_artifacts/${assay}_feature_table_summary.qzv"
  qiime feature-table tabulate-seqs \
    --i-data "${OUTPUT_DIR}/qiime_artifacts/${assay}_rep_seqs.qza" \
    --o-visualization "${OUTPUT_DIR}/qiime_artifacts/${assay}_rep_seqs.qzv"
done < <(tr '\t' '\037' < "${PROJECT_ROOT}/config/assays.tsv")

# Real, confirmed gotcha on teach-sub1 (see Script 2's own comment for the
# full diagnosis): MultiQC's script needs its own matching Python
# explicitly loaded, or it fails on whatever QIIME2/R's conflicting
# Python left on PATH. Loaded here, after the qiime calls above already
# ran, so it can't affect those.
if command -v multiqc >/dev/null 2>&1; then
  module load Python/3.11.3-GCCcore-12.3.0
  # Real, confirmed gotcha: this MultiQC version (1.20-foss-2023a) exits
  # non-zero whenever it logs an internal error while building a report
  # (confirmed real cause: a plotly chart-config warning, "Bad property
  # path: autorangeoptions") -- even though it still finishes and writes
  # a complete, real report. Previously bare `|| true` here silently
  # swallowed this with no visible sign the report might need review;
  # now surfaced loudly instead.
  if ! multiqc --force --outdir "${OUTPUT_DIR}/qc/final" "${OUTPUT_DIR}"; then
    echo "WARNING: multiqc exited non-zero but still completed and wrote a report --" >&2
    echo "         inspect ${OUTPUT_DIR}/qc/final/multiqc_report.html yourself before" >&2
    echo "         trusting it; one chart may not have rendered as intended (see" >&2
    echo "         Script 2's header comment for the confirmed real cause)." >&2
  fi
fi
record_versions
find "${OUTPUT_DIR}/exported" -type f -print0 | sort -z | xargs -0 sha256sum \
  > "${OUTPUT_DIR}/provenance/exported_files.sha256"
cp "${PROJECT_ROOT}/data/run_manifest.tsv" "${OUTPUT_DIR}/provenance/run_manifest.tsv"
cp "${PROJECT_ROOT}/config/assays.tsv" "${OUTPUT_DIR}/provenance/assays.tsv"
note "QC gate: inspect every QZV and the final MultiQC report, reconcile sample counts, then run R Script 01."
