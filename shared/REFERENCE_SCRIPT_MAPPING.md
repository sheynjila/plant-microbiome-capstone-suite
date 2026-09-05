# Mapping from the supplied teaching skeleton

The supplied Parkinson's gut-microbiome scripts were used as the structural reference. Their numerical order and one-decision-per-file teaching style are preserved. The changes below are limited to what the plant studies and reproducibility require.

| Reference position | Preserved role | Necessary adaptation |
|---:|---|---|
| Shell 1 | Fetch and verify one pilot | ENA run reports and deposited MD5 values replace a hard-coded SRA run and cluster path |
| Shell 2 | Interpret FastQC | Paired Illumina overlap and marker-specific length replace 454 single-end interpretation; MultiQC is added |
| Shell 3 | Fetch all and import jointly | Reviewed manifests separate 16S, ITS, RNA-seq exclusion, and tomato shotgun data |
| Shell 4 | Remove primers and generate features | DADA2 ASVs replace 97 percent VSEARCH OTUs because all three selected studies used paired Illumina data |
| Shell 5 | Classify and export | SILVA and UNITE are assay-specific; tomato shotgun adds host depletion, Kraken2, and Bracken |
| Shell 6 | Surface QC before R | Per-assay QIIME summaries, MultiQC, software versions, and exported-file hashes are recorded |
| R 00 to 03 | Package, metadata, object, and filter setup | `renv`, experimental-unit checks, multiple assay objects, raw counts, proportions, and CLR views are explicit |
| R 04 to 06 | Alpha, beta, and compositionality lessons | Paired/block-aware PERMANOVA and PERMDISP plus Aitchison sensitivity are added |
| R 07 | Compare with the paper's central result | QRMC-3HS, tomato RIL feature gating, and TifTuf Actinobacteria replace Prevotellaceae |
| R 08 | CLR-based differential abundance | ALDEx2 is retained with a prespecified study-specific two-group contrast |
| R 09 | Publication dashboard | Available panels, input checksums, and `sessionInfo()` are combined without fabricating missing branches |

Site-specific `module load` statements were removed because they are not portable. The scripts fail on missing commands and record the environment actually used. The original scientific distinction between raw counts, relative abundance, rarefaction, and CLR analysis is retained and made consistent across the three projects.
