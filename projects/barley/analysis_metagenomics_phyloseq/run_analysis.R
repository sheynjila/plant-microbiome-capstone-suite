## Execute the numbered analysis in one R session so documented objects pass
    ## forward exactly as shown in the teaching sequence.
    args <- commandArgs(trailingOnly = FALSE)
    file_arg <- grep("^--file=", args, value = TRUE)
    analysis_dir <- dirname(normalizePath(sub("^--file=", "", file_arg[[1]])))
    setwd(analysis_dir)
    scripts <- c(
      "common.R",
  "01_prepare_metadata.R",
  "02_load_biom_and_build_phyloseq.R",
  "03_qc_filter_and_normalization.R",
  "04_alpha_diversity.R",
  "05_beta_diversity.R",
  "06_compositionality_demo.R",
  "07_qrmc3hs_showcase.R",
  "08_differential_abundance_aldex2.R",
  "09_publication_dashboard.R"
    )
    for (script in scripts) {
      message("
===== ", script, " =====")
      sys.source(script, envir = .GlobalEnv)
    }
