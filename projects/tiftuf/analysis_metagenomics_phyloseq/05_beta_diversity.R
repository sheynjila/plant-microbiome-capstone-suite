## 05_beta_diversity.R
## Runs Bray-Curtis and Aitchison analyses, PERMANOVA, and the required
## PERMDISP check. The block variable constrains permutations.
if (!exists("PROJECT_ROOT")) source("common.R")
suppressPackageStartupMessages({ library(phyloseq); library(vegan); library(permute); library(ggplot2) })
beta_results <- list(); p_beta <- list()
for (assay in names(physeq_filtered)) {
  ps <- physeq_filtered[[assay]]
  md <- data.frame(sample_data(ps), check.names = FALSE)
  block_var <- "field_block"
  assert_columns(md, block_var, paste(assay, "beta metadata"))
  bray <- phyloseq::distance(physeq_proportions[[assay]], method = "bray")
  model_formula <- as.formula("bray ~ compartment * irrigation_pct_et")
  perm <- how(nperm = 999)
  setBlocks(perm) <- factor(md[[block_var]])
  permanova <- adonis2(model_formula, data = md, permutations = perm, by = "margin")
  primary <- factor(md[["irrigation_group"]])
  dispersion <- betadisper(bray, primary)
  permdisp <- permutest(dispersion, permutations = perm)
  ord <- cmdscale(bray, eig = TRUE, k = 2)
  ord_df <- data.frame(analysis_id = rownames(ord$points), Axis1 = ord$points[, 1], Axis2 = ord$points[, 2], md)
  p_beta[[assay]] <- ggplot(ord_df, aes(Axis1, Axis2, color = .data[["irrigation_group"]])) +
    geom_point(size = 2.8, alpha = 0.8) +
    labs(title = paste(assay, "Bray-Curtis PCoA"), color = "irrigation_group") +
    theme_minimal(base_size = 11)
  ggsave(file.path(RESULTS_DIR, paste0("05_beta_", safe_name(assay), ".png")),
         p_beta[[assay]], width = 7, height = 5.5, dpi = 300)
  aitchison <- dist(t(clr_by_assay[[assay]]))
  aitchison_model <- adonis2(as.formula("aitchison ~ compartment * irrigation_pct_et"), data = md,
                             permutations = perm, by = "margin")
  beta_results[[assay]] <- list(bray = bray, permanova = permanova,
                                permdisp = permdisp, aitchison = aitchison,
                                aitchison_permanova = aitchison_model)
  capture.output(permanova, permdisp, aitchison_model,
                 file = file.path(RESULTS_DIR, paste0("05_beta_tests_", safe_name(assay), ".txt")))
}
