#!/usr/bin/env python3
"""Static checks for the teaching repository without downloading any data."""
from __future__ import annotations

import csv
import re
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
EXPECTED = {
    "barley": {
        "projects": {"PRJEB50061"},
        "primers": {"GTGCCAGCMGCCGCGGTAA", "GGACTACHVGGGTWTCTAAT",
                    "CTTGGTCATTTAGAGGAAGTAA", "GCTGCGTTCTTCATCGATGC"},
        "step7": "07_qrmc3hs_showcase.R",
    },
    "tomato": {
        "projects": {"PRJNA787039", "PRJNA789467"},
        "primers": {"CCTACGGGNGGCWGCAG", "GACTACHVGGGTATACTAATCC"},
        "step7": "07_qtl_feature_showcase.R",
    },
    "tiftuf": {
        "projects": {"PRJNA852645"},
        "primers": {"CCTACGGGNGGCWGCAG", "GACTACHVGGGTATCTAATCC",
                    "TAGAGGAAGTAAAAGTCGTAA", "TTYRCTRCGTTCTTCATC"},
        "step7": "07_actinobacteria_load_showcase.R",
    },
}


def fail(message: str) -> None:
    raise AssertionError(message)


def main() -> int:
    master = ROOT / "docs" / "master"
    for suffix in ("md", "docx", "pdf"):
        path = master / f"plant_microbiome_capstone_master_document.{suffix}"
        if not path.is_file() or path.stat().st_size == 0:
            fail(f"Missing master artifact: {path}")

    for slug, expected in EXPECTED.items():
        project = ROOT / "projects" / slug
        for required in (project / "README.md",
                         project / "docs" / f"{slug}_execution_guide.md",
                         project / "docs" / f"{slug}_execution_guide.docx",
                         project / "docs" / f"{slug}_execution_guide.pdf",
                         project / "config" / "assays.tsv",
                         project / "config" / "project.env.example"):
            if not required.is_file() or required.stat().st_size == 0:
                fail(f"Missing required project file: {required}")

        shell_dir = project / "pipeline_raw_reads_to_counts"
        shell_scripts = sorted(shell_dir.glob("[1-6]_*.sh"))
        if [int(p.name[0]) for p in shell_scripts] != list(range(1, 7)):
            fail(f"Broken shell sequence for {slug}: {[p.name for p in shell_scripts]}")
        for script in shell_scripts:
            text = script.read_text(encoding="utf-8")
            if not text.startswith("#!/usr/bin/env bash\n"):
                fail(f"Invalid shebang: {script}")
            if "set -euo pipefail" not in text:
                fail(f"Strict mode absent: {script}")
        step1_text = shell_scripts[0].read_text(encoding="utf-8")
        if "read -r run study sample experiment" not in step1_text:
            fail(f"ENA parser does not begin with run_accession for {slug}")
        if "ENA run-report columns changed" not in step1_text:
            fail(f"ENA header guard absent for {slug}")

        r_dir = project / "analysis_metagenomics_phyloseq"
        numbered = sorted(r_dir.glob("[0-9][0-9]_*.R"))
        numbers = [int(p.name[:2]) for p in numbered]
        if numbers != list(range(10)):
            fail(f"Broken R sequence for {slug}: {[p.name for p in numbered]}")
        if not (r_dir / expected["step7"]).is_file():
            fail(f"Study-specific R Script 07 absent for {slug}")

        env = (project / "config" / "project.env.example").read_text(encoding="utf-8")
        found_projects = set(re.findall(r"PRJ(?:EB|NA)\d+", env))
        if found_projects != expected["projects"]:
            fail(f"BioProject mismatch for {slug}: {found_projects}")

        with (project / "config" / "assays.tsv").open(encoding="utf-8", newline="") as handle:
            rows = list(csv.DictReader(handle, delimiter="\t"))
        found_primers = {value for row in rows for value in
                         (row["forward_primer"], row["reverse_primer"]) if value != "NA"}
        if found_primers != expected["primers"]:
            fail(f"Primer mismatch for {slug}: {found_primers}")
        if any(row["workflow"] == "amplicon" and row["layout"] != "paired" for row in rows):
            fail(f"Unexpected amplicon layout for {slug}")

        metadata_header = (project / "data" / "analysis_metadata.tsv").read_text(encoding="utf-8").splitlines()[0].split("\t")
        for field in ("sample_id", "analysis_id", "run_accession", "assay", "experimental_unit_id"):
            if field not in metadata_header:
                fail(f"Metadata schema for {slug} lacks {field}")

        guide_text = (project / "docs" / f"{slug}_execution_guide.md").read_text(encoding="utf-8")
        for diagram in (project / "docs" / "diagrams").glob("*.png"):
            if diagram.name not in guide_text:
                fail(f"Guide does not reference diagram: {diagram}")

    print("Repository static validation passed for barley, tomato, and TifTuf.")
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except AssertionError as exc:
        print(f"VALIDATION ERROR: {exc}", file=sys.stderr)
        raise SystemExit(1)
