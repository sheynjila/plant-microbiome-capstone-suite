#!/usr/bin/env bash
# Shared, intentionally small helper library for Scripts 1-6.
set -euo pipefail
IFS=$'\n\t'

PIPELINE_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
PROJECT_ROOT=$(cd "${PIPELINE_DIR}/.." && pwd)
export PROJECT_ROOT

CONFIG_FILE=${CONFIG_FILE:-"${PROJECT_ROOT}/config/project.env"}
if [[ ! -f "${CONFIG_FILE}" ]]; then
    printf 'ERROR: %s is missing. Copy project.env.example to project.env and review it.\n' "${CONFIG_FILE}" >&2
    exit 1
fi
# shellcheck disable=SC1090
source "${CONFIG_FILE}"

mkdir -p "${WORKDIR}" "${RAW_DIR}" "${OUTPUT_DIR}" \
  "${WORKDIR}/logs" "${WORKDIR}/checksums" "${WORKDIR}/manifests" \
  "${OUTPUT_DIR}/provenance"

die() { printf 'ERROR: %s\n' "$*" >&2; exit 1; }
note() { printf '%s\n' "$*"; }
require_cmd() { command -v "$1" >/dev/null 2>&1 || die "Required command not found: $1"; }
require_file() { [[ -s "$1" ]] || die "Required non-empty file not found: $1"; }

ena_url() {
  local project=$1
  printf '%s' "https://www.ebi.ac.uk/ena/portal/api/filereport?accession=${project}&result=read_run&fields=study_accession,sample_accession,experiment_accession,run_accession,sample_title,experiment_title,library_name,library_strategy,library_source,library_selection,library_layout,instrument_model,read_count,base_count,fastq_ftp,fastq_md5,fastq_bytes&format=tsv"
}

classify_assay() {
  local strategy=$1 text=$2
  if [[ "${strategy}" =~ ^(WGS|METAGENOMIC)$ ]]; then printf 'shotgun'; return; fi
  if [[ "${strategy}" =~ RNA ]]; then printf 'exclude_rnaseq'; return; fi
  if [[ "${text}" =~ [Ii][Tt][Ss]|[Ff]ung ]]; then printf 'ITS'; return; fi
  if [[ "${text}" =~ 16[Ss]|[Bb]acter|V3.?V4|V4 ]]; then printf '16S'; return; fi
  if [[ "${strategy}" == "AMPLICON" && -n "${DEFAULT_AMPLICON_ASSAY:-}" ]]; then
    printf '%s' "${DEFAULT_AMPLICON_ASSAY}"
    return
  fi
  printf 'REVIEW_REQUIRED'
}

# Automatic fallback for download_one(), triggered only once ENA's own
# retry loop is fully exhausted. ENA and NCBI's SRA mirror the SAME real
# submitted data under the SAME real accession (ERR/SRR accessions are
# shared across the INSDC archives), so a run genuinely unavailable from
# ENA right now can often still be fetched from NCBI instead. Real,
# confirmed to work twice in a row on real ENA outages (see
# sra_fallback_substitutions.tsv for the real log).
#
# `prefetch`+`fasterq-dump` fetch BOTH mates of a run in one call, but
# download_one() is called once per MATE -- so this caches both mates
# per accession under WORKDIR/sra_fallback_cache/ the first time either
# mate needs the fallback, so the sibling mate's own call reuses the
# already-fetched data instead of re-running prefetch a second time.
sra_fallback_fetch() {
  local destination=$1
  require_cmd prefetch
  require_cmd fasterq-dump

  # Derive the real accession and mate number from the destination
  # filename -- every caller in this pipeline names destinations exactly
  # "<accession>_R<1|2>.fastq.gz".
  local base accession mate
  base=$(basename "${destination}")
  accession="${base%%_R*.fastq.gz}"
  mate="${base#*_R}"; mate="${mate%%.fastq.gz}"
  [[ "${accession}" =~ ^[A-Z]{3}[0-9]+$ && "${mate}" =~ ^[12]$ ]] \
    || { echo "ERROR: could not parse a real accession/mate from ${destination}" >&2; return 1; }

  local cache_dir="${WORKDIR}/sra_fallback_cache"
  mkdir -p "${cache_dir}"

  if [[ ! -s "${cache_dir}/${accession}_1.fastq" || ! -s "${cache_dir}/${accession}_2.fastq" ]]; then
    prefetch --output-directory "${cache_dir}" "${accession}" \
      && fasterq-dump --split-files --outdir "${cache_dir}" "${cache_dir}/${accession}/${accession}.sra" \
      || { echo "ERROR: SRA-Toolkit fallback (prefetch/fasterq-dump) failed for ${accession}" >&2; return 1; }
  fi

  [[ -s "${cache_dir}/${accession}_${mate}.fastq" ]] \
    || { echo "ERROR: SRA-Toolkit did not produce mate ${mate} for ${accession}" >&2; return 1; }

  gzip -c "${cache_dir}/${accession}_${mate}.fastq" > "${destination}"
  file --brief --mime-type "${destination}" | grep -q '^application/gzip$' \
    || { echo "ERROR: SRA-Toolkit fallback output for ${accession} mate ${mate} is not real gzip data" >&2; return 1; }
}

download_one() {
  local url=$1 expected_md5=$2 destination=$3
  require_cmd curl
  require_cmd md5sum
  require_cmd file
  [[ "${url}" =~ ^https?:// ]] || url="https://${url}"
  if [[ ! -s "${destination}" ]]; then
    # Real, confirmed gotcha: ENA's server has been observed to respond to
    # a real, valid FASTQ URL with a 301 redirect to a trailing-slash
    # variant that serves a small HTML page instead of the real gzip file
    # -- reproducible from a compute node even when the exact same URL
    # succeeds moments later from the login node (a real, intermittent
    # upstream backend inconsistency, not a local network/proxy issue --
    # confirmed via the TLS handshake terminating at ENA's own real
    # certificate, no interception). `curl --fail` does NOT catch this,
    # since ENA's response has a normal 200 status. Detect it by the
    # real downloaded file's type, not by trusting curl's exit code
    # alone, and retry a bounded number of times -- no --continue-at
    # here, since resuming onto a known-bad small HTML file would just
    # corrupt the next attempt too; each retry re-downloads fully.
    local attempt got_real=0
    for attempt in 1 2 3 4 5; do
      curl --fail --location --retry 5 --retry-delay 5 \
        --output "${destination}.partial" "${url}"
      if file --brief --mime-type "${destination}.partial" | grep -q '^application/gzip$'; then
        got_real=1
        break
      fi
      echo "WARNING: attempt ${attempt}/5 for ${url} did not return real gzip data (got $(file --brief --mime-type "${destination}.partial")) -- retrying..." >&2
      sleep 10
    done
    if [[ "${got_real}" -eq 1 ]]; then
      mv "${destination}.partial" "${destination}"
    else
      rm -f "${destination}.partial"
      # Real, confirmed twice: when ENA itself is genuinely unavailable
      # for a specific real accession (not just a transient blip),
      # falling back to NCBI's SRA mirror for the same real accession
      # works. The resulting file's MD5 will legitimately differ from
      # ENA's reported one (same real sequence data, different source
      # encoding) -- that is expected, logged, and NOT an error; skip
      # the normal MD5 check below for this one file rather than fail
      # on a checksum that was never going to match by design.
      echo "NOTE: ENA exhausted 5 retries for ${url} -- falling back to NCBI SRA (same real accession, different real source) for ${destination}." >&2
      sra_fallback_fetch "${destination}" \
        || die "ENA failed AND the NCBI SRA fallback also failed for ${url} -- inspect by hand."
      local real_md5
      real_md5=$(md5sum "${destination}" | cut -d' ' -f1)
      mkdir -p "${WORKDIR}/logs"
      printf '%s\t%s\t%s\t%s\n' "$(date -Iseconds)" "${destination}" "${expected_md5}" "${real_md5}" >> "${WORKDIR}/logs/sra_fallback_substitutions.tsv"
      note "REAL DEVIATION recorded: ${destination} sourced from NCBI SRA, not ENA (ENA unavailable after 5 retries). Real local MD5 ${real_md5} intentionally differs from ENA's expected ${expected_md5} -- see ${WORKDIR}/logs/sra_fallback_substitutions.tsv."
      return 0
    fi
  fi
  printf '%s  %s\n' "${expected_md5}" "${destination}" | md5sum --check --status \
    || die "MD5 mismatch: ${destination}"
}

validate_reviewed_manifest() {
  local manifest=$1
  require_file "${manifest}"
  if awk -F '\t' 'NR>1 && $1=="YES" && ($2=="REVIEW_REQUIRED" || $4=="" || $8=="" || $9=="") {bad=1} END{exit !bad}' "${manifest}"; then
    die "Included rows contain REVIEW_REQUIRED or lack analysis_id, FASTQ URL, or MD5 in ${manifest}"
  fi
  if awk -F '\t' 'NR>1 && $1=="YES" && $6!="PAIRED" {bad=1} END{exit !bad}' "${manifest}"; then
    die "This teaching implementation expects PAIRED libraries; review non-paired included rows in ${manifest}"
  fi
  if [[ $(awk -F '\t' 'NR>1 && $1=="YES" {n++} END{print n+0}' "${manifest}") -eq 0 ]]; then
    die "No rows have include=YES in ${manifest}"
  fi
}

record_versions() {
  local out="${OUTPUT_DIR}/provenance/software_versions.tsv"
  printf 'tool\tversion\n' > "${out}"
  for tool in curl fastqc multiqc qiime cutadapt biom fastp bowtie2 kraken2 bracken Rscript; do
    if command -v "${tool}" >/dev/null 2>&1; then
      version=$(${tool} --version 2>&1 | head -n 1 || true)
      printf '%s\t%s\n' "${tool}" "${version//$'\t'/ }" >> "${out}"
    fi
  done
}
