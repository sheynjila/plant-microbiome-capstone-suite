# Pipeline Orchestration: YAML-Driven Bash + R Slurm Chain

Runs Scripts 1 through 6 (`pipeline_raw_reads_to_counts/`) and the R
analysis (`analysis_metagenomics_phyloseq/run_analysis.R`) as one real,
unattended, 7-step Slurm job chain, instead of submitting each bash step
by hand and then separately running R yourself. This uses **Slurm's own
native job dependency mechanism** (`--dependency=afterok:<jobid>`) — no
external workflow-manager software (Snakemake, Nextflow, etc.) is
installed or required.

## Quick start

```bash
cd pipeline_orchestration
source activate_conda_env.sh
bash check_environment.sh && bash run_pipeline_from_yaml.sh pipeline_config.yaml
```

That's it — this returns immediately after submitting all 7 jobs. Slurm's
scheduler runs each one in turn, only starting step *N+1* once step *N*
has actually exited successfully.

**`activate_conda_env.sh` must be *sourced* (`source ...`, not `bash ...`)** — `conda activate` doesn't persist across a new login shell, and only changes the environment of whatever process runs it. Since no conda environment *name* is documented anywhere in this project (checked deliberately — see the script's own header), it discovers by capability instead of by name: it checks every environment on your account for whichever one actually provides `qiime`, `biom`, `fastqc`, `multiqc`, and `Rscript`, and activates it only if exactly one qualifies. Once you know which environment that is, skip the discovery cost on future sessions with `export PLANT_MICROBIOME_CONDA_ENV=<name>` before sourcing it.

## No script duplication, no directory-isolation trick

Unlike orchestrated repos elsewhere in this curriculum, this project
needs neither separate "orchestrator-only" copies of the pipeline scripts
nor a `RUN_TAG`-suffixed working directory. Both were necessary there
because paths were hardcoded per-script; here, every path (`WORKDIR`,
`RAW_DIR`, `OUTPUT_DIR`, `REFERENCE_ROOT`) is read once from
`config/project.env`, so this orchestrator simply re-runs
[`../pipeline_raw_reads_to_counts/`](../pipeline_raw_reads_to_counts/)
and [`../analysis_metagenomics_phyloseq/`](../analysis_metagenomics_phyloseq/)
completely untouched, against your own `config/project.env` — the exact
same scripts and configuration a manual, step-by-step run would use.

This is safe to do unattended because the pipeline already protects
itself in the ways that mattered for a real collision elsewhere in this
curriculum:

- `download_one()` (in `lib/common.sh`) skips re-downloading a file that
  already exists and still re-verifies its checksum — re-running Script 1
  or 3 does not re-fetch or corrupt anything already fetched.
- Script 1 **refuses** to regenerate `data/run_manifest.tsv` if it
  already exists (see its own guard and `FORCE_REGENERATE_MANIFEST=1`
  escape hatch) — the human review step this project's whole
  reproducibility model depends on can never be silently discarded by
  re-running the chain.
- `RESULTS_DIR` (R's output) and `OUTPUT_DIR` (bash's output) are simply
  regenerated on each full run — there is no expensive, hours-long
  intermediate step whose loss would be costly, unlike a multi-hour STAR
  genome index elsewhere in this curriculum.

**If `data/run_manifest.tsv` has already been reviewed by hand** (the
normal case — see the main [README](../README.md)'s "Start here"), Step 1
will refuse to run. Start the chain from Step 2 instead:

```bash
bash run_pipeline_from_yaml.sh pipeline_config.yaml --start-from 2
```

## Chaining a bash pipeline with a plain R script

`run_analysis.R` has no `#SBATCH` header of its own (it's designed to be
run directly with `Rscript`), and it lives in a different folder from the
bash scripts. `pipeline_config.yaml`'s step 7 uses three fields the bash
steps don't need:

```yaml
- {id: 7, script: run_analysis.R, mode: sbatch_wrap, dir: ../analysis_metagenomics_phyloseq, wrap_cmd: Rscript, wrap_cpus: 4, wrap_mem: 16G, wrap_time: 04:00:00}
```

- `dir` — overrides `scripts_dir` for just this step, so the driver looks
  in `analysis_metagenomics_phyloseq/` instead of `pipeline_raw_reads_to_counts/`.
- `wrap_cmd` — the interpreter to run the script with (`Rscript` instead
  of the default `bash`).
- `wrap_cpus` / `wrap_mem` / `wrap_time` — this step's own resource
  request, since phyloseq loading, ALDEx2's CLR Monte Carlo, and dashboard
  rendering need more than the driver's lightweight 1 CPU / 2G / 10-minute
  default for a wrapped step. Adjust these for your dataset's real size.

This project's own scripts never hardcode `--partition` (see the main
README: site-specific `module load` commands are intentionally excluded
because they differ across clusters — the same reasoning applies to
partitions), so `mode: sbatch_wrap` does not add one by default either.
Add an optional `wrap_partition: <name>` field to a step only if your
cluster's default partition can't be relied on.

## Preflight check (`check_environment.sh`)

This pipeline assumes a pre-activated environment (conda/QIIME2, R with
the required packages) rather than a module system, so the failure
category most worth catching in advance is different from a module-based
cluster: a required CLI tool or R package silently missing from PATH,
rather than a wrong module version. `check_environment.sh` checks:

- `config/project.env` exists,
- `curl`, `sha256sum`, `md5sum`, `awk`, `qiime`, `biom`, `fastqc`,
  `multiqc`, and `Rscript` are on PATH,
- the required R packages (`phyloseq`, `ALDEx2`, `vegan`, `ggplot2`,
  `dplyr`, `tibble`, `biomformat`) are installed,
- every reference artifact named in `config/assays.tsv` actually exists.

```bash
bash check_environment.sh
```

Exits 0 only if every check passes, so it's safe to chain directly in
front of the real run, as shown in Quick start. It can tell you a
required tool is missing from `PATH` but can't activate the environment
that provides it — that's what `source activate_conda_env.sh` (above) is
for; run it first.

## Monitoring progress

```bash
squeue -u $(whoami)
```

A step waiting on its dependency shows `(Dependency)` as its reason.

## If a step fails

Slurm's `afterok` dependency means: if step *N* exits non-zero, every
step after it is left in a `DependencyNeverSatisfied` state and **never
runs**. Find out exactly which step failed and why:

```bash
sacct -u $(whoami) --format=JobID,JobName%20,State,ExitCode,Start,End
```

Fix whatever caused it, then resume from that exact step instead of
re-running the whole chain:

```bash
bash run_pipeline_from_yaml.sh pipeline_config.yaml --start-from 5
```

## Editing the pipeline

`pipeline_config.yaml`'s `steps:` list is deliberately written as
one-line YAML flow mappings (`- {id: N, script: ..., mode: ...}`) so it
can be parsed reliably with plain `grep`/`sed` — no `PyYAML` or `yq`
installation required. It's still fully valid YAML; verify it any time
with:

```bash
python3 -c "import yaml; print(yaml.safe_load(open('pipeline_config.yaml')))"
```
