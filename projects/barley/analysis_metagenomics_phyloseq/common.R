options(stringsAsFactors = FALSE)

command_file <- grep("^--file=", commandArgs(trailingOnly = FALSE), value = TRUE)
analysis_dir <- if (length(command_file)) {
  dirname(normalizePath(sub("^--file=", "", command_file[[1]]), mustWork = TRUE))
} else {
  normalizePath(getwd(), mustWork = TRUE)
}
if (!file.exists(file.path(analysis_dir, "common.R"))) {
  candidate <- file.path(getwd(), "analysis_metagenomics_phyloseq")
  if (file.exists(file.path(candidate, "common.R"))) analysis_dir <- normalizePath(candidate)
}

PROJECT_ROOT <- normalizePath(file.path(analysis_dir, ".."), mustWork = TRUE)
DATA_DIR <- file.path(PROJECT_ROOT, "data")
HANDOFF_DIR <- file.path(PROJECT_ROOT, "pipeline_raw_reads_to_counts_output", "exported")
RESULTS_DIR <- file.path(PROJECT_ROOT, "results")
dir.create(RESULTS_DIR, recursive = TRUE, showWarnings = FALSE)

require_file <- function(path, message = NULL) {
  if (!file.exists(path) || file.info(path)$size == 0) {
    stop(if (is.null(message)) paste("Required non-empty file not found:", path) else message,
         call. = FALSE)
  }
  invisible(path)
}

assert_columns <- function(data, required, label) {
  missing <- setdiff(required, names(data))
  if (length(missing)) stop(label, " is missing columns: ", paste(missing, collapse = ", "), call. = FALSE)
  invisible(TRUE)
}

write_tsv <- function(data, path) {
  dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
  utils::write.table(data, path, sep = "\t", quote = FALSE, row.names = FALSE, na = "NA")
}

taxonomy_column <- function(ps, rank) {
  tx <- as.data.frame(phyloseq::tax_table(ps), stringsAsFactors = FALSE)
  if (!rank %in% names(tx)) return(rep(NA_character_, nrow(tx)))
  as.character(tx[[rank]])
}

load_amplicon_phyloseq <- function(assay, metadata) {
  biom_path <- file.path(HANDOFF_DIR, assay, "feature_table", "feature-table-with-taxonomy.biom")
  require_file(biom_path, paste0("Missing ", assay, " BIOM handoff. Run upstream Scripts 1-6 first: ", biom_path))
  ps <- phyloseq::import_biom(biom_path)
  tx <- phyloseq::tax_table(ps, errorIfNULL = FALSE)
  if (!is.null(tx)) {
    canonical <- c("Kingdom", "Phylum", "Class", "Order", "Family", "Genus", "Species")
    current <- colnames(tx)
    if (!any(canonical %in% current) && ncol(tx) <= length(canonical)) {
      colnames(tx) <- canonical[seq_len(ncol(tx))]
      phyloseq::tax_table(ps) <- tx
    }
  }
  md <- metadata[metadata$assay == assay, , drop = FALSE]
  ids <- phyloseq::sample_names(ps)
  absent <- setdiff(ids, md$analysis_id)
  if (length(absent)) stop("Feature table IDs absent from metadata for ", assay, ": ",
                           paste(absent, collapse = ", "), call. = FALSE)
  md <- md[match(ids, md$analysis_id), , drop = FALSE]
  if (anyDuplicated(md$experimental_unit_id)) {
    stop("Technical runs map to duplicate experimental_unit_id values within ", assay,
         ". Merge their counts deliberately before biological inference.", call. = FALSE)
  }
  rownames(md) <- md$analysis_id
  phyloseq::sample_data(ps) <- phyloseq::sample_data(md)
  ps
}

load_shotgun_phyloseq <- function(metadata) {
  counts_path <- file.path(HANDOFF_DIR, "shotgun", "feature_counts.tsv")
  taxonomy_path <- file.path(HANDOFF_DIR, "shotgun", "taxonomy.tsv")
  require_file(counts_path); require_file(taxonomy_path)
  counts <- utils::read.delim(counts_path, check.names = FALSE)
  taxonomy <- utils::read.delim(taxonomy_path, check.names = FALSE)
  rownames(counts) <- counts$feature_id; counts$feature_id <- NULL
  rownames(taxonomy) <- taxonomy$feature_id; taxonomy$feature_id <- NULL
  md <- metadata[metadata$assay == "shotgun", , drop = FALSE]
  absent <- setdiff(colnames(counts), md$analysis_id)
  if (length(absent)) stop("Shotgun count IDs absent from metadata: ", paste(absent, collapse = ", "))
  md <- md[match(colnames(counts), md$analysis_id), , drop = FALSE]
  if (anyDuplicated(md$experimental_unit_id)) {
    stop("Duplicate shotgun experimental units detected; merge technical runs before analysis.")
  }
  rownames(md) <- md$analysis_id
  phyloseq::phyloseq(
    phyloseq::otu_table(as.matrix(counts), taxa_are_rows = TRUE),
    phyloseq::tax_table(as.matrix(taxonomy)),
    phyloseq::sample_data(md)
  )
}

prune_non_target <- function(ps, assay) {
  if (is.null(phyloseq::tax_table(ps, errorIfNULL = FALSE))) return(ps)
  tx <- as.data.frame(phyloseq::tax_table(ps), stringsAsFactors = FALSE)
  text <- apply(tx, 1, paste, collapse = ";")
  keep <- !grepl("Chloroplast|Mitochond", text, ignore.case = TRUE)
  if (assay == "16S" && "Kingdom" %in% names(tx)) {
    annotated <- nzchar(tx$Kingdom) & !is.na(tx$Kingdom)
    keep[annotated] <- keep[annotated] & grepl("Bacteria", tx$Kingdom[annotated], ignore.case = TRUE)
  }
  if (assay == "ITS" && "Kingdom" %in% names(tx)) {
    annotated <- nzchar(tx$Kingdom) & !is.na(tx$Kingdom)
    keep[annotated] <- keep[annotated] & grepl("Fungi", tx$Kingdom[annotated], ignore.case = TRUE)
  }
  phyloseq::prune_taxa(keep, ps)
}

clr_matrix <- function(ps, pseudocount = 0.5) {
  x <- as(phyloseq::otu_table(ps), "matrix")
  if (!phyloseq::taxa_are_rows(ps)) x <- t(x)
  logged <- log(x + pseudocount)
  sweep(logged, 2, colMeans(logged), FUN = "-")
}

safe_name <- function(x) gsub("[^A-Za-z0-9_.-]+", "_", x)
