__author__ = "inodb http://ino.pm"
__license__ = "MIT"


# add all reads to check fastqc
import os

config["fastqc_rules"]["reads"] = {os.path.basename(p):p for p in [v for t in config["bowtie2_rules"]["units"].values() for v in t]}


#CONCOCT_COMMIT="https://raw.githubusercontent.com/inodb/snakemake-workflows/e1c376a46db8d88cd73fd10b00a152fa59c113db/"
CONCOCT_COMMIT = "/glob/inod/github/snakemake-workflows/"
include: CONCOCT_COMMIT + "bio/ngs/rules/quality_control/fastqc.rules"
include: CONCOCT_COMMIT + "common/rules/track_dir.rules"

localrules: track_changes

rule report:
    input:
        "report/fastqc/index.html"
    output:
        "report/index.html"
    shell:
        """
        (
            echo '<html><head><style>body {{ text-align: center }}</style></head><body>'
            echo "<a href='fastqc/index.html'>FastQC Results</a><br />"
            echo '</body></html>'
        ) > {output}
        """

rule track_changes:
    input:
        "results_track.txt"
