#!/usr/bin/env bash
###############################################################################
# check_environment.sh
#
# NARRATIVE:
# This pipeline assumes a pre-activated environment (conda/QIIME2, R with
# the required packages) rather than a module system -- every project's
# own README says as much ("Site-specific module load commands are
# intentionally excluded because module names differ among clusters").
# That means the failure category most worth catching before submitting a
# real Slurm chain is different from a module-based cluster: not "wrong
# module version", but "a required CLI tool or R package silently isn't on
# PATH / installed in this environment", which would otherwise only
# surface many hours into the chain when a downstream step dies.
#
# Usage:
#   bash check_environment.sh
#
# Exits 0 if everything checked out, 1 otherwise -- safe to use as a gate:
#   bash check_environment.sh && bash run_pipeline_from_yaml.sh pipeline_config.yaml
###############################################################################
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

FAIL=0

echo "=== Checking config/project.env exists ==="
if [ -s "${PROJECT_ROOT}/config/project.env" ]; then
  echo "OK: config/project.env"
else
  echo "MISSING: config/project.env -- copy config/project.env.example and review it first."
  FAIL=1
fi
echo ""

echo "=== Checking required CLI tools are on PATH ==="
for tool in curl sha256sum md5sum awk qiime biom fastqc multiqc Rscript; do
  if command -v "${tool}" >/dev/null 2>&1; then
    echo "OK: ${tool}"
  else
    echo "MISSING: ${tool}"
    FAIL=1
  fi
done
echo ""

echo "=== Checking required R packages are installed ==="
REQUIRED_R_PACKAGES="phyloseq ALDEx2 vegan ggplot2 dplyr tibble biomformat"
for pkg in ${REQUIRED_R_PACKAGES}; do
  if Rscript -e "if (!requireNamespace('${pkg}', quietly = TRUE)) quit(status = 1)" >/dev/null 2>&1; then
    echo "OK: R package ${pkg}"
  else
    echo "MISSING: R package ${pkg} -- run analysis_metagenomics_phyloseq/00_install_packages.R first."
    FAIL=1
  fi
done
echo ""

echo "=== Checking config/assays.tsv reference artifacts exist ==="
if [ -s "${PROJECT_ROOT}/config/project.env" ]; then
  export PROJECT_ROOT
  # shellcheck disable=SC1091
  source "${PROJECT_ROOT}/config/project.env"
  while IFS=$'\t' read -r assay workflow layout forward reverse truncf truncr refseq reftax; do
    [ "${assay}" = "assay" ] && continue
    [ "${workflow}" = "amplicon" ] || continue
    refseq=${refseq//'$REFERENCE_ROOT'/${REFERENCE_ROOT}}
    reftax=${reftax//'$REFERENCE_ROOT'/${REFERENCE_ROOT}}
    for f in "${refseq}" "${reftax}"; do
      if [ -s "${f}" ]; then
        echo "OK: ${f}"
      else
        echo "MISSING: ${f} (see references/README.md)"
        FAIL=1
      fi
    done
  done < "${PROJECT_ROOT}/config/assays.tsv"
else
  echo "SKIPPED: config/project.env is missing (see above); cannot resolve reference paths yet."
fi
echo ""

if [ "${FAIL}" -eq 0 ]; then
  echo "=== ALL CHECKS PASSED -- safe to run: bash run_pipeline_from_yaml.sh pipeline_config.yaml ==="
  exit 0
else
  echo "=== ONE OR MORE CHECKS FAILED -- fix the items above before running the real chain. ===" >&2
  exit 1
fi
