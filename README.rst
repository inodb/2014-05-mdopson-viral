==========================================
M Dopson Viral Metagenomes Project
==========================================
:date: 2014-05-31 00:00
:summary: Viral metagenomes assemblies
:start_date: 2014-03-21
:end_date: 2014-09-31

Performing assemblies, mappings and some analysis for viral metagenomes. It
uses a lot of the `metassemble`_ scripts

**UPDATE 2014-09** Started doing binning with CONCOCT as well. Selecting only those bins which have no
microbial Single Copy Genes (SCGs).


Google docs
===========
- `Assembly stats`_
- `Mapping stats`_


FastQC
=====================

Ran FastQC on all reads on the login node

.. code-block:: bash

    snakemake -j 16 --debug --configfile config.json --directory results -s Snakefile  -np --debug fastqc_all

FastQC showed that reads contained Illumina adapters. Previously done assemblies did as well. This was confirmed by grepping for 
adapters supplied with trimmomatic:

.. code-block:: bash

    cd /proj/b2013127/nobackup/projects/M.Dopson_13_05/
    for f in /sw/apps/bioinfo/trimmomatic/0.32/milou/adapters/*.fa; do
        echo $f
        cat $f | awk '{if (NR % 2 == 0) {print $0}}' \
            | parallel grep --color=always {} assemblies/P911_101/newbler/454AllContigs.fna
    done
    
Turned out there were adapters in the assemblies from 
``/sw/apps/bioinfo/trimmomatic/0.32/milou/adapters/TruSeq3-PE-2.fa``
    

Trimmomatic
===========
Adapter removal with SeqPrep removed adapters, but there was still bias in the bases at 
the beginning and the end of the reads. Therefore we chose to remove adapters, do 
quality trimming and crop reads with trimmomatic:

.. code-block:: bash

    module load trimmomatic/0.32
    mkdir -p /proj/b2013127/nobackup/projects/M.Dopson_13_05/trimmomatic
    cd !$
    for f in /proj/b2013127/INBOX/M.Dopson_13_05/P911_101/140220_AC3UBFACXX/7_140220_AC3UBFACXX_P911_101_7_140220_AC3UBFACXX_P911_101_1.fastq.gz; do
        outf=$(echo $f | cut -d/ -f6,7)
        mkdir -p $outf
        sbatch -A b2014227 -t 1-00:00:00 -p core -n 1 -J trimmomatic_$outf --output=$outf-slurm.out \
            ~/bin/sbatch_job time java -jar /sw/apps/bioinfo/trimmomatic/0.32/milou/trimmomatic.jar \
            PE --phred33 $f ${f/_1.fa/_2.fa} $outf/$(basename $f .fastq.gz).trimmomatic.fastq.gz \
            $outf/$(basename $f _1.fastq.gz).single.fwd.trimmomatic.fastq \
            $outf/$(basename $f _1.fastq.gz)_2.trimmomatic.fastq.gz  \
            $outf/$(basename $f _1.fastq.gz).single.rev.trimmomatic.fastq \
            ILLUMINACLIP:/sw/apps/bioinfo/trimmomatic/0.32/milou/adapters/TruSeq3-PE-2.fa:2:30:10 \
            LEADING:3 TRAILING:3 SLIDINGWINDOW:4:15 MINLEN:36
    done

FastQC after trimmomatic
========================

Assemblies
============
Performed assemblies with Ray on `Lindgren`_ over kmers 31 to 81 with a stepsize of 10. First copied the files:

.. code-block:: bash

    rsync -va xxxx@xxxx.xxxx.xxx:/proj/b2013127/INBOX/M.Dopson_13_05/ .

Directory structure like that:

.. code-block:: bash
    
    $ ls
    assemblies
    P911_101
    P911_102
    P911_103
    P911_104
    P911_105
    P911_106

First did assemblies for P911_101, P911_102 and P911_106:

.. code-block:: bash
    
    cd assemlies
    for d in ../P911_10{1,2,6}; do
        mkdir -p ${d##.*/} && cd ${d##.*/}
        for k in `seq 31 10 81`; do
            qsub  -V -d `pwd` -o ray-$k-pbs.out -l procs=2048,walltime=24:00:00 \
                -v QSUB_ARGUMENTS="aprun -n 2048 Ray -k $k -o out_$k -p ../$d/*/4_*.fastq.gz -p ../$d/*/7_*.fastq.gz" \
                /cfs/klemming/nobackup/i/inodb/github/metassemble/bin/wrapper_jobscript.pbs
        done
        cd ..
    done

It uses two libraries, since those were resequenced. The wrapper_jobscript
executes whatever is in the ``QSUB_ARGUMENTS`` variable. Similarly for
P911_103, P911_104, P911_105, but with one library:

.. code-block:: bash

    for d in ../P911_10{3,4,5}; do
        reads=( $d/*/5_*.fastq.gz )
        mkdir -p ${d##.*/} && cd ${d##.*/}
        for k in `seq 31 10 81`; do
            qsub  -V -d `pwd` -o ray-$k-pbs.out -l procs=2048,walltime=24:00:00 \
            -v QSUB_ARGUMENTS="aprun -n 2048 Ray -k $k -o out_$k -p ../$d/*/5_*.fastq.gz" \
            /cfs/klemming/nobackup/i/inodb/github/metassemble/bin/wrapper_jobscript.pbs
        done
        cd ..
    done

Copied the files back to the original server:

.. code-block:: bash

    rsync -va assemblies xxxx@xxx:/proj/b2013127/nobackup/projects/M.Dopson_13_05/

Then combined the different kmer assemblies using Newbler:

.. code-block:: bash
    
    cd /proj/b2013127/nobackup/projects/M.Dopson_13_05/assemblies
    for dir in P911_{101,102,103,104,105,106}; do
        cd $dir
        sbatch --output=newbler-slurm.out -J merge-dopson -A b2013127 -t 2-00:00:00 -p core -n 8 \
            ~/bin/sbatch_job bash -x $METASSEMBLE_DIR/scripts/assembly/merge-asm-newbler.sh newbler \ 
            out_*/Contigs.fasta
        cd ..
    done

Which results in the following assemblies:

.. code-block:: bash

    $ ls */newbler/454AllContigs.fna
    P911_101/newbler/454AllContigs.fna  P911_103/newbler/454AllContigs.fna  P911_105/newbler/454AllContigs.fna
    P911_102/newbler/454AllContigs.fna  P911_104/newbler/454AllContigs.fna  P911_106/newbler/454AllContigs.fna

Mapping
======================

After the assemblies all reads were mapped back against every merged assembly:

.. code-block:: bash

    cd /proj/b2013127/nobackup/projects/M.Dopson_13_05/assemblies
    d=`pwd`
    for p in P911_10{1,2,3,4,5,6}; do
        mkdir -p $p/newbler/map
        cd $p/newbler/map
        for s in /proj/b2013127/INBOX/M.Dopson_13_05/P911_*/*/*_1.fastq.gz; do
            mkdir -p ${s##*/}
            cd ${s##*/}
            ls bowtie2/asm_pair-smds.coverage || \
                sbatch -A b2013127 -t 01-00:00:00 -J mdopson-map-$p -p core -n 4 ~/bin/sbatch_job \
                bash $METASSEMBLE_DIR/scripts/map/map-bowtie2-markduplicates.sh -ct 4 $s ${s/_1.fastq/_2.fastq} \
                pair ../454AllContigs.fna asm bowtie2
            cd ..
        done
        cd $d
    done

Maping statistics were generated for all the reads and put on the google docs (`Mapping stats`_). To
get the ``bowtie2`` mapping stats the newest slurm output file was parsed for all assemblies and 
read files and then copied to the google docs.

.. code-block:: bash

     for s in $(ls P911_*/newbler/map/*/slurm-*.out | sort -r | tr '/' ' ' | rev | uniq -f1 | rev | tr ' ' '/' | sort);
     do
        cat $s | awk -v sample=`echo ${s} | cut -d/ -f4` -v OFS="\t" \
        '{
            if ($0 ~ "were paired") {a = $1;} 
            if ($0 ~ ") aligned concordantly 0 times") { b = $1}
            if ($0 ~ ") aligned concordantly exactly 1 time" ) {c = $1}
            if ($0 ~ "aligned concordantly >1 times") { d=$1 }
            if ($0 ~ ") aligned 0 times") {e=$1}
            if ($0 ~ "% overall alignment rate") { f = $1 }
        } END { print sample,a,b,c,d,e,f }'
    done | xclip -sel clip

Same for duplication rate as determined by MarkDuplicates.

.. code-block:: bash

    for s in $(ls P911_*/newbler/map/*/bowtie2/asm_pair-smd.metrics | sort);
    do
        cat $s  | awk '{if ($0 ~ "Unknown Library") {printf "%s%\n", $9}}' | tr '.' ','
    done | xclip -sel clip

Binning
========================

We wanted to run CONCOCT and get only those bins out that don't have any microbial Single Copy Genes. Hopefully these
represent viral bins. Follows the `complete example`_ of the CONCOCT repository.

Cut up the assembly in 10K chunks:

.. code-block:: bash

    cd /proj/b2013127/nobackup/projects/M.Dopson_13_05/assemblies
    for d in P911_10{1,2,3,4,5,6}; do
        mkdir -p $d/newbler/concoct/cut_up_10K
        time python ~inod/glob/src/CONCOCT/scripts/cut_up_fasta.py -c 10000 -o 0 \
            -m $d/newbler/454AllContigs.fna > $d/newbler/concoct/cut_up_10K/contigs_c10K.fa &
    done

Rerun mapping on new contigs:

.. code-block:: bash

    cd /proj/b2013127/nobackup/projects/M.Dopson_13_05/assemblies
    d=`pwd`
    for p in P911_10{1,2,3,4,5,6}; do
        mkdir -p $p/newbler/concoct/map
        cd $p/newbler/concoct/map
        cp ../cut_up_10K/contigs_c10K.fa .
        bowtie2-build contigs_c10K.fa contigs_c10K.fa
        for s in /proj/b2013127/INBOX/M.Dopson_13_05/P911_*/*/*_1.fastq.gz; do
            mkdir -p ${s##*/}
            cd ${s##*/}
            ls bowtie2/asm_pair-smds.coverage || \
                sbatch -A b2013127 -t 01-00:00:00 -J mdopson-map-$p -p core -n 4 ~/bin/sbatch_job \
                bash $METASSEMBLE_DIR/scripts/map/map-bowtie2-markduplicates.sh -ct 4 $s ${s/_1.fastq/_2.fastq} \
                pair ../contigs_c10K.fa asm bowtie2
            cd ..
        done
        cd $d
    done

Generate input tables for CONCOCT:

.. code-block:: bash

    cd /proj/b2013127/nobackup/projects/M.Dopson_13_05/assemblies
    d=`pwd`;
    for p in P911_10{1,2,3,4,5,6}; do
        mkdir -p $p/newbler/concoct/concoct-input
        cd $p/newbler/concoct/concoct-input
        time python ~/glob/src/CONCOCT/scripts/gen_input_table.py \
            --samplenames <(for c in ../map/*/bowtie2/asm_pair-smds.coverage; do echo $c | cut -d/ -f3; done) \
            --isbedfiles ../map/contigs_c10K.fa ../map/*/bowtie2/asm_pair-smds.coverage > concoct_inputtable.tsv
        cut -f1,3-26 concoct_inputtable.tsv > concoct_inputtableR.tsv
        cd $d
    done

Run CONCOCT with different minimum contig lengths:

.. code-block:: bash

    cd /proj/b2013127/nobackup/projects/M.Dopson_13_05/assemblies
    d=`pwd`;
    for p in P911_10{1,2,3,4,5,6}; do
        cd $p/newbler/concoct
        for co in 300 500 700 1000 2000 3000; do
            grep -q 'FINISHED' concoct-output-$co-slurm.out ||
                sbatch -A b2013127 -p core -n 5 -t 1-00:00:00 -J $p-concoct-$co \
                    --output=concoct-output-$co-slurm.out ~/bin/sbatch_job concoct \
                    -l $co -c 400 -k 4 --coverage_file concoct-input/concoct_inputtableR.tsv \
                    --composition_file map/contigs_c10K.fa -b concoct-output-$co/
        done
        cd $d
    done

Extract fasta in separate bins for all cut offs:

.. code-block:: bash

    cd /proj/b2013127/nobackup/projects/M.Dopson_13_05/assemblies
    d=`pwd`;
    for p in P911_10{1,2,3,4,5,6}; do
        for co in 300 500 700 1000 2000 3000; do
            mkdir -p $p/newbler/concoct/concoct-output-$co/bins/
            python /glob/inod/src/CONCOCT/scripts/extract_fasta_bins.py \
                $p/newbler/concoct/map/contigs_c10K.fa \
                $p/newbler/concoct/concoct-output-$co/clustering_gt$co.csv \
                --output_path $p/newbler/concoct/concoct-output-$co/bins/
        done
        cd $d
    done

Run prodigal and rpsblast for each sample:

.. code-block:: bash

    cd /proj/b2013127/nobackup/projects/M.Dopson_13_05/assemblies
    d=`pwd`;
    for p in P911_10{1,2,3,4,5,6}; do
        cd $p/newbler/concoct
        mkdir -p annotations/cog-annotations/ annotations/proteins/
        sbatch --output=annotations/cog-annotations/rpsblast.out-slurm.out \
            -A b2013127 -J rpsblast_$p -t 1-00:00:00 -p core -n 1 \
            ~/bin/sbatch_job \
            prodigal -a annotations/proteins/contigs_c10K.faa \
            -i map/contigs_c10K.fa -f gff -p meta '>' \
            annotations/proteins/contigs_c10K.gff '&&' \
            rpsblast -outfmt \
            "'6 qseqid sseqid evalue pident score qstart qend sstart send length slen'" \
            -max_target_seqs 1 -evalue 0.001 -query annotations/proteins/contigs_c10K.faa \
            -db '/proj/b2010008/nobackup/database/cog_le/Cog' -out annotations/cog-annotations/rpsblast.out
        cd $d
    done

Generate COGPlots for all samples and cut offs:

.. code-block:: bash

    cd /proj/b2013127/nobackup/projects/M.Dopson_13_05/assemblies
    d=`pwd`;
    for p in P911_10{1,2,3,4,5,6}; do
        mkdir -p $p/newbler/concoct/evaluation-output
        for co in 300 500 700 1000 2000 3000; do
            python /glob/inod/src/CONCOCT/scripts/COG_table.py \
                -b $p/newbler/concoct/annotations/cog-annotations/rpsblast.out \
                -m /glob/inod/src/CONCOCT/scgs/scg_cogs_min0.97_max1.03_unique_genera.txt \
                -c $p/newbler/concoct/concoct-output-$co/clustering_gt$co.csv \
                --cdd_cog_file /glob/inod/src/CONCOCT/scgs/cdd_to_cog.tsv \
                > $p/newbler/concoct/evaluation-output/clustering_gt${co}_scg.tab
            Rscript /glob/inod/src/CONCOCT/scripts/COGPlot.R \
                -s $p/newbler/concoct/evaluation-output/clustering_gt${co}_scg.tab \
                -o $p/newbler/concoct/evaluation-output/clustering_gt${co}_scg.svg
        done
        cd $d
    done

Make a HTML report of all SCG Plots:

.. code-block:: bash

    cd /proj/b2013127/nobackup/projects/M.Dopson_13_05/assemblies
    mkdir -p report
    d=`pwd`;
    (
        echo "<html><head><style>body { text-align: center }</style></head><body>"
        for p in P911_10{1,2,3,4,5,6}; do
            echo "<h1>$p</h1>"
            for co in 300 500 700 1000 2000 3000; do
                echo "<h3>$p cut off $co</h3>"
                mkdir -p report/$p/newbler/concoct/evaluation-output/
                cp $p/newbler/concoct/evaluation-output/clustering_gt${co}_scg.{tab,svg} report/$p/newbler/concoct/evaluation-output/
                echo "<img src=\"$p/newbler/concoct/evaluation-output/clustering_gt${co}_scg.svg\" />"
                echo "<br />"
                echo "<a href=\"$p/newbler/concoct/evaluation-output/clustering_gt${co}_scg.tab\">tsv</a><br />"
                echo -n "Number of clusters with COG hit: "
                cat $p/newbler/concoct/evaluation-output/clustering_gt${co}_scg.tab | \
                    cut -f1,4- | tail -n +2 | py -fx 'sum(map(int, x.split()[1:])) > 0' \
                    | wc -l
                echo "<br />"
                echo -n "Number of clusters without COG hit: "
                cat $p/newbler/concoct/evaluation-output/clustering_gt${co}_scg.tab | \
                    cut -f1,4- | tail -n +2 | py -fx 'sum(map(int, x.split()[1:])) == 0' \
                    | wc -l
                echo "<br />"
            done
            cd $d
        done
        echo "</body></html>"
    ) > report/scg_plots.html


Do a similar BLAST against `POG`_ database to check for viral bins. Run `POG`_ annotations
on all assemblies both HighVQ (Viral Quotient) and all VQ. A Viral Quotient of 1 
indicates it is never found in prokaryotic genomes outside prophage regions:

.. code-block:: bash

    cd /proj/b2013127/nobackup/projects/M.Dopson_13_05/assemblies
    d=`pwd`;
    for p in P911_10{1,2,3,4,5,6}; do
        cd $p/newbler/concoct
        mkdir -p annotations/pog-annotations/ 
        sbatch --output=annotations/pog-annotations/blastp.out-slurm.out \
            -A b2013127 -J poghighvq_blastp_$p -t 1-00:00:00 -p core -n 16 \
            ~/bin/sbatch_job \
            cat annotations/proteins/contigs_c10K.faa '|' \
            parallel --pipe --recstart "'>'" -N10000 \
            blastp -outfmt \
            "\"'6 qseqid sseqid evalue pident score qstart qend sstart send length slen'\"" \
            -num_threads  1 -max_target_seqs 1 -evalue 0.0001 -query - \
            -db /proj/b2010008/nobackup/database/pog/thousandgenomespogs/blastdb/POGseqs_HighVQ \
            '>' annotations/pog-annotations/blastp_highVQ.out
        cd $d
    done
    
    cd /proj/b2013127/nobackup/projects/M.Dopson_13_05/assemblies
    d=`pwd`;
    for p in P911_10{1,2,3,4,5,6}; do
        cd $p/newbler/concoct
        mkdir -p annotations/pog-annotations/ 
        sbatch --output=annotations/pog-annotations/blastp.out-slurm.out \
            -A b2013127 -J pogallvq_blastp_$p -t 1-00:00:00 -p core -n 1 \
            ~/bin/sbatch_job \
            cat annotations/proteins/contigs_c10K.faa '|' \
            parallel --pipe --recstart "'>'" -N10000 \
            blastp -outfmt \
            "\"'6 qseqid sseqid evalue pident score qstart qend sstart send length slen'\"" \
            -num_threads  1 -max_target_seqs 1 -evalue 0.0001 -query - \
            -db /proj/b2010008/nobackup/database/pog/thousandgenomespogs/blastdb/POGseqs \
            '>' annotations/pog-annotations/blastp_allVQ.out
        cd $d
    done
    
Generate the cluster vs POG count tables:

.. code-block:: bash

    cd /proj/b2013127/nobackup/projects/M.Dopson_13_05/assemblies
    d=`pwd`;
    for p in P911_10{1,2,3,4,5,6}; do
        mkdir -p $p/newbler/concoct/evaluation-output
        for co in 300 500 700 1000 2000 3000; do
            python /glob/inod/github/concoct-inodb/scripts/POG_table.py \
                -b $p/newbler/concoct/annotations/pog-annotations/blastp_allVQ.out \
                -c /proj/b2013127/nobackup/projects/M.Dopson_13_05/assemblies/$p/newbler/concoct/concoct-output-$co/clustering_gt$co.csv \
                --protein_pog_file /glob/inod/github/concoct-inodb/pogs/protein_pog.tsv \
                > $p/newbler/concoct/evaluation-output/clustering_gt${co}_pog_allVQ.tab
            python /glob/inod/github/concoct-inodb/scripts/POG_table.py \
                -b $p/newbler/concoct/annotations/pog-annotations/blastp_highVQ.out \
                -c /proj/b2013127/nobackup/projects/M.Dopson_13_05/assemblies/$p/newbler/concoct/concoct-output-$co/clustering_gt$co.csv \
                --protein_pog_file /glob/inod/github/concoct-inodb/pogs/protein_pog.tsv \
                > $p/newbler/concoct/evaluation-output/clustering_gt${co}_pog_highVQ.tab
        done
        cd $d
    done

Generate the POG html plots:

.. code-block:: bash

    cd /proj/b2013127/nobackup/projects/M.Dopson_13_05/assemblies
    d=`pwd`;
    (
        for p in P911_10{1,2,3,4,5,6}; do
            mkdir -p $p/newbler/concoct/evaluation-output
            for co in 300 500 700 1000 2000 3000; do
                echo python /glob/inod/github/concoct-inodb/scripts/POG_plot.py \
                    -c $p/newbler/concoct/evaluation-output/clustering_gt${co}_pog_highVQ.tab \
                    -o $p/newbler/concoct/evaluation-output/clustering_gt${co}_pog_highVQ.html
                echo python /glob/inod/github/concoct-inodb/scripts/POG_plot.py \
                    -c $p/newbler/concoct/evaluation-output/clustering_gt${co}_pog_allVQ.tab \
                    -o $p/newbler/concoct/evaluation-output/clustering_gt${co}_pog_allVQ.html
            done
            cd $d
        done
    ) | parallel

Create a POG HTML file for the report for easy access of the different POG plots:

.. code-block:: bash

    cd /proj/b2013127/nobackup/projects/M.Dopson_13_05/assemblies
    mkdir -p report
    d=`pwd`;
    (
        echo "<html><head><style>body { text-align: center }</style></head><body>"
        for p in P911_10{1,2,3,4,5,6}; do
            echo "<h1>$p</h1>"
            for co in 300 500 700 1000 2000 3000; do
                echo "<h3>$p cut off $co</h3>"
                mkdir -p report/$p/newbler/concoct/evaluation-output/
                cp $p/newbler/concoct/evaluation-output/clustering_gt${co}_pog_{allVQ,highVQ}.{tab,html} report/$p/newbler/concoct/evaluation-output/
                echo "<a href=\"$p/newbler/concoct/evaluation-output/clustering_gt${co}_pog_allVQ.tab\">all VQ tsv</a><br />"
                echo "<a href=\"$p/newbler/concoct/evaluation-output/clustering_gt${co}_pog_allVQ.html\">all VQ html plot</a><br />"
                echo "<a href=\"$p/newbler/concoct/evaluation-output/clustering_gt${co}_pog_highVQ.tab\">high VQ tsv</a><br />"
                echo "<a href=\"$p/newbler/concoct/evaluation-output/clustering_gt${co}_pog_highVQ.html\">high VQ html plot</a><br />"
            done
            cd $d
        done
        echo "</body></html>"
    ) > report/pog_plots.html

Instead of using ``blastp`` for the POG analysis, we now use HMMER to make alignments against HMM profiles of the MSA
of each POG. First we have to build the database:

.. code-block:: bash

    for pog in /proj/b2010008/nobackup/database/pog/thousandgenomespogs/alignments/POG*.aln; do
        hmmbuild /proj/b2010008/nobackup/database/pog/hmmer/3.1b1/profiles/$(basename $pog .aln).hmm $pog
    done
    cat /proj/b2010008/nobackup/database/pog/hmmer/3.1b1/profiles/*.hmm \
        > /proj/b2010008/nobackup/database/pog/hmmer/3.1b1/databases/all_pog.hmm
    hmmpress /proj/b2010008/nobackup/database/pog/hmmer/3.1b1/databases/all_pog.hmm

Then the database can be used to align sequence against HMM profiles:

.. code-block:: bash

    cd /proj/b2013127/nobackup/projects/M.Dopson_13_05/assemblies
    d=`pwd`;
    for p in P911_10{1,2,3,4,5,6}; do
        cd $p/newbler/concoct
        mkdir -p annotations/pog-annotations/ 
        sbatch --output=annotations/pog-annotations/hmmscan_allVQ.out-slurm.out \
            -A b2013127 -J pogall_hmmscan_$p -t 1-00:00:00 -p core -n 16 \
            ~/bin/sbatch_job \
            hmmscan \
            -E 0.0001 \
            --tblout annotations/pog-annotations/hmmer_allVQ.tsv \
            /proj/b2010008/nobackup/database/pog/hmmer/3.1b1/databases/all_pog.hmm \
            annotations/proteins/contigs_c10K.faa \
            '>' annotations/pog-annotations/hmmscan_allVQ.out
        cd $d
    done

Blast all contigs against nr.

.. code-block:: bash

    cd /proj/b2013127/nobackup/projects/M.Dopson_13_05/assemblies
    d=`pwd`
    module load bioinfo-tools blast/2.2.29+
    for p in P911_10{1,2,3,4,5,6}; do
        cd $p/newbler/concoct
        mkdir -p annotations/contig-blast-nt/
        sbatch --output=annotations/contig-blast-nt/blastn-nt-contigs-10K.tsv-slurm.out \
            -A b2013127 -J contig_blast_$p -t 1-00:00:00 -p core -n 16 \
            ~/bin/sbatch_job \
                cat cut_up_10K/contigs_c10K.fa '|' \
                parallel --pipe --recstart "'>'" -N1000 \
                blastn -outfmt \
                "\"'6 qseqid sseqid evalue pident score qstart qend sstart send length slen'\"" \
                -num_threads  1 -max_target_seqs 1 -evalue 0.0001 -query - \
                -db /sw/data/uppnex/blast_databases/nt \
                '>' annotations/contig-blast-nt/blastn-nt-contigs-10K.tsv
        cd $d
    done

Compare bins between samples
============================
Compare bins of one sample with bins of another sample:

.. code-block:: bash
    
    module load bioinfo-tools MUMmer/3.23
    cd /proj/b2013127/nobackup/projects/inod
    mkdir -p planktonic_bacterial_vs_bacterial_from_viral
    files=$(ls /proj/b2013127/nobackup/projects/xiaofen/planktonic/approved_bins/P1163_1{01,02,03,09,10,11}/approved_bins_fasta/*.fa)
    files2=$(ls /proj/b2013127/nobackup/projects/xiaofen/planktonic/bacterial_bins_from_viral/P911_10{1,2,3,4,5,6}/*.fa)
    # store fasta names
    (
        for f in $files; do echo $f | cut -d/ -f9,11 | sed 's/\//_bin_/' | sed 's/.fa//'; done
        for f in $files2; do echo $f | cut -d/ -f9- | sed 's/\//_bin_/' | sed 's/.fa//'; done
    ) > planktonic_bacterial_vs_bacterial_from_viral/fasta_names.txt
    # run on cluster
    sbatch -A b2013127 -n 16 -p core -t 1-00:00:00 -J bac_vs_viral_bac \
        --output=planktonic_bacterial_vs_bacterial_from_viral-slurm.out \
        ~/bin/sbatch_job python ~/glob/github/CONCOCT-dnadiff-matrix/scripts/dnadiff_dist_matrix.py \
        --fasta_names planktonic_bacterial_vs_bacterial_from_viral/fasta_names.txt \
        planktonic_bacterial_vs_bacterial_from_viral $files $files2 \
    > planktonic_bacterial_vs_bacterial_from_viral/dist_matrix.tsv

.. _POG: http://www.ncbi.nlm.nih.gov/COG/
.. _Lindgren: https://www.pdc.kth.se/resources/computers/lindgren
.. _metassemble: https://github.com/inodb/metassemble
.. _Assembly stats: https://docs.google.com/spreadsheet/ccc?key=0Ammr7cdGTJzgdG4tb2tfMGpsX1UxeWlYX0pEaFQ5RGc&usp=drive_web#gid=0
.. _Mapping stats: https://docs.google.com/spreadsheet/ccc?key=0Ammr7cdGTJzgdG4tb2tfMGpsX1UxeWlYX0pEaFQ5RGc&usp=sharing#gid=2
.. _complete example: https://concoct.readthedocs.org/en/latest/complete_example.html
