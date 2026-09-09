###############################################################################
# activate_conda_env.sh
#
# MUST BE SOURCED, NOT EXECUTED:
#   source pipeline_orchestration/activate_conda_env.sh
# `conda activate` only changes environment variables (PATH, CONDA_PREFIX,
# etc.) in whatever shell process runs it. If this script is executed as
# its own process (`bash activate_conda_env.sh`), the activation vanishes
# the instant that process exits, and check_environment.sh / sbatch's
# --export=ALL (used by run_pipeline_from_yaml.sh) will never see it.
#
# WHY THIS IS DIFFERENT FROM PRJNA983748_Saureus_Genome_Assembly's
# load_modules.sh (a different, Lmod-based repo in this curriculum):
# this project's own environment/TOOLCHAIN.md and check_environment.sh
# are explicit that it deliberately uses a pre-activated conda
# environment, not a module system -- "Site-specific module load
# commands are intentionally excluded because module names differ among
# clusters." There is also, disclosed rather than assumed: NO documented
# conda environment NAME anywhere in this repo (checked README.md,
# config/, environment/, pipeline_orchestration/README.md, and a
# whole-repo grep for "conda activate|conda create|conda env" -- none
# found). So unlike load_modules.sh's "try this exact pinned string
# first" design, there is no known-good name to pin here.
#
# WHAT THIS DOES INSTEAD -- capability-based discovery, not name matching:
# Lists every conda environment that exists on this account
# (`conda env list`), and for each one, checks whether it actually
# provides every command this project's own check_environment.sh
# requires (qiime, biom, fastqc, multiqc, Rscript -- see
# environment/TOOLCHAIN.md). An environment either has all of them or it
# doesn't; there's no "close enough" here.
#   - Exactly one qualifying environment found -> activates it.
#   - Zero found -> refuses, and prints which required command was
#     missing from each candidate environment it checked, so you can see
#     what's actually installed rather than getting a bare "not found".
#   - Two or more found -> refuses to guess which one you meant; lists
#     them and tells you how to pin your choice (see override below).
#
# OVERRIDE, so you don't pay the discovery cost every session once you
# know the answer:
#   export PLANT_MICROBIOME_CONDA_ENV=your-env-name
#   source pipeline_orchestration/activate_conda_env.sh
# skips discovery entirely and activates that name directly.
#
# DISCLOSED, NOT TESTED AGAINST A REAL CLUSTER: `conda run -n <env> ...`
# is used to probe each candidate environment without actually activating
# it first -- this is documented conda behavior, but has not been
# exercised against real conda environments in this development
# environment (no cluster/conda access here). If discovery behaves
# unexpectedly on the real cluster, paste the real `conda env list`
# output you see and this script gets corrected against real evidence.
###############################################################################

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    echo "ERROR: this script must be SOURCED, not executed, or the activation it does" >&2
    echo "       vanishes the instant it exits. Run:" >&2
    echo "       source ${BASH_SOURCE[0]}" >&2
    exit 1
fi

if ! command -v conda >/dev/null 2>&1; then
    echo "ERROR: 'conda' is not on PATH / not a recognized shell function in this session." >&2
    echo "       Check your cluster's documentation for how conda is normally initialized" >&2
    echo "       (often via 'module load Miniconda3' or sourcing a conda.sh script) before" >&2
    echo "       continuing." >&2
    return 1
fi

# This project's own required commands (environment/TOOLCHAIN.md, and the
# same list check_environment.sh checks). No shotgun classifiers needed
# for barley -- the sibling tomato/ project's copy of this script needs a
# longer list (fastp, bowtie2, kraken2, bracken) for its shotgun branch.
_ACE_REQUIRED_CMDS=(qiime biom fastqc multiqc Rscript)

if [ -n "${PLANT_MICROBIOME_CONDA_ENV:-}" ]; then
    echo "Using pinned override PLANT_MICROBIOME_CONDA_ENV=${PLANT_MICROBIOME_CONDA_ENV} -- skipping discovery."
    if conda activate "${PLANT_MICROBIOME_CONDA_ENV}" 2>/dev/null; then
        echo "OK: activated ${PLANT_MICROBIOME_CONDA_ENV}"
        return 0
    else
        echo "ERROR: 'conda activate ${PLANT_MICROBIOME_CONDA_ENV}' failed -- does that environment" >&2
        echo "       still exist? Check: conda env list" >&2
        return 1
    fi
fi

echo "No PLANT_MICROBIOME_CONDA_ENV override set -- discovering which conda environment(s)"
echo "actually provide everything this project needs: ${_ACE_REQUIRED_CMDS[*]}"
echo ""

# Real conda env names, one per line, skipping the header/comment lines
# and the "base" env's leading "*" marker.
mapfile -t _ACE_ENV_NAMES < <(conda env list 2>/dev/null | grep -vE '^\s*#' | grep -vE '^\s*$' | awk '{print $1}')

if [ "${#_ACE_ENV_NAMES[@]}" -eq 0 ]; then
    echo "ERROR: 'conda env list' returned no environments at all -- nothing to discover." >&2
    unset _ACE_REQUIRED_CMDS _ACE_ENV_NAMES
    return 1
fi

_ACE_QUALIFYING=()
declare -A _ACE_MISSING_FROM

for _env in "${_ACE_ENV_NAMES[@]}"; do
    _missing=""
    for _cmd in "${_ACE_REQUIRED_CMDS[@]}"; do
        if ! conda run -n "${_env}" bash -c "command -v ${_cmd}" >/dev/null 2>&1; then
            _missing="${_missing}${_missing:+, }${_cmd}"
        fi
    done
    if [ -z "${_missing}" ]; then
        _ACE_QUALIFYING+=("${_env}")
        echo "CANDIDATE: ${_env} -- has all required commands"
    else
        _ACE_MISSING_FROM["${_env}"]="${_missing}"
        echo "SKIPPING: ${_env} -- missing: ${_missing}"
    fi
done
echo ""

_ACE_RESULT=0

if [ "${#_ACE_QUALIFYING[@]}" -eq 1 ]; then
    _target="${_ACE_QUALIFYING[0]}"
    if conda activate "${_target}" 2>/dev/null; then
        echo "OK: activated ${_target} (the one environment providing everything this project needs)."
        echo "TIP: to skip this discovery next session, run:"
        echo "     export PLANT_MICROBIOME_CONDA_ENV=${_target}"
    else
        echo "ERROR: found exactly one qualifying environment (${_target}) but 'conda activate'" >&2
        echo "       still failed for it -- try it manually: conda activate ${_target}" >&2
        _ACE_RESULT=1
    fi
elif [ "${#_ACE_QUALIFYING[@]}" -gt 1 ]; then
    echo "ERROR: multiple environments qualify -- refusing to guess which one you meant:" >&2
    for _env in "${_ACE_QUALIFYING[@]}"; do
        echo "         ${_env}" >&2
    done
    echo "       Pick one and pin it: export PLANT_MICROBIOME_CONDA_ENV=<name>" >&2
    _ACE_RESULT=1
else
    echo "ERROR: no environment on this account provides everything this project needs" >&2
    echo "       (${_ACE_REQUIRED_CMDS[*]}). See the SKIPPING lines above for what each" >&2
    echo "       existing environment is missing -- install the gap into one of them, or" >&2
    echo "       create a new environment with all of it." >&2
    _ACE_RESULT=1
fi

unset _entry _env _cmd _missing _target _ACE_REQUIRED_CMDS _ACE_ENV_NAMES _ACE_QUALIFYING _ACE_MISSING_FROM
return "${_ACE_RESULT}"
