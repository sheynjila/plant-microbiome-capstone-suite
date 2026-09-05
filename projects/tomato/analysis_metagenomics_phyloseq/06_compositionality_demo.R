## 06_compositionality_demo.R
## Demonstrates closure on each study's observed data. A negative correlation
## between one component and the remainder is mathematical, not evidence of
## biological antagonism.
if (!exists("PROJECT_ROOT")) source("common.R")
suppressPackageStartupMessages({ library(phyloseq); library(ggplot2) })
compositionality_results <- list(); p_composition <- list()
for (assay in names(physeq_proportions)) {
  ps <- physeq_proportions[[assay]]
  rank <- if ("Genus" %in% colnames(tax_table(ps))) "Genus" else colnames(tax_table(ps))[ncol(tax_table(ps))]
  glom <- tax_glom(ps, taxrank = rank, NArm = FALSE)
  x <- as(otu_table(glom), "matrix"); if (taxa_are_rows(glom)) x <- t(x)
  labels <- taxonomy_column(glom, rank); labels[is.na(labels) | labels == ""] <- taxa_names(glom)[is.na(labels) | labels == ""]
  colnames(x) <- make.unique(labels)
  target <- colnames(x)[which.max(colMeans(x))]
  target_value <- x[, target]
  remainder <- rowSums(x[, colnames(x) != target, drop = FALSE])
  rho <- suppressWarnings(cor(target_value, remainder, method = "spearman"))
  df <- data.frame(target = target_value, remainder = remainder)
  p_composition[[assay]] <- ggplot(df, aes(target, remainder)) + geom_point(alpha = 0.7) +
    geom_smooth(method = "lm", se = FALSE) +
    labs(title = paste(assay, "compositional closure"),
         subtitle = paste0(target, "; Spearman rho = ", round(rho, 3)),
         x = paste(target, "relative abundance"), y = "Sum of all other relative abundances") +
    theme_minimal(base_size = 11)
  ggsave(file.path(RESULTS_DIR, paste0("06_compositionality_", safe_name(assay), ".png")),
         p_composition[[assay]], width = 7, height = 5.5, dpi = 300)
  compositionality_results[[assay]] <- data.frame(assay = assay, target = target, spearman_rho = rho)
}
write_tsv(do.call(rbind, compositionality_results), file.path(RESULTS_DIR, "06_compositionality_summary.tsv"))
