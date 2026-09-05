## 07_qrmc3hs_showcase.R
## Tests the study's central QRMC-3HS community claim without inventing a
## single causal taxon. The result remains an association.
if (!exists("PROJECT_ROOT")) source("common.R")
suppressPackageStartupMessages({ library(phyloseq); library(vegan); library(ggplot2) })
ps <- physeq_proportions[["16S"]]
md <- data.frame(sample_data(ps), check.names = FALSE)
keep <- !is.na(md$qrmc3hs_haplotype) & md$qrmc3hs_haplotype %in% c("wild_like", "elite_like") & md$compartment == "rhizosphere"
ps_qrmc <- prune_samples(keep, ps)
if (nsamples(ps_qrmc) < 4 || length(unique(sample_data(ps_qrmc)$qrmc3hs_haplotype)) < 2) {
  stop("QRMC-3HS showcase needs at least two reviewed samples in each haplotype class.")
}
bray <- distance(ps_qrmc, "bray"); qmd <- data.frame(sample_data(ps_qrmc), check.names = FALSE)
perm <- how(nperm = 4999); setBlocks(perm) <- factor(qmd$batch)
qrmc_test <- adonis2(bray ~ qrmc3hs_haplotype + batch, data = qmd, permutations = perm, by = "margin")
qrmc_dispersion <- permutest(betadisper(bray, factor(qmd$qrmc3hs_haplotype)), permutations = perm)
ord <- cmdscale(bray, eig = TRUE, k = 2)
df <- data.frame(Axis1 = ord$points[, 1], Axis2 = ord$points[, 2], qmd)
p_showcase <- ggplot(df, aes(Axis1, Axis2, color = qrmc3hs_haplotype, shape = batch)) +
  geom_point(size = 3) + labs(title = "QRMC-3HS-associated bacterial community structure") +
  theme_minimal(base_size = 11)
ggsave(file.path(RESULTS_DIR, "07_qrmc3hs_showcase.png"), p_showcase, width = 7.5, height = 5.8, dpi = 300)
capture.output(qrmc_test, qrmc_dispersion, file = file.path(RESULTS_DIR, "07_qrmc3hs_tests.txt"))
