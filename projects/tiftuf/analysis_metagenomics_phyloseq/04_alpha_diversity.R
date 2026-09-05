## 04_alpha_diversity.R
## Computes rarefied alpha diversity with a fixed seed. The rarefied object
## is not reused for compositional differential-abundance testing.
if (!exists("PROJECT_ROOT")) source("common.R")
suppressPackageStartupMessages({ library(phyloseq); library(ggplot2); library(dplyr) })
set.seed(42)
alpha_results <- list(); p_alpha <- list()
for (assay in names(physeq_filtered)) {
  ps <- physeq_filtered[[assay]]
  depth <- min(sample_sums(ps))
  rare <- rarefy_even_depth(ps, sample.size = depth, rngseed = 42, replace = FALSE, verbose = FALSE)
  alpha <- cbind(data.frame(analysis_id = sample_names(rare)),
                 estimate_richness(rare, measures = c("Observed", "Shannon", "Simpson")))
  md <- data.frame(sample_data(rare), check.names = FALSE)
  md$analysis_id <- rownames(md)
  alpha <- left_join(alpha, md, by = "analysis_id")
  group_var <- "irrigation_group"
  assert_columns(alpha, group_var, paste(assay, "alpha metadata"))
  groups <- unique(na.omit(alpha[[group_var]]))
  test <- if (length(groups) == 2) wilcox.test(alpha$Shannon ~ factor(alpha[[group_var]])) else kruskal.test(alpha$Shannon ~ factor(alpha[[group_var]]))
  alpha$test_p <- test$p.value
  alpha_results[[assay]] <- alpha
  p_alpha[[assay]] <- ggplot(alpha, aes(x = .data[[group_var]], y = Shannon, fill = .data[[group_var]])) +
    geom_boxplot(outlier.shape = NA) + geom_jitter(width = 0.15, alpha = 0.65) +
    labs(title = paste(assay, "alpha diversity"),
         subtitle = paste0("Rarefied to ", depth, " reads; p = ", signif(test$p.value, 3)),
         x = group_var, y = "Shannon diversity") + theme_minimal(base_size = 11) +
    theme(legend.position = "none") + facet_wrap(~ compartment)
  ggsave(file.path(RESULTS_DIR, paste0("04_alpha_", safe_name(assay), ".png")),
         p_alpha[[assay]], width = 7, height = 5.5, dpi = 300)
  write_tsv(alpha, file.path(RESULTS_DIR, paste0("04_alpha_", safe_name(assay), ".tsv")))
}
