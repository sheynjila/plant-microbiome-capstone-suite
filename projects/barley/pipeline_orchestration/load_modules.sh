###############################################################################
# load_modules.sh
#
# MUST BE SOURCED, NOT EXECUTED:
#   source pipeline_orchestration/load_modules.sh
# `module load` only changes environment variables (PATH, LD_LIBRARY_PATH,
# etc.) in whatever shell process runs it. If this script is executed as
# its own process (`bash load_modules.sh`), every change it makes vanishes
# the instant that process exits, and check_environment.sh / sbatch's
# --export=ALL (used by run_pipeline_from_yaml.sh) will never see them.
#
# WHY THIS EXISTS ALONSIDE activate_conda_env.sh IN THIS SAME DIRECTORY:
# This project's own environment/TOOLCHAIN.md documents a portable,
# cluster-agnostic assumption ("a pre-activated conda environment...
# rather than a module system"), and activate_conda_env.sh was built
# against that assumption first. But real evidence gathered on this exact
# account, on this exact cluster (teach-sub1), earlier in this curriculum
# (fixing PRJEB4927_Amplicon_Parkinsons_Gut_Microbiome) showed QIIME2 IS
# available there as a real Lmod module (QIIME2/2025.10-amplicon) -- so
# for teach-sub1 specifically, modules may be the more direct path for at
# least some of this project's tools, even though the project's own docs
# don't assume that. Try this script first; fall back to
# activate_conda_env.sh only for whatever this one's own
# check_environment.sh run still reports missing afterward.
#
# WHAT IS AND ISN'T CONFIRMED REAL HERE -- READ BEFORE TRUSTING THE PINS:
#   QIIME2  -> pinned "QIIME2/2025.10-amplicon": CONFIRMED real on
#              teach-sub1 (used to fix PRJEB4927 earlier this session).
#              Real `module spider QIIME2` on 2026-09 also lists
#              QIIME2/2023.7, QIIME2/2025.4-amplicon, QIIME2/2026.04.
#   FastQC  -> pinned "FastQC/0.12.1-Java-11": CONFIRMED real on
#              teach-sub1 (environment/TOOLCHAIN.md of the sibling
#              PRJNA983748_Saureus_Genome_Assembly repo, same cluster;
#              also directly reconfirmed via `module spider FastQC`).
#   MultiQC -> NO pinned version. Real `module spider MultiQC` on
#              2026-09 found two versions (1.20-foss-2023a,
#              1.28-foss-2024a) -- neither has been run against this
#              pipeline. Goes straight to discovery; see POLICY below
#              for what happens with more than one real match.
#   R       -> NO pinned version, same reason as MultiQC (provides
#              Rscript). Real `module spider R` on 2026-09 found six
#              versions (4.2.1 through 4.5.1, various toolchains) -- see
#              POLICY below. check_environment.sh independently verifies
#              the required R packages (phyloseq, ALDEx2, vegan, etc.)
#              are actually installed for whatever R this loads, so a
#              wrong pick surfaces there explicitly rather than silently.
#   biom    -> deliberately NOT a separate module entry. CONFIRMED (not
#              assumed) on teach-sub1: `module load QIIME2/2025.10-amplicon
#              && command -v biom` returned a real path
#              (/apps/eb/QIIME2/2025.10-amplicon/bin/biom) -- biom ships
#              bundled inside the QIIME2 module here.
#
# POLICY for 2+ real candidates found during discovery (no single
# confirmed-working version to fall back to): auto-select the highest
# version via `sort -V` (a real, version-aware sort -- NOT a plain
# lexicographic sort, which would misorder e.g. 4.10.x before 4.2.x) and
# load it, always with a loud, unmissable warning naming every candidate
# it did NOT pick. This is a deliberate choice, not the previous
# behavior (which refused and asked a human to choose) -- made because
# for MultiQC and R specifically, a wrong pick is not silent: MultiQC's
# own output would just look different, and any R-package mismatch is
# already caught explicitly by check_environment.sh's own separate
# package check. Zero real candidates still refuses outright -- there is
# nothing to auto-select from.
#
# GOTCHA THIS SCRIPT GUARDS AGAINST: module-name matching on some Lmod
# configs is loose enough to surface an unrelated same-named package (a
# real example hit elsewhere in this curriculum: the CRAN R package
# `cellranger` vs. the real 10x Genomics `CellRanger` software). Every
# candidate below is filtered to require the exact, case-sensitive module
# family name immediately before the "/", not a loose substring.
###############################################################################

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    echo "ERROR: this script must be SOURCED, not executed, or the modules it loads" >&2
    echo "       vanish the instant it exits. Run:" >&2
    echo "       source ${BASH_SOURCE[0]}" >&2
    exit 1
fi

if ! command -v module >/dev/null 2>&1; then
    echo "ERROR: 'module' is not a recognized shell function in this session." >&2
    echo "       This usually means Lmod's own init hasn't run in this shell" >&2
    echo "       (it normally does via your login profile) -- check with your" >&2
    echo "       cluster's documentation before continuing." >&2
    return 1
fi

# family:pinned_version -- pinned may be EMPTY, meaning "no confirmed
# version to try first, go straight to discovery" (see header above for
# exactly which entries that applies to and why).
_LM_TOOLS=(
    "QIIME2:QIIME2/2025.10-amplicon"
    "FastQC:FastQC/0.12.1-Java-11"
    "MultiQC:"
    "R:"
)

_LM_FAIL=0

for _entry in "${_LM_TOOLS[@]}"; do
    _family="${_entry%%:*}"
    _pinned="${_entry#*:}"

    if [ -n "${_pinned}" ]; then
        if module load "${_pinned}" 2>/dev/null; then
            echo "OK: loaded pinned ${_pinned}"
            continue
        fi
        echo "NOTE: pinned ${_pinned} not found on this cluster -- checking what IS available for ${_family}..."
    else
        echo "NOTE: no confirmed pinned version for ${_family} on this cluster -- discovering what's available..."
    fi

    _matches=$(module -t avail "${_family}" 2>&1 \
        | grep -E "^${_family}/" \
        | sed -E 's/\s*\(D\)\s*$//' \
        | sort -u)
    _n_matches=$(echo "${_matches}" | grep -c . || true)

    if [ "${_n_matches}" -eq 1 ]; then
        _fallback="${_matches}"
        if module load "${_fallback}" 2>/dev/null; then
            if [ -n "${_pinned}" ]; then
                echo "WARNING: loaded ${_fallback} instead of the pinned ${_pinned}."
                echo "         This version has NOT been verified against this pipeline --"
                echo "         a different version can change default parameters or output"
                echo "         file naming. Proceed, but watch this tool's output closely."
            else
                echo "OK: loaded ${_fallback} (discovered -- no pinned version existed to compare against)."
            fi
        else
            echo "MISSING: found exactly one candidate (${_fallback}) but 'module load' still" >&2
            echo "         failed for it -- inspect manually: module avail ${_family}" >&2
            _LM_FAIL=1
        fi
    elif [ "${_n_matches}" -gt 1 ]; then
        _latest=$(echo "${_matches}" | sort -V | tail -1)
        _others=$(echo "${_matches}" | grep -v -F -x "${_latest}")
        if module load "${_latest}" 2>/dev/null; then
            echo "WARNING: ${_family} has multiple real versions on this cluster -- auto-selected"
            echo "         the highest, ${_latest}, and loaded it. NOT verified against this"
            echo "         pipeline. Versions NOT selected:"
            echo "${_others}" | sed 's/^/           /'
            echo "         To pin a different one instead, set this entry's pinned value in"
            echo "         this script and re-source it."
        else
            echo "MISSING: auto-selected ${_latest} (highest of ${_n_matches} real candidates) but" >&2
            echo "         'module load' still failed for it -- inspect manually: module avail ${_family}" >&2
            _LM_FAIL=1
        fi
    else
        echo "MISSING: ${_family} -- not found under any version on this cluster." >&2
        echo "         Check 'module spider ${_family}' (not 'module avail' -- avail's matching" >&2
        echo "         can surface an unrelated same-named package) or ask your cluster admin." >&2
        _LM_FAIL=1
    fi
done

_LM_RESULT="${_LM_FAIL}"
unset _entry _family _pinned _matches _n_matches _fallback _latest _others _LM_TOOLS _LM_FAIL

if [ "${_LM_RESULT}" -eq 0 ]; then
    echo ""
    echo "=== All modules loaded. Proceed with: bash check_environment.sh ==="
    echo "(biom is confirmed bundled with the QIIME2 module -- no separate load needed.)"
else
    echo ""
    echo "=== One or more modules could not be loaded -- see MISSING lines above. ===" >&2
    echo "If any of these are genuinely unavailable as modules on this cluster, try:" >&2
    echo "  source activate_conda_env.sh" >&2
    echo "instead (or as well) -- it discovers a conda environment providing the same tools." >&2
fi

return "${_LM_RESULT}"
