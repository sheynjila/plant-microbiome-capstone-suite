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
#   FastQC  -> pinned "FastQC/0.12.1-Java-11": CONFIRMED real on
#              teach-sub1 (environment/TOOLCHAIN.md of the sibling
#              PRJNA983748_Saureus_Genome_Assembly repo, same cluster).
#   MultiQC -> NO pinned version. Not confirmed to exist as a module on
#              this cluster at all -- this entry goes straight to live
#              `module avail MultiQC` discovery every time, with no
#              "try this first" shortcut, specifically because there is
#              nothing confirmed to try.
#   R       -> NO pinned version, same reason as MultiQC (provides
#              Rscript). "R" is a very common real Lmod family name by
#              convention, but that is a naming convention, not a
#              confirmed fact about this specific cluster.
#   biom    -> deliberately NOT a separate entry here. biom-format
#              typically ships bundled inside a QIIME2 distribution
#              rather than as its own module -- an assumption, not a
#              confirmed fact. If `qiime biom fastqc multiqc Rscript`'s
#              own check_environment.sh reports biom missing after
#              QIIME2 loads cleanly, that assumption was wrong and this
#              script needs a real "BIOM" entry added, based on that
#              evidence.
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
        echo "MISSING: ${_family} -- multiple versions found, refusing to guess which one:" >&2
        echo "${_matches}" | sed 's/^/         /' >&2
        echo "         Pick one, edit this script's pinned entry for ${_family}, and re-source it." >&2
        _LM_FAIL=1
    else
        echo "MISSING: ${_family} -- not found under any version on this cluster." >&2
        echo "         Check 'module spider ${_family}' (not 'module avail' -- avail's matching" >&2
        echo "         can surface an unrelated same-named package) or ask your cluster admin." >&2
        _LM_FAIL=1
    fi
done

_LM_RESULT="${_LM_FAIL}"
unset _entry _family _pinned _matches _n_matches _fallback _LM_TOOLS _LM_FAIL

if [ "${_LM_RESULT}" -eq 0 ]; then
    echo ""
    echo "=== All modules loaded. Proceed with: bash check_environment.sh ==="
    echo "(If check_environment.sh still reports 'biom' missing, this project's assumption"
    echo " that biom ships bundled with QIIME2 was wrong on this cluster -- report that and"
    echo " a real BIOM module entry gets added here based on the evidence.)"
else
    echo ""
    echo "=== One or more modules could not be loaded -- see MISSING lines above. ===" >&2
    echo "If any of these are genuinely unavailable as modules on this cluster, try:" >&2
    echo "  source activate_conda_env.sh" >&2
    echo "instead (or as well) -- it discovers a conda environment providing the same tools." >&2
fi

return "${_LM_RESULT}"
