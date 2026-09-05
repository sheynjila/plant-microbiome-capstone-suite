# Barley QRMC-3HS host microbiome capstone

**Study:** Escudero-Martínez et al. (2022), Identifying plant genes shaping microbiota composition in the barley rhizosphere  
**Primary source:** [https://doi.org/10.1038/s41467-022-31022-y](https://doi.org/10.1038/s41467-022-31022-y)  
**Public sequence project:** PRJEB50061  
**Implemented read branches:** 16S, ITS

The numbered scripts reprocess the 16S and ITS branches. Host QTL, RNA-seq, and KASP work are retained as documented integration extensions because the necessary plant marker matrix, locus coordinates, and biological metadata must be reconciled before executable claims are safe.

![Barley data-processing pipeline](docs/diagrams/01_barley_data_pipeline.png)

## Pipeline contract

Scripts 1 through 6 create feature counts. R Scripts 01 through 09 consume only the exported counts, taxonomy, representative sequences, and a reviewed `data/analysis_metadata.tsv`. Execute files in numerical order. Script 00 installs or verifies R packages and is not sourced automatically during a production run.

```bash
cp config/project.env.example config/project.env
# edit paths and resource settings
bash pipeline_raw_reads_to_counts/1_Fetch_And_Verify_Raw_Reads.sh
# review data/run_manifest.tsv and the pilot FastQC report
bash pipeline_raw_reads_to_counts/2_Interpret_FastQC_Diagnostics.sh
bash pipeline_raw_reads_to_counts/3_Fetch_All_And_Import_To_QIIME2.sh
bash pipeline_raw_reads_to_counts/4_Primer_Trim_And_Infer_ASVs.sh
bash pipeline_raw_reads_to_counts/5_Classify_Taxonomy_And_Export.sh
bash pipeline_raw_reads_to_counts/6_QC_Report_Generator.sh

Rscript -e 'source("analysis_metagenomics_phyloseq/00_install_packages.R"); manage_packages("automatic")'
Rscript analysis_metagenomics_phyloseq/run_analysis.R
```

On Slurm, submit each upstream script only after the preceding quality gate passes. The scripts also run directly in an activated Linux environment. Site-specific `module load` commands are intentionally excluded because module names differ among clusters.

Once `data/run_manifest.tsv` has been reviewed, [`pipeline_orchestration/`](pipeline_orchestration/) can run Scripts 1-6 and the R analysis as one unattended Slurm job chain instead of submitting each step by hand.

## Metadata gate

Complete one row per analysis unit in `data/analysis_metadata.tsv`. Required fields are `sample_id`, `analysis_id`, `run_accession`, `assay`, `experimental_unit_id`, `genotype`, `qrmc3hs_haplotype`, `compartment`, `batch`, `biological_replicate`, `control_status`. Use `experimental_unit_id` to distinguish the plant, RIL, or field plot from a run or PCR library. Technical runs must not be counted as independent biological replicates.

Script 1 creates `data/run_manifest.tsv` from ENA. Its assay classifier is only a review aid. Any `REVIEW_REQUIRED` value must be resolved against the paper, supplements, and public repository before the row can be included.

## Reproducibility-critical changes from the reference skeleton

- All paths are project-relative or configured; no username or cluster scratch path is embedded.
- ENA-provided MD5 checksums are verified for every FASTQ, and exported products receive SHA-256 hashes.
- 16S and ITS files cannot enter the wrong processing branch. This project has no shotgun branch; see [Tomato](../tomato/README.md) for that variant.
- Published primers are visible in `config/assays.tsv`; truncation is left at zero until observed quality and overlap justify a change.
- SILVA 138 (16S) and UNITE 04.02.2020 (ITS) taxonomy references are explicit, versioned inputs.
- PERMANOVA is paired with PERMDISP, block variables are retained, and ALDEx2 uses raw counts rather than relative abundance.
- Every final dashboard records `sessionInfo()` and input provenance.

## Expected handoff to R

Amplicon outputs appear under `pipeline_raw_reads_to_counts_output/exported/<assay>/`. Each contains `feature-table-with-taxonomy.biom`, `taxonomy.tsv`, and `dna-sequences.fasta`. Tomato shotgun outputs appear under `exported/shotgun/` as a Bracken count matrix and taxonomy table.

## Study-specific endpoint

A ranked QRMC-3HS host-variant dossier and an in-silico KASP or PolyMarker design. The assay remains designed, not validated, until laboratory and independent-population testing.

![Barley downstream analysis pipeline](docs/diagrams/02_barley_analysis_pipeline.png)

The illustrated execution guide is supplied as [Markdown](docs/barley_execution_guide.md), Word, and PDF in `docs/`. Also see the [marker evidence template](marker_identification/marker_evidence_template.tsv) and the [master portfolio](../../docs/master/plant_microbiome_capstone_master_document.md).
