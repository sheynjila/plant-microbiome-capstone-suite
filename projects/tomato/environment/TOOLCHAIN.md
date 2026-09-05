# Toolchain contract

The shell scripts target the stable QIIME 2 command interfaces used by the supplied teaching skeleton and verify commands at runtime. Use one documented Linux environment and capture actual versions with Script 6. The minimum interfaces are QIIME 2 with q2-cutadapt, q2-dada2, q2-feature-classifier, q2-demux, and q2-feature-table; FastQC; MultiQC; BIOM; curl; and GNU checksum tools.

The tomato shotgun branch also requires fastp, Bowtie2, Kraken2, Bracken, and Python 3.

R Script 00 creates or restores `renv.lock`. Commit that lockfile after the first supervised installation. Keep reference databases and per-user package caches outside Git.
