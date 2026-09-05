## 09_publication_dashboard.R
## Combines available study panels and records the exact R session. Missing
## optional branches are disclosed instead of replaced with fabricated data.
if (!exists("PROJECT_ROOT")) source("common.R")
suppressPackageStartupMessages({ library(ggplot2); library(patchwork) })
panels <- list()
if (length(p_alpha)) panels <- c(panels, unname(p_alpha)[1])
if (length(p_beta)) panels <- c(panels, unname(p_beta)[1])
if (exists("p_showcase")) panels <- c(panels, list(p_showcase))
if (length(p_composition)) panels <- c(panels, unname(p_composition)[1])
if (!length(panels)) stop("No plots are available for the dashboard")
dashboard <- wrap_plots(panels, ncol = 2) +
  plot_annotation(title = "Barley QRMC-3HS host microbiome capstone")
ggsave(file.path(RESULTS_DIR, "09_publication_dashboard.png"), dashboard,
       width = 12, height = 9, dpi = 300)
capture.output(sessionInfo(), file = file.path(RESULTS_DIR, "09_session_info.txt"))
inputs <- list.files(file.path(PROJECT_ROOT, "pipeline_raw_reads_to_counts_output", "provenance"),
                     full.names = TRUE)
provenance <- data.frame(file = inputs,
                         md5 = if (length(inputs)) unname(tools::md5sum(inputs)) else character())
write_tsv(provenance, file.path(RESULTS_DIR, "09_input_provenance.tsv"))
message("Dashboard and R provenance written to ", RESULTS_DIR)
