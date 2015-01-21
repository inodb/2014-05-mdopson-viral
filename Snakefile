__author__ = "inodb http://ino.pm"
__license__ = "MIT"


configfile: "config.json"


import os


# add all reads to check fastqc
config["fastqc_rules"]["reads"] = {os.path.basename(p):p for p in [v for t in config["bowtie2_rules"]["units"].values() for v in t]}
# add all paired reads to run trimmomatic
config["trimmomatic_rules"]["reads"] = config["bowtie2_rules"]["units"]
# add all trimmomatic reads to fastqc
config["fastqc_rules"]["reads"].update(
    {r.replace("/","_"):r for r in expand("trimmomatic/{trim_params}/{reads}_{ext}.fastq.gz",
        reads=config["trimmomatic_rules"]["reads"],
        trim_params=config["trimmomatic_rules"]["trim_params"], ext=["1P","2P","1U","2U"])})
# add all samples and units to ray config from prefered trimmomatic parameters
config["ray_rules"]["samples"] = config["bowtie2_rules"]["samples"]
config["ray_rules"]["units"] = {u:expand("trimmomatic/{trim_params}/{reads}_{ext}.fastq.gz", reads=u, ext=["1P", "2P"], trim_params="TruSeq3-m4-pe30-se10-minlen36") for u in config["bowtie2_rules"]["units"]}
# make merged newbler assemblies of all ray assemblies for each sample
config["assembly_merge_rules"]["merge"] = {sample:expand("assembly/ray/{assembly_params}/{sample}/out_{kmer}/Contigs.fasta",
                                                  assembly_params="default",
                                                  kmer=config["ray_rules"]["kmers"],
                                                  sample=sample) for sample in config["ray_rules"]["samples"]}



#CONCOCT_COMMIT="https://raw.githubusercontent.com/inodb/snakemake-workflows/e1c376a46db8d88cd73fd10b00a152fa59c113db/"
CONCOCT_COMMIT = "/glob/inod/github/snakemake-workflows/"
include: CONCOCT_COMMIT + "bio/ngs/rules/quality_control/fastqc.rules"
include: CONCOCT_COMMIT + "bio/ngs/rules/trimming/trimmomatic.rules"
include: CONCOCT_COMMIT + "bio/ngs/rules/assembly/ray.rules"
include: CONCOCT_COMMIT + "common/rules/track_dir.rules"
include: CONCOCT_COMMIT + "bio/ngs/rules/assembly/merge.rules"

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
