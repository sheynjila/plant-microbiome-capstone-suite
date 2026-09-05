## 07_actinobacteria_load_showcase.R
## Examines the published Actinobacteria and Streptomyces pattern across
## the full irrigation gradient and compartments. qPCR-scaled values are
## labeled as load proxies, not direct taxon counts.
if (!exists("PROJECT_ROOT")) source("common.R")
suppressPackageStartupMessages({ library(phyloseq); library(dplyr); library(ggplot2) })
ps <- tax_glom(physeq_proportions[["16S"]], taxrank = "Phylum", NArm = FALSE)
phyla <- taxonomy_column(ps, "Phylum")
idx <- grep("Actinobacter", phyla, ignore.case = TRUE)
if (!length(idx)) stop("No Actinobacteria-labelled feature found; inspect the taxonomy reference and filtering.")
actino <- colSums(as(otu_table(prune_taxa(taxa_names(ps)[idx], ps)), "matrix"))
if (!taxa_are_rows(ps)) actino <- rowSums(as(otu_table(prune_taxa(taxa_names(ps)[idx], ps)), "matrix"))
md <- data.frame(sample_data(ps), check.names = FALSE)
md$actinobacteria_relative <- actino[rownames(md)]
if ("qpcr_bacterial" %in% names(md)) {
  md$actinobacteria_qpcr_scaled_proxy <- md$actinobacteria_relative * as.numeric(md$qpcr_bacterial)
}
p_showcase <- ggplot(md, aes(irrigation_pct_et, actinobacteria_relative, color = compartment)) +
  geom_point(size = 2.5) + geom_smooth(method = "lm", se = TRUE) +
  labs(title = "TifTuf Actinobacteria across the irrigation gradient",
       x = "Evapotranspiration replacement percent", y = "Relative abundance") +
  theme_minimal(base_size = 11)
ggsave(file.path(RESULTS_DIR, "07_tiftuf_actinobacteria_showcase.png"), p_showcase, width = 8, height = 5.8, dpi = 300)
write_tsv(md, file.path(RESULTS_DIR, "07_tiftuf_actinobacteria_load_context.tsv"))
