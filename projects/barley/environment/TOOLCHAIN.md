# Toolchain contract

The shell scripts target the stable QIIME 2 command interfaces used by the supplied teaching skeleton and verify commands at runtime. Use one documented Linux environment and capture actual versions with Script 6. The minimum interfaces are QIIME 2 with q2-cutadapt, q2-dada2, q2-feature-classifier, q2-demux, and q2-feature-table; FastQC; MultiQC; BIOM; curl; and GNU checksum tools.

No shotgun classifiers are required for this project.

R Script 00 creates or restores `renv.lock`. Commit that lockfile after the first supervised installation. Keep reference databases and per-user package caches outside Git.

No conda environment name is pinned anywhere in this project deliberately — `pipeline_orchestration/activate_conda_env.sh` discovers which of your existing conda environments actually provides everything above (by capability, not by name) and activates it; run `source pipeline_orchestration/activate_conda_env.sh` each session before `check_environment.sh`.

**Real, cluster-specific update:** on `teach-sub1` specifically, QIIME2 is confirmed available as a real Lmod module (`QIIME2/2025.10-amplicon`) rather than needing conda at all — discovered while fixing the sibling `PRJEB4927_Amplicon_Parkinsons_Gut_Microbiome` repo. `biom` is also confirmed to ship bundled with that same QIIME2 module (`command -v biom` resolves once QIIME2 loads) — no separate module needed for it. `pipeline_orchestration/load_modules.sh` tries QIIME2 and a confirmed real `FastQC/0.12.1-Java-11` first; for MultiQC and R (no single confirmed version exists), it discovers all real versions live and auto-selects the highest, loudly disclosing every version it did not pick. Try `load_modules.sh` before `activate_conda_env.sh` on this cluster; the two can be combined if modules alone don't cover everything.
