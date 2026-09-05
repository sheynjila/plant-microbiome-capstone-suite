## 01_prepare_metadata.R
## Validates the biological design before counts are loaded. No group is
## inferred from filenames, row order, run accession, or plotting color.
if (!exists("PROJECT_ROOT")) source("common.R")
metadata_path <- file.path(DATA_DIR, "analysis_metadata.tsv")
require_file(metadata_path, paste("Complete the metadata schema first:", metadata_path))
sample_info <- utils::read.delim(metadata_path, check.names = FALSE, na.strings = c("", "NA"))
if (!nrow(sample_info)) stop("analysis_metadata.tsv contains only a header; add reviewed study rows.")
required_columns <- c("sample_id", "analysis_id", "run_accession", "assay", "experimental_unit_id", "genotype", "qrmc3hs_haplotype", "compartment", "batch", "biological_replicate", "control_status")
assert_columns(sample_info, required_columns, "analysis_metadata.tsv")
if (anyDuplicated(sample_info$analysis_id)) stop("analysis_id must be unique across metadata rows")
blank_required <- vapply(required_columns, function(x) any(is.na(sample_info[[x]]) | sample_info[[x]] == ""), logical(1))
if (any(blank_required)) stop("Blank required metadata fields: ", paste(names(blank_required)[blank_required], collapse = ", "))

rownames(sample_info) <- sample_info$analysis_id
write_tsv(sample_info, file.path(RESULTS_DIR, "metadata_validated.tsv"))
message("Validated ", nrow(sample_info), " analysis rows representing ",
        length(unique(sample_info$experimental_unit_id)), " experimental units.")
