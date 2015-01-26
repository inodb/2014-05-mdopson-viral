==========================================
M Dopson Viral Metagenomes Project
==========================================
:date: 2014-05-31 00:00
:summary: Viral metagenomes assemblies
:start_date: 2014-03-21
:end_date: 2015-01-31

Performing assemblies, mappings and some analysis for viral metagenomes. This is a repository to
reconstruct the analysis done for this project. Only the *rules* to do the analysis are stored, 
since the actual data is too big to store online.

**UPDATE 2014-09** Started doing binning with CONCOCT as well. Selecting only those bins which have no
microbial Single Copy Genes (SCGs).

**UPDATE 2014-12** Redid full analysis after noticing adapter content in assemblies.

Report
===========
- http://inodb.github.io/2014-05-mdopson-viral/

Install Snakemake
===================
`Snakemake <https://bitbucket.org/johanneskoester/snakemake/wiki/Home>`_ has been used to make the analysis reproducible. Snakemake uses
python3. A common approach for handling Python scripts is to create a virtual
environment for each of them so your modules of different python scripts do not
interfer with each other. Here we use 
`conda <https://store.continuum.io/cshop/anaconda/>`_ to install snakemake:

.. code-block:: bash

    conda create -n py3-snakemake python=3 anaconda
    source activate py3-snakemake
    pip install snakemake


You can deactivate the environment again with:

.. code-block:: bash

    source deactivate
    
Running Snakemake
=================
Most rules can be run locally or submitted through sbatch. For a local run, taking the rule ``fastqc_all`` as an 
example one would do:

.. code-block:: bash

    snakemake -j 16 --debug -p --debug fastqc_all
    
for a run scheduled through sbatch:

.. code-block:: bash

    snakemake --rerun-incomplete --debug -npj 999 --immediate-submit \
        --cluster '/glob/inod/github/snakemake-workflows/scheduling/Snakefile_sbatch.py {dependencies}'
        --directory /glob/inod/github/2014-05-mdopson-viral/results 
        --configfile /glob/inod/github/2014-05-mdopson-viral/config.json
        -s /glob/inod/github/2014-05-mdopson-viral/Snakefile fastqc_all

You can always do a dry-run to just print the commands that will
be run with ``-n``:

.. code-block:: bash

    snakemake -j 16 --debug -np --debug fastqc_all


Directory structure on milou
============================
This repository is at ``/glob/inod/github/2014-05-mdopson-viral``. The
results are all at ``/glob/inod/github/2014-05-mdopson-viral/results`` which
is a symbolic link to ``/proj/b2013127/nobackup/projects/M.Dopson_13_05/adapter-removal``.
The snakemake commands are all run from within the ``/glob/inod/github/2014-05-mdopson-viral/results``
folder, which has symbolic links to this repository, i.e.:

.. code-block:: bash
    
    $ ll config.json config_sbatch.json report Snakefile 
    lrwxrwxrwx 1 inod b2013127 51 Jan 10 17:42 config.json -> /glob/inod/github/2014-05-mdopson-viral/config.json
    lrwxrwxrwx 1 inod b2013127 58 Jan 10 15:22 config_sbatch.json -> /glob/inod/github/2014-05-mdopson-viral/config_sbatch.json
    lrwxrwxrwx 1 inod b2013127 47 Dec 19 15:11 report -> /glob/inod/github/2014-05-mdopson-viral/report/
    lrwxrwxrwx 1 inod b2013127 49 Jan 10 17:42 Snakefile -> /glob/inod/github/2014-05-mdopson-viral/Snakefile


- The ``config.json`` holds configuration settings for the rules (commands) defined in the Snakefile. Think bowtie2 parameters etc.
- The ``config_sbatch.json`` represent the sbatch specific configuration settings such as in how many cores to use and what partition. You will only have to edit this if used on another server than milou.
- The ``report/`` folder holds the git repository that has the latest version of the ``gh-pages`` branch. Whatever is in that branch and pushed to github is shown on the http://inodb.github.io/2014-05-mdopson-viral/ page.
- The ``Snakefile`` has the actual commands that are run.


FastQC
=====================

Ran FastQC on all reads:

.. code-block:: bash

    cd /glob/inod/github/2014-05-mdopson-viral/results
    snakemake --rerun-incomplete --debug -npj 999 --immediate-submit  \
        --cluster '/glob/inod/github/snakemake-workflows/scheduling/Snakefile_sbatch.py {dependencies}'\
        --directory /glob/inod/github/2014-05-mdopson-viral/results \
        --configfile /glob/inod/github/2014-05-mdopson-viral/config.json \
        -s /glob/inod/github/2014-05-mdopson-viral/Snakefile fastqc_all

Generate report with:

.. code-block:: bash

    snakemake -j 1 -p --debug --rerun-incomplete fastqc_report report
    
Turned out there was indeed adapter contamination.
    

Trimmomatic
===========
Removed adapters with trimmomatic through sbatch. Same as before just change the rule name to:

.. code-block:: bash

    trimmomatic_all


FastQC after trimmomatic
========================

Redid FastQC as described before after updating ``config.json`` including report to compare
before and after. Most of the adpater contamination was removed.

Assemblies
==============
Did assemblies with Ray through sbatch over kmers 31 to 81 with a stepsize of 10 on milou:

.. code-block:: bash

    ray_assembly_all
    
Merged the assemblies with Newbler:

.. code-block:: bash

    merge_newbler_all

Generated report locally:

.. code-block:: bash

    assembly_report

Mapping bowtie2
===============
After assembly, mapped all the reads back with bowtie2. Also cut up all assemblies in chunks of 10K
and mapped the reads back, because this is necessary for CONCOCT. One rule does both:

.. code-block::

    concoct_map_10K_all

Generate the report:

.. code-block::

    mapping_report

Run CONCOCT and annotation
==========================
Ran CONCOCT through sbatch on milou with contigs bigger than 500, 700, 1000, 2000 and 3000:

.. code-block::

    concoct_run_10K_all

Predicted proteins with prodigal:

.. code-block::
    
    prodigal_run_all

Align the predicted proteins against the COG database:

.. code-block::

    rpsblast_run_all

CONCOCT binning evaluation
==========================
Generate Single Copy Gene plots for each bin

.. code-block::
    
    concoct_eval_cog_plot_all

Extracted bins with max missing Single Copy Genes of 5 and max 2 multicopy SCG. For each 
sample select the CONCOCT binning that resulted in the highest number of approved bins.

.. code-block::

    concoct_extract_approved_scg_bins_all

Pairwise compare all aproved bins with MUMmer.

.. code-block::

    concoct_dnadiff_dist_matrix

Generate a report of the evaluation

.. code-block::

    concoct_eval_report

Old pre-adapter contamination filtering analysis steps
======================================================
The old pre-adaptar contamination filtering analysis shows similar commands that can be directly pasted 
in the bash terminal instead of using snakemake and might be more easily customizable for some. They 
can be found in an `older version of this repo <https://github.com/inodb/2014-05-mdopson-viral/blob/d981e40c436176762439a14a72e47aeea3775c1f/README.rst>`_

Old Google docs for assemblies with adapter contamination
==========================================================
- `Assembly stats`_
- `Mapping stats`_

.. _POG: http://www.ncbi.nlm.nih.gov/COG/
.. _Lindgren: https://www.pdc.kth.se/resources/computers/lindgren
.. _metassemble: https://github.com/inodb/metassemble
.. _Assembly stats: https://docs.google.com/spreadsheet/ccc?key=0Ammr7cdGTJzgdG4tb2tfMGpsX1UxeWlYX0pEaFQ5RGc&usp=drive_web#gid=0
.. _Mapping stats: https://docs.google.com/spreadsheet/ccc?key=0Ammr7cdGTJzgdG4tb2tfMGpsX1UxeWlYX0pEaFQ5RGc&usp=sharing#gid=2
.. _complete example: https://concoct.readthedocs.org/en/latest/complete_example.html
