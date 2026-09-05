## 02_load_biom_and_build_phyloseq.R
    ## Loads this pipeline's own exported feature counts. The raw-read workflow
    ## remains primary because processed tables may use different databases or
    ## filtering decisions.
    if (!exists("PROJECT_ROOT")) source("common.R")
    suppressPackageStartupMessages({ library(phyloseq); library(biomformat) })
    physeq_by_assay <- list()
    for (assay in c("16S")) {
      physeq_by_assay[[assay]] <- load_amplicon_phyloseq(assay, sample_info)
      message(assay, ": ", ntaxa(physeq_by_assay[[assay]]), " features x ",
              nsamples(physeq_by_assay[[assay]]), " samples")
    }
    shotgun_counts <- file.path(HANDOFF_DIR, "shotgun", "feature_counts.tsv")
if (file.exists(shotgun_counts)) {
  physeq_by_assay[["shotgun"]] <- load_shotgun_phyloseq(sample_info)
} else {
  warning("Shotgun Bracken table is absent. Amplicon analysis can continue, but the full tomato pipeline is incomplete.")
}
    saveRDS(physeq_by_assay, file.path(RESULTS_DIR, "02_phyloseq_raw.rds"))
