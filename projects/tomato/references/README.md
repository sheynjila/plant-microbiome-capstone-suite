# Reference data

Place QIIME2 reference-sequence and taxonomy artifacts under this directory using the filenames in `config/assays.tsv`. Do not commit the large artifacts. Record each source URL, download date, release, and SHA-256 checksum in `reference_manifest.tsv`.

The paper assigned 16S taxonomy with SILVA 132; the default filenames preserve that reproduction branch. The published Kraken database is available from the authors by request. A replacement database is acceptable only when its build date, genome sources, taxonomy snapshot, Bracken read length, and checksums are recorded. Build the Bowtie2 index from a documented tomato reference assembly and retain the FASTA checksum.

The pipeline stops when an expected reference is absent. This is intentional; substituting an unnamed database would compromise reproducibility.
