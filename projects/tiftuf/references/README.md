# Reference data

Place QIIME2 reference-sequence and taxonomy artifacts under this directory using the filenames in `config/assays.tsv`. Do not commit the large artifacts. Record each source URL, download date, release, and SHA-256 checksum in `reference_manifest.tsv`.

The paper used Greengenes 13.8 for bacteria and UNITE 8.3 for fungi. This teaching implementation uses SILVA 138 for the primary bacterial branch because Greengenes 13.8 is historical; record this as a deliberate modernization and treat a Greengenes rerun as a reproduction sensitivity analysis.

The pipeline stops when an expected reference is absent. This is intentional; substituting an unnamed database would compromise reproducibility.
