## 03_qc_filter_and_normalization.R
## Keeps raw counts for ALDEx2, proportions for descriptive plots, and CLR
## coordinates for Aitchison distances. Rarefaction is reserved for the
## explicit alpha-diversity sensitivity analysis in Script 04.
if (!exists("PROJECT_ROOT")) source("common.R")
suppressPackageStartupMessages({ library(phyloseq); library(dplyr) })
min_prevalence <- as.integer(Sys.getenv("MIN_PREVALENCE_SAMPLES", "2"))
physeq_filtered <- list(); physeq_proportions <- list(); clr_by_assay <- list()
qc_rows <- list()
for (assay in names(physeq_by_assay)) {
  ps0 <- prune_non_target(physeq_by_assay[[assay]], assay)
  keep <- apply(as(otu_table(ps0), "matrix"), if (taxa_are_rows(ps0)) 1 else 2,
                function(x) sum(x > 0) >= min_prevalence)
  ps <- prune_taxa(keep, ps0)
  if (!ntaxa(ps)) stop("No features remain after filtering for ", assay)
  physeq_filtered[[assay]] <- ps
  physeq_proportions[[assay]] <- transform_sample_counts(ps, function(x) x / sum(x))
  clr_by_assay[[assay]] <- clr_matrix(ps)
  qc_rows[[assay]] <- data.frame(
    assay = assay, samples = nsamples(ps), features_before = ntaxa(physeq_by_assay[[assay]]),
    features_after = ntaxa(ps), min_depth = min(sample_sums(ps)),
    median_depth = median(sample_sums(ps)), max_depth = max(sample_sums(ps)))
}
qc_summary <- bind_rows(qc_rows)
write_tsv(qc_summary, file.path(RESULTS_DIR, "03_qc_summary.tsv"))
saveRDS(list(counts = physeq_filtered, proportions = physeq_proportions, clr = clr_by_assay),
        file.path(RESULTS_DIR, "03_analysis_objects.rds"))
print(qc_summary)
