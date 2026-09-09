#!/usr/bin/env bash
#SBATCH --job-name=barley_ref_fetch
#SBATCH --partition=batch
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=8
#SBATCH --mem=64G
#SBATCH --time=12:00:00
###############################################################################
# 00_Fetch_Reference_Databases.sh
#
# Fetches the two real reference databases Script 5
# (5_Classify_Taxonomy_And_Export.sh) needs, using QIIME2's own RESCRIPT
# plugin against each database's real, canonical source -- matching
# exactly what the real study (Escudero-Martinez et al. 2022) used:
#   - SILVA 138, 99% OTUs (SSURef_NR99) for bacterial 16S taxonomy.
#   - UNITE 8.2 / 04.02.2020, fungi, 99% clustering for fungal ITS
#     taxonomy (confirmed real release date/version via UNITE's own
#     PlutoF DOI, 10.15156/BIO/786385).
#
# HARD PREREQUISITE, NOT YET INDEPENDENTLY CONFIRMED: this assumes the
# q2-rescript plugin is bundled in the loaded QIIME2 module
# (QIIME2/2025.10-amplicon on teach-sub1). Confirm with
# `qiime rescript --help` before trusting this script -- if that command
# errors ("no such command"), rescript needs installing separately
# (`pip install rescript` inside the QIIME2 environment, or an
# equivalent module) before this will work.
#
# WHY THIS NEEDS GENEROUS RESOURCES: get-silva-data downloads and
# dereplicates the FULL real SILVA SSU database from scratch, not just
# the 16S region -- genuinely large and memory-hungry. Run this once;
# the real artifacts it produces are reused for every future run of
# Script 5, no need to re-fetch.
#
# DISCLOSED: this script has been reviewed against QIIME2's own official
# RESCRIPT documentation (both commands come directly from
# docs.qiime2.org, not guessed), but has NOT been functionally executed
# in this development environment (no QIIME2/network access here) --
# treat the first real run on teach-sub1 with the same scrutiny as any
# other new script in this curriculum.
###############################################################################
set -euo pipefail
SCRIPT_DIR="${PIPELINE_SCRIPT_DIR:-${SLURM_SUBMIT_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)}}"
# shellcheck source=../pipeline_raw_reads_to_counts/lib/common.sh
source "${SCRIPT_DIR}/../pipeline_raw_reads_to_counts/lib/common.sh"
require_cmd qiime
require_cmd sha256sum
# Real, confirmed gotcha on teach-sub1 (see Script 3 in
# pipeline_raw_reads_to_counts for the full diagnosis): a PYTHONPATH left
# over from another module loaded alongside QIIME2 (FastQC/MultiQC/R, via
# load_modules.sh) leaks a python-version-mismatched numpy build into
# qiime's own bundled python.
unset PYTHONPATH

if ! qiime rescript --help >/dev/null 2>&1; then
  die "q2-rescript plugin not found in the loaded QIIME2 module -- see this script's own header for what to do next."
fi

REF_DIR="${PROJECT_ROOT}/references"
cd "${REF_DIR}"

if [[ -s silva-138-99-seqs.qza && -s silva-138-99-tax.qza ]]; then
  note "SILVA artifacts already present -- skipping re-fetch. Remove them first to force a fresh download."
else
  echo "=== Fetching real SILVA 138, 99% OTUs (SSURef_NR99) via RESCRIPT -- this downloads and parses the FULL real SILVA database, expect this to take a while ==="
  qiime rescript get-silva-data \
    --p-version '138' \
    --p-target 'SSURef_NR99' \
    --o-silva-sequences silva-138-99-seqs.qza \
    --o-silva-taxonomy silva-138-99-tax.qza
fi

if [[ -s unite-04.02.2020-seqs.qza && -s unite-04.02.2020-tax.qza ]]; then
  note "UNITE artifacts already present -- skipping re-fetch. Remove them first to force a fresh download."
else
  echo "=== Fetching real UNITE 8.2 (04.02.2020), fungi, 99% clustering via RESCRIPT ==="
  qiime rescript get-unite-data \
    --p-version '8.2' \
    --p-taxon-group 'fungi' \
    --p-cluster-id '99' \
    --o-sequences unite-04.02.2020-seqs.qza \
    --o-taxonomy unite-04.02.2020-tax.qza
fi

echo "=== Recording real provenance in reference_manifest.tsv (matching its existing real column schema) ==="
today=$(date -I)
{
  printf '%s\t%s\t%s\t%s\t%s\t%s\n' \
    "silva-138-99-seqs.qza" "SILVA 138, SSURef_NR99" \
    "qiime rescript get-silva-data --p-version 138 --p-target SSURef_NR99 (real ARB-SILVA source, fetched internally by RESCRIPT)" \
    "${today}" "$(sha256sum silva-138-99-seqs.qza | cut -d' ' -f1)" \
    "Bacterial 16S reference sequences"
  printf '%s\t%s\t%s\t%s\t%s\t%s\n' \
    "silva-138-99-tax.qza" "SILVA 138, SSURef_NR99" \
    "qiime rescript get-silva-data --p-version 138 --p-target SSURef_NR99 (real ARB-SILVA source, fetched internally by RESCRIPT)" \
    "${today}" "$(sha256sum silva-138-99-tax.qza | cut -d' ' -f1)" \
    "Bacterial 16S reference taxonomy"
  printf '%s\t%s\t%s\t%s\t%s\t%s\n' \
    "unite-04.02.2020-seqs.qza" "UNITE 8.2 (04.02.2020), fungi, 99%" \
    "qiime rescript get-unite-data --p-version 8.2 --p-taxon-group fungi --p-cluster-id 99 (real UNITE PlutoF REST API, DOI 10.15156/BIO/786385)" \
    "${today}" "$(sha256sum unite-04.02.2020-seqs.qza | cut -d' ' -f1)" \
    "Fungal ITS reference sequences"
  printf '%s\t%s\t%s\t%s\t%s\t%s\n' \
    "unite-04.02.2020-tax.qza" "UNITE 8.2 (04.02.2020), fungi, 99%" \
    "qiime rescript get-unite-data --p-version 8.2 --p-taxon-group fungi --p-cluster-id 99 (real UNITE PlutoF REST API, DOI 10.15156/BIO/786385)" \
    "${today}" "$(sha256sum unite-04.02.2020-tax.qza | cut -d' ' -f1)" \
    "Fungal ITS reference taxonomy"
} >> reference_manifest.tsv

note "Real reference artifacts fetched and recorded in reference_manifest.tsv. Ready for Script 5."
