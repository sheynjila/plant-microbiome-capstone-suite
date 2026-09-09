# Toolchain contract

The shell scripts target the stable QIIME 2 command interfaces used by the supplied teaching skeleton and verify commands at runtime. Use one documented Linux environment and capture actual versions with Script 6. The minimum interfaces are QIIME 2 with q2-cutadapt, q2-dada2, q2-feature-classifier, q2-demux, and q2-feature-table; FastQC; MultiQC; BIOM; curl; and GNU checksum tools.

No shotgun classifiers are required for this project.

R Script 00 creates or restores `renv.lock`. Commit that lockfile after the first supervised installation. Keep reference databases and per-user package caches outside Git.

No conda environment name is pinned anywhere in this project deliberately — `pipeline_orchestration/activate_conda_env.sh` discovers which of your existing conda environments actually provides everything above (by capability, not by name) and activates it; run `source pipeline_orchestration/activate_conda_env.sh` each session before `check_environment.sh`.
