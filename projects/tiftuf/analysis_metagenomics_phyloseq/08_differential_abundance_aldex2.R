## 08_differential_abundance_aldex2.R
## Uses raw feature counts with a CLR Monte Carlo model. The prespecified
## two-level contrast is drought versus well_watered.
if (!exists("PROJECT_ROOT")) source("common.R")
suppressPackageStartupMessages({ library(ALDEx2); library(phyloseq); library(dplyr) })
aldex_by_assay <- list()
for (assay in names(physeq_filtered)) {
  ps <- physeq_filtered[[assay]]
  md <- data.frame(sample_data(ps), check.names = FALSE)
  group_var <- "irrigation_group"
  keep <- md[[group_var]] %in% c("drought", "well_watered")
  keep <- keep & md$compartment == "root_endosphere"
  ps2 <- prune_samples(keep, ps); md2 <- data.frame(sample_data(ps2), check.names = FALSE)
  if (nsamples(ps2) < 4 || length(unique(md2[[group_var]])) != 2) {
    warning("Skipping ALDEx2 for ", assay, ": the prespecified two-group contrast is incomplete")
    next
  }
  counts <- as(otu_table(ps2), "matrix"); if (!taxa_are_rows(ps2)) counts <- t(counts)
  conditions <- factor(md2[[group_var]], levels = c("well_watered", "drought"))
  set.seed(42)
  clr <- aldex.clr(counts, conditions, mc.samples = 128, denom = "all", verbose = FALSE)
  result <- data.frame(aldex.ttest(clr, paired.test = FALSE, verbose = FALSE),
                       aldex.effect(clr, verbose = FALSE), check.names = FALSE)
  result$feature_id <- rownames(result)
  if (!is.null(tax_table(ps2, errorIfNULL = FALSE))) {
    tx <- data.frame(tax_table(ps2), check.names = FALSE) |> tibble::rownames_to_column("feature_id")
    result <- left_join(result, tx, by = "feature_id")
  }
  result <- arrange(result, wi.eBH, desc(abs(effect)))
  aldex_by_assay[[assay]] <- result
  write_tsv(result, file.path(RESULTS_DIR, paste0("08_aldex2_", safe_name(assay), ".tsv")))
}
