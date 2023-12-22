#!
version development

workflow ximmer {
  input {
    Array[File] bam_or_cram_files
    Array[File] bam_or_cram_indices
    File ed_params
    File xhmm_params
    File savvy_params
    File target_bed
    File reference_fasta
    File? reference_fasta_index
    # String sex
    # others?
  }
  # call init {
  # TODO
  # }
  # call create_analysable_target {
  # TODO PROPERLY
  #   input:
  #     TARGETS = target_bed,
  #     samples_names = bam_or_cram_files
  # }
  # if (enable_kmer_normalisation) {
  #   scatter (sample in bam_or_cram_files) {
  #     call compute_kmer_profiles {
  #       input: 
  #         bam = sample
  #     }
  #   }
  # }
  scatter (sample in bam_or_cram_files) {
    # IGNORE OPTIONAL USE OF KMER PROFILES
    call calc_target_covs {
      input:
        TARGETS = target_bed,
        bam = sample
    }
  }
  call calc_combined_correlations {
    input:
      sample_interval_summaries = calc_target_covs.sample_interval_summary,
      samples_stats = calc_target_covs.sample_stats
  }
  call select_controls {
    input:
      input_correlations = calc_combined_correlations.combined_correlations_js,
      control_samples = ???
  }
  # call init_batch {
  # TODO
  # }
  # call caller_stages {
  # TODO
  # }
  # call cnv_reports {
  # TODO
  # }
  call create_cnv_report {
    input:
      TARGETS = target_bed,
      # refgene =,
      # dgv =,
      # ddd =,
      # ed_cnvs =,
      # savvy_cnvs =,
      # xhmm_cnvs =,
      # vcfs =,
      # bams =,
      container = 'gngs'
  }
  call plot_cnv_coverage {
    input:
      # TODO
  }
  output {
    File
  }
}

task init {

  input {
    String container
  }
  command <<<
  >>>
  runtime {
    cpu: 1
    memory: "4 GiB"
    disks: "local-disk 10 SSD"
  }

}

task compute_kmer_profiles {

  input {
    File bam
  }
  output {
    kmer_output_tsv = "common/kmers/${bam}.tsv"
  }
  command <<<
    unset GROOVY_HOME;

    java -Xmx${memory}g -cp $GROOVY_ALL_JAR:$GNGS_JAR \
      gngs.tools.ShearingKmerCounter \
      -i bam \
      -o kmer_output_tsv
  >>>
  runtime {
    cpu: 1
    memory: "4 GiB"
    disks: "local-disk 10 SSD"
    docker: 'gngs'
  }

}

task calc_target_covs {

  input {
    File TARGETS
    File bam
  }

  String bamBaseName = basename(bam, ".bam")
  String memory = '8'
  String GROOVY_ALL_JAR = 'groovy-3.0.10/lib/*'
  String GNGS_JAR = 'groovy-ngs-utils/bin/gngs'

  output {
    sample_stats = "common/rawqc/individual/${bam}.stats.tsv"
    sample_interval_summary = "common/rawqc/individual/${bam}.calc_target_covs.sample_interval_summary"
  }
  
  command {
    java -Xmx${memory}g -cp $GROOVY_ALL_JAR:$GNGS_JAR \
      gngs.tools.Cov \
      -L TARGETS \ # TODO $kmerFlag
      -o /dev/null \
      -samplesummary sample_stats \
      -intervalsummary sample_interval_summary \
      bam
  }
  
  runtime {
    cpu: 1
    memory: "24 GiB"
    disks: "local-disk 10 SSD"
    docker: 'gngs'
  }

}

task calc_combined_correlations {

  input {
    Array[File] sample_interval_summaries
    Array[File] samples_stats
  }
  output {
    File combined_correlations_tsv = 'combined.correlations.tsv'
    File combined_correlations_js = 'combined.correlations.js'
    File combined_covs_js = 'combined.cov.js'
    File combined_coeffv_js = 'combined.coeffv.js'
    File combined_interval_summary = 'combined.sample_interval_summary'
  }
  command {
    JAVA_OPTS="-Xmx24g -Djava.awt.headless=true -noverify" $GROOVY -cp $GNGS_JAR:$XIMMER_SRC $XIMMER_SRC/ximmer/CalculateCombinedStatistics.groovy \
      -corrTSV combined_correlations_tsv \
      -corrJS combined_correlations_js \
      -covJS combined_covs_js \
      -coeffvJS combined_coeffv_js \
      -stats combined_interval_summary \
      -threads 4 \
      sample_interval_summaries \
      samples_stats
  }
  runtime {
    cpu: 1
    memory: "24 GiB"
    disks: "local-disk 10 SSD"
    docker: 'gngs'
  }

}

task select_controls {

  input {
    File input_correlations
    Array[String] control_samples
    String container
  }
  output {
    filtered_controls = 'filtered_controls.txt'
  }
  command <<<
    mkdir -p control_sets

   JAVA_OPTS="-Xmx8g -Djava.awt.headless=true -noverify" $GROOVY -cp $GNGS_JAR:$XIMMER_SRC $XIMMER_SRC/ximmer/FilterControls.groovy \
     -corr input_correlations \
     --outputDirectory control_sets \
     -splitThreshold 0.83 \
     -minimumGroupSize 20 \
     -thresh 0.9 \ # TODO ${control_samples.collect { '-control ' + it}.join(' ')}
     > filtered_controls
  >>>
  runtime {
    cpu: 1
    memory: "8 GiB"
    disks: "local-disk 10 SSD"
    docker: 'gngs'
  }

}

task create_cnv_report {

  input {
    File TARGETS
    File refgene
    File dgv
    File ddd
    File ed_cnvs
    File savvy_cnvs
    File xhmm_cnvs
    Array[File]? vcfs
    Array[File]? bams
    String container
  }
  output {
    cnvs_tsv = ''
    cnvs_json = ''
    cnvs_html = ''
  }
  command {
    JAVA_OPTS="-Xmx12g -noverify" $GROOVY -cp $GNGS_JAR:$XIMMER_SRC:$XIMMER_SRC/../resources:$XIMMER_SRC/../js $XIMMER_SRC/SummarizeCNVs.groovy \
      -target TARGETS ${caller_opts.join(" ")} $refGeneOpts $reportChrFlag ${inputs.vcf.withFlag("-vcf")} ${inputs.vcf.gz.withFlag("-vcf")} \
      -ed ed_cnvs \
      -savvy savvy_cnvs \
      -xhmm xhmm_cnvs \
      -tsv cnvs_tsv \
      -json cnvs_json ${imgpath?"-imgpath "+imgpath.replaceAll('#batch#',batch_name):""} \
      -mergefrac $mergeOverlapFraction \
      -mergeby $cnvMergeMode $dgvFlag $dddOpt $true_cnvs $idMaskOpt $geneFilterOpts $excludeGenesOpts $geneListOpts $minCatOpt $sampleMapParam $samplesOption \
      ${batch_quality_params.join(" ")} \
      -o cnvs_html \
      ${batch_name ? "-name $batch_name" : ""} ${inputs.bam.withFlag('-bam')}
  }
  runtime {
    cpu: 1
    memory: "12 GiB"
    disks: "local-disk 10 SSD"
    # docker: container
  }

}

task  {

  input {
    # TODO
  }
  output {
    # TODO
  }
  command {
    # TODO
  }
  runtime {
    cpu: 1
    memory: "4 GiB"
    disks: "local-disk 10 SSD"
    # docker: container
  }

}