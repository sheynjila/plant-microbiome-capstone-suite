## 07_qtl_feature_showcase.R
## Recreates the defensible handoff from common rhizosphere ASVs to QTL
## phenotypes. It does not fabricate a host map or call new QTLs.
if (!exists("PROJECT_ROOT")) source("common.R")
suppressPackageStartupMessages({ library(phyloseq); library(dplyr); library(ggplot2) })
ps <- physeq_filtered[["16S"]]
md <- data.frame(sample_data(ps), check.names = FALSE)
keep <- md$host_group == "ril" & md$compartment == "rhizosphere"
ps_ril <- prune_samples(keep, ps)
if (nsamples(ps_ril) < 10) stop("Tomato QTL handoff requires reviewed RIL rhizosphere samples with host_group='ril'.")
x <- as(otu_table(ps_ril), "matrix"); if (!taxa_are_rows(ps_ril)) x <- t(x)
prevalence <- rowMeans(x > 0)
retained <- names(prevalence[prevalence >= 0.50])
trait <- as.data.frame(t(x[retained, , drop = FALSE]))
trait$analysis_id <- rownames(trait)
trait <- left_join(data.frame(sample_data(ps_ril), check.names = FALSE) |>
                     tibble::rownames_to_column("analysis_id"), trait, by = "analysis_id")
write_tsv(trait, file.path(RESULTS_DIR, "07_qtl_ready_asv_traits.tsv"))
prev_df <- data.frame(feature_id = names(prevalence), prevalence = prevalence,
                      retained_for_qtl = prevalence >= 0.50)
p_showcase <- ggplot(prev_df, aes(prevalence, fill = retained_for_qtl)) + geom_histogram(bins = 30) +
  geom_vline(xintercept = 0.5, linetype = "dashed") +
  labs(title = "Tomato RIL ASV prevalence gate", x = "Proportion of RIL samples", y = "ASVs") +
  theme_minimal(base_size = 11)
ggsave(file.path(RESULTS_DIR, "07_tomato_qtl_feature_gate.png"), p_showcase, width = 7, height = 5.5, dpi = 300)
message(length(retained), " ASVs retained as QTL phenotypes. QTL mapping requires the verified host map and covariates.")
