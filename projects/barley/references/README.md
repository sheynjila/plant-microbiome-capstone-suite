# Reference data

Place QIIME2 reference-sequence and taxonomy artifacts under this directory using the filenames in `config/assays.tsv`. Do not commit the large artifacts. Record each source URL, download date, release, and SHA-256 checksum in `reference_manifest.tsv`.

The paper used SILVA 138 for bacterial taxonomy and UNITE 04.02.2020 for fungal taxonomy. Keep those exact references for reproduction; a newer frozen release belongs in a separate sensitivity branch.

The pipeline stops when an expected reference is absent. This is intentional; substituting an unnamed database would compromise reproducibility.
