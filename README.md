# Plant Microbiome Capstone Suite

This monorepo contains three independent, sequential teaching projects built from public plant-microbiome studies. A single repository is the best fit because it keeps one reproducibility standard, one assessment framework, and one master document while giving each student a self-contained project folder.

## Projects

| Project | Raw-data branches | R analysis | Correct validation endpoint |
|---|---|---|---|
| [Barley](projects/barley/README.md) | 16S and ITS | Diversity, composition, QRMC-3HS-focused comparison, ALDEx2 | Host SNP or haplotype followed by in-silico KASP or PolyMarker design |
| [Tomato](projects/tomato/README.md) | 16S and shotgun | Diversity, composition, feature integration, ALDEx2 | Tomato QTL and host SNP followed by in-silico KASP or PolyMarker design |
| [TifTuf](projects/tiftuf/README.md) | 16S and ITS | Irrigation-by-compartment ecology, load-aware biomarkers, ALDEx2 | Microbial taxon or gene followed by qPCR or ddPCR design |

## Teaching sequence

Every project preserves the reference curriculum's order.

```text
1  Fetch one pilot run and verify its checksum
2  Run and interpret pilot FastQC
3  Fetch all reviewed runs and import or stage them
4  Remove primers or adapters and generate analysis-ready reads or ASVs
5  Assign taxonomy and export feature counts
6  Generate the upstream QC and provenance report

00 Install or verify R packages
01 Prepare and validate analysis metadata
02 Load feature counts and build phyloseq objects
03 Apply declared QC filters and normalization views
04 Analyze alpha diversity
05 Analyze beta diversity, PERMANOVA, and dispersion
06 Demonstrate compositional closure
07 Reproduce a study-specific biological result
08 Run CLR-based differential abundance with ALDEx2
09 Assemble the publication dashboard and provenance record
```

## Start here

1. Read the selected project's `README.md` and its execution guide in `docs/`.
2. Copy `config/project.env.example` to `config/project.env` and review every path.
3. Run Script 1. Open `data/run_manifest.tsv`, reconcile assay and biological labels with the paper and supplementary metadata, and change `include` only after review.
4. Run Scripts 2 through 6 in order. Do not submit Script 4 before interpreting the FastQC and overlap constraints.
5. Complete `data/analysis_metadata.tsv` without inferring groups from filenames or row order.
6. Run `Rscript analysis_metagenomics_phyloseq/run_analysis.R`.

## Documentation bundle

The complete portfolio is available in [Markdown](docs/master/plant_microbiome_capstone_master_document.md), Word, and PDF under `docs/master/`. Each project also contains a concise README and an illustrated execution guide in Markdown, Word, and PDF.

## Reproducibility policy

Raw FASTQ files, reference databases, Kraken2 databases, host indexes, QIIME2 artifacts, and large intermediate files remain outside Git. The repository records URLs, checksums, versions, commands, metadata decisions, and outputs needed to reproduce an analysis. Scripts use project-relative paths and fail when required metadata or references are missing.

The pipeline deliberately does not claim that an in-silico primer is experimentally validated. See [shared reproducibility standards](shared/REPRODUCIBILITY_AND_CLAIMS.md) and the [master portfolio](docs/master/plant_microbiome_capstone_master_document.md).

The [reference-script mapping](shared/REFERENCE_SCRIPT_MAPPING.md) records every preserved teaching role and every necessary study-specific change.

Run `python tests/validate_repository.py` from the repository root for a no-download structural check. This confirms the three project sequences, accessions, primers, metadata schemas, diagrams, and master artifacts.

`REPOSITORY_MANIFEST.tsv` records the byte size and SHA-256 checksum of every delivered file.
