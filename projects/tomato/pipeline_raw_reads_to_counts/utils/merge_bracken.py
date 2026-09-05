#!/usr/bin/env python3
"""Merge per-sample Bracken species reports into a feature-count matrix."""
import argparse
import csv
from pathlib import Path

parser = argparse.ArgumentParser()
parser.add_argument("--input-dir", required=True, help="Directory of *.species.tsv Bracken reports")
parser.add_argument("--kraken-dir", required=True, help="Directory of the matching *.report Kraken2 reports")
parser.add_argument("--counts", required=True)
parser.add_argument("--taxonomy", required=True)
args = parser.parse_args()


def domains_from_kraken_report(report_path: Path) -> dict[str, str]:
    """Map taxonomy_id -> domain name using the report's own rank-code hierarchy.

    A Kraken2 report is a depth-first traversal of the taxonomy tree; a "D"
    rank-code line starts a new domain (Bacteria, Archaea, Eukaryota, Viruses,
    ...) and every taxon printed after it belongs to that domain until the
    next "D" line. The database is never guaranteed to be bacteria-only, so
    this must be read per report rather than assumed.
    """
    domains: dict[str, str] = {}
    current_domain = None
    with report_path.open(encoding="utf-8") as handle:
        for line in handle:
            fields = line.rstrip("\n").split("\t")
            if len(fields) < 6:
                continue
            rank_code, taxid, name = fields[3], fields[4], fields[5].strip()
            if rank_code == "D":
                current_domain = name
            if current_domain is not None:
                domains[taxid] = current_domain
    return domains


reports = sorted(Path(args.input_dir).glob("*.species.tsv"))
if not reports:
    raise SystemExit("No Bracken *.species.tsv reports found")
samples = [p.name.removesuffix(".species.tsv") for p in reports]

domains: dict[str, str] = {}
for sample in samples:
    kraken_report = Path(args.kraken_dir) / f"{sample}.report"
    if not kraken_report.is_file():
        raise SystemExit(f"Matching Kraken2 report not found for {sample}: {kraken_report}")
    domains.update(domains_from_kraken_report(kraken_report))

counts = {}
names = {}
for sample, path in zip(samples, reports):
    with path.open(newline="", encoding="utf-8") as handle:
        for row in csv.DictReader(handle, delimiter="\t"):
            taxid = row["taxonomy_id"]
            names[taxid] = row["name"]
            counts.setdefault(taxid, {})[sample] = int(row["new_est_reads"])

count_path = Path(args.counts); count_path.parent.mkdir(parents=True, exist_ok=True)
with count_path.open("w", newline="", encoding="utf-8") as handle:
    writer = csv.writer(handle, delimiter="\t")
    writer.writerow(["feature_id", *samples])
    for taxid in sorted(counts, key=lambda x: int(x)):
        writer.writerow([taxid, *[counts[taxid].get(s, 0) for s in samples]])
tax_path = Path(args.taxonomy); tax_path.parent.mkdir(parents=True, exist_ok=True)
with tax_path.open("w", newline="", encoding="utf-8") as handle:
    writer = csv.writer(handle, delimiter="\t")
    writer.writerow(["feature_id", "Kingdom", "Species"])
    for taxid in sorted(names, key=lambda x: int(x)):
        # "NA" when a taxid never appeared under a "D" line in any report
        # (e.g. it fell under Kraken2's "unclassified"/"root" branch) -- an
        # honest gap is preferable to a guessed domain.
        writer.writerow([taxid, domains.get(taxid, "NA"), names[taxid]])
