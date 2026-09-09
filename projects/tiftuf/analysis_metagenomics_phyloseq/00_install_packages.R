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

## On a shared HPC install (e.g. a module-provided R under /apps/...), the
## default system library is admin-owned and not writable by a regular
## user -- install.packages() fails outright under non-interactive Rscript,
## which can't fall back to the "create a personal library?" prompt an
## interactive session would show. Ensures a personal, writable library
## exists and is checked first, so this works the same whether or not
## R_LIBS_USER happens to already be set in the calling shell.
ensure_writable_library <- function() {
  lib <- Sys.getenv("R_LIBS_USER")
  if (identical(lib, "")) {
    lib <- file.path(Sys.getenv("HOME"), "R",
                      paste0(R.version$platform, "-library"),
                      paste(R.version$major, sub("\\..*$", "", R.version$minor), sep = "."))
  }
  if (!dir.exists(lib)) dir.create(lib, recursive = TRUE, showWarnings = FALSE)
  .libPaths(c(lib, .libPaths()))
  invisible(lib)
}

manage_packages <- function(mode = c("interactive", "automatic")) {
  mode <- match.arg(mode)
  ensure_writable_library()
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

## Auto-run when executed as a script (Rscript 00_install_packages.R), e.g.
## from check_environment.sh's own instructions. Left as a no-op when this
## file is `source()`d inside an interactive R session instead, so a human
## can call manage_packages() themselves with the interactive [y/N] prompt.
## Without this call, the functions above were defined but never invoked --
## Rscript would silently exit having installed nothing.
if (!interactive()) {
  manage_packages(mode = "automatic")
}

