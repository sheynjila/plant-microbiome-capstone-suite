# Reproducibility and claim standards

## Evidence hierarchy

Raw counts and directly observed sequences are measurements. Relative abundance is a composition, not microbial load. PICRUSt2 output is predicted function. A QTL identifies an associated genomic interval, not a causal gene. A primer produced by software is designed, not laboratory validated.

## Required gates

1. Reconcile accessions, assays, treatments, controls, and experimental units.
2. Verify every deposited checksum and record software and reference versions.
3. Inspect primer retention, quality, paired overlap, denoising loss, chimeras, non-target features, and sample depth.
4. Predeclare filtering, transformation, group contrast, block structure, and false-discovery threshold.
5. Pair PERMANOVA with PERMDISP and restrict permutations when blocks or repeated measures require it.
6. Report effect estimates and uncertainty with adjusted p-values.
7. Separate discovery data from independent validation data.

## Marker language

Use `associated with` for observational or QTL relationships, `predicted` for imputed functions, `designed` for in-silico primers, `laboratory tested` after assay performance has been measured, and `validated` only after both the assay and biological relationship have been confirmed in appropriate independent material.
