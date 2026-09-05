## 00_install_packages.R
## Run once. If renv.lock exists, restore it. Otherwise install the declared
## package set and create a lockfile so subsequent executions are frozen.
cran_packages <- c("vegan", "permute", "ggplot2", "dplyr", "tidyr", "readr",
                   "tibble", "patchwork", "scales", "renv")
bioc_packages <- c("phyloseq", "biomformat", "ALDEx2")

find_project_root <- function(start = getwd()) {
  current <- normalizePath(start, mustWork = TRUE)
  repeat {
    if (file.exists(file.path(current, "config", "assays.tsv"))) return(current)
    parent <- dirname(current)
    if (identical(parent, current)) break
    current <- parent
  }
  stop("Run Script 00 from the project root or its analysis subdirectory.", call. = FALSE)
}

manage_packages <- function(mode = c("interactive", "automatic")) {
  mode <- match.arg(mode)
  if (!requireNamespace("renv", quietly = TRUE)) install.packages("renv")
  root <- find_project_root()
  lock <- file.path(root, "renv.lock")
  if (file.exists(lock)) {
    renv::restore(project = root, prompt = mode == "interactive")
    return(invisible(lock))
  }
  missing_cran <- cran_packages[!vapply(cran_packages, requireNamespace, logical(1), quietly = TRUE)]
  missing_bioc <- bioc_packages[!vapply(bioc_packages, requireNamespace, logical(1), quietly = TRUE)]
  if (mode == "interactive" && length(c(missing_cran, missing_bioc))) {
    answer <- readline("Install missing packages and create renv.lock? [y/N] ")
    if (!tolower(answer) %in% c("y", "yes")) return(invisible(NULL))
  }
  if (length(missing_cran)) install.packages(missing_cran)
  if (length(missing_bioc)) {
    if (!requireNamespace("BiocManager", quietly = TRUE)) install.packages("BiocManager")
    BiocManager::install(missing_bioc, update = FALSE, ask = FALSE)
  }
  renv::init(project = root, bare = TRUE, restart = FALSE)
  renv::snapshot(project = root, prompt = FALSE)
  message("Created ", lock, ". Commit it with the project.")
  invisible(lock)
}

