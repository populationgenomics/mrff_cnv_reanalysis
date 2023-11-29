#!
version development

workflow xhmm {
  input {
    File target_bed
    File reference_fasta
    File? reference_fasta_index
    File xhmm_params
    String min_sample_mean
    # String filter_target_bed
    Array[File] bam_or_cram_files
    Array[File]? bam_or_cram_indices
    # File normalised_read_depth_matrix
    # File orig_read_depth_matrix
    # String sex
    # String xhmm_docker
  }
  # call xhmm_init {
  # TODO: process xhmm params
  # }
  call find_extreme_gc_content {
    input:
      TARGETS = target_bed,
      REF = reference_fasta,
      container = 'GATK'
  }
  call xhmm_count_reads {
    input:
      TARGETS = target_bed,
      bam_or_cram_inputs = bam_or_cram_files,
      container = 'GNGS'
  }
  call xhmm_mean_center {
    input:
      extreme_GC = extremeGC_outfile.find_extreme_gc_content,
      cov_intervals = xhmm_count_reads.interval_cov_outfile,
      min_sample_mean = min_sample_mean,
      container = 'xhmm'
  }
  # call xhmm_merge_coverage {
  # TODO: xhmm --mergeGATKdepths
  # }
  call xhmm_pca {
    input:
      centred_infile = xhmm_mean_center.centered_outfile,
      container = 'xhmm'
  }
  call xhmm_normalize {
    input:
      centred_infile = xhmm_mean_center.centered_outfile,
      PC_in = xhmm_pca.PC_out,
      container = 'xhmm'
  }
  call xhmm_filter_normalized {
    input:
      PC_norm_in = xhmm_normalize.PC_norm_out,
      container = 'xhmm'
  }
  call xhmm_filter_orig {
    input:
      cov_intervals = xhmm_count_reads.interval_cov_outfile,
      orig_excluded_targets = xhmm_mean_center.excluded_targets,
      norm_excluded_targets = xhmm_filter_normalized.norm_excluded_targets,
      orig_excluded_samples = xhmm_mean_center.excluded_samples,
      norm_excluded_samples = xhmm_filter_normalized.norm_excluded_samples,
      container = 'xhmm'
  }
  call xhmm_discover {
    input:
      xhmm_params_file = xhmm_params,
      rd_matrix_normalised = xhmm_filter_normalized.norm_zscored_out,
      rd_matrix_original = xhmm_filter_orig.filtered_interval_summary,
      container = 'xhmm'
  }
  output {
    File xcnv_output_file = run_xhmm_discover.xcnv
    File aux_xcnv_output_file = run_xhmm_discover.aux_xcnv
  }
}

task find_extreme_gc_content {

  input {
    File TARGETS
    File REF
    String container
  }
  output {
    File GC_outfile = 'analysis/xhmm/test.bed.gc.txt'
    File extremeGC_outfile = 'analysis/xhmm/test.bed.extremegc.txt'
  }
  command <<<
    java -jar GenomeAnalysisTK.jar \
      -T GCContentByInterval \
      -L TARGETS \
      -R REF \
      -o GC_outfile
      
    cat GC_outfile | awk '{if (\$2 < 0.1 || \$2 > 0.9) print \$1}' > extremeGC_outfile
  >>>
  runtime {
    cpu: 1
    memory: "3 GiB"
    disks: "local-disk 10 SSD"
    docker: container
  }
  
}

task xhmm_count_reads {

  input {
    File TARGETS
    Array[File] bam_or_cram_inputs
    File rd_matrix_original
    String container
  }
  output {
    File interval_cov_outfile = 'analysis/xhmm/test.merged.sample_interval_summary'
    File perbase_cov_outfile = 'analysis/xhmm/test_per_base.coverage.tsv.bgz'
  }
  command <<<
    java -cp GNGS_JAR gngs.tools.MultiCov \
      -targetmeans interval_cov_outfile \
      -bed TARGETS bam_or_cram_inputs > perbase_cov_outfile
  >>>
  runtime {
    cpu: 1
    memory: "4 GiB"
    disks: "local-disk 10 SSD"
    docker: container
  }

}

task xhmm_mean_center {

  input {
    File extreme_GC
    File cov_intervals
    String min_sample_mean
    String container
  }
  output {
    File centered_outfile = 'analysis/xhmm/test.centered'
    File excluded_targets = 'analysis/xhmm/test.excluded.targets'
    File excluded_samples = 'analysis/xhmm/test.excluded.samples'
  }
  command <<<
    xhmm --matrix -r cov_intervals \
      --centerData \
      --centerType target \
      -o centered_outfile \
      --outputExcludedTargets excluded_targets \
      --outputExcludedSamples excluded_samples \
      --excludeTargets extreme_GC \
      --minTargetSize 10 \
      --maxTargetSize 10000 \
      --minMeanTargetRD 10 --maxMeanTargetRD 1000 \
      --minMeanSampleRD min_sample_mean --maxMeanSampleRD 1000 \
      --maxSdSampleRD 180
  >>>
  runtime {
    cpu: 1
    memory: "4 GiB"
    disks: "local-disk 10 SSD"
    docker: container
  }
}

task xhmm_pca {

  input {
    File centred_infile
    String container
  }
  output {
    File PC_out = 'analysis/xhmm/test.PC.txt'
    File PC_SD_out = 'analysis/xhmm/test.PC_SD.txt'
    File PC_LOADINGS_out = 'analysis/xhmm/test.PC_LOADINGS.txt'
  }
  command <<<
    xhmm --PCA -r centred_infile --PCAfiles # TODO
  >>>
  runtime {
    cpu: 1
    memory: "4 GiB"
    disks: "local-disk 10 SSD"
    docker: container
  }
  
}

task xhmm_normalize {

  input {
    File centred_infile
    File PC_in
    String container
  }
  output {
    File PC_norm_out = 'analysis/xhmm/test.PC.norm.txt'
  }
  command <<<
    xhmm --normalize \
      -r centred_infile \
      --PCAfiles # TODO \
      --normalizeOutput PC_norm_out \
      --PCnormalizeMethod PVE_mean \
      --PVE_mean_factor 0.7
  >>>
  runtime {
    cpu: 1
    memory: "4 GiB"
    disks: "local-disk 10 SSD"
    docker: container
  }
  
}

task xhmm_filter_normalized {

  input {
    File PC_norm_in
    String container
  }
  output {
    File norm_zscored_out = 'analysis/xhmm/test.PC.norm.zscored'
    File norm_excluded_targets = 'analysis/xhmm/test.PC.norm.excluded.samples'
    File norm_excluded_samples = 'analysis/xhmm/test.PC.norm.excluded.targets'
  }
  command <<<
    xhmm --matrix -r PC_norm_in --centerData --centerType sample --zScoreData \
      -o norm_zscored_out \
      --outputExcludedTargets norm_excluded_targets \
      --outputExcludedSamples norm_excluded_samples \
      --maxSdTargetRD 30
  >>>
  runtime {
    cpu: 1
    memory: "4 GiB"
    disks: "local-disk 10 SSD"
    docker: container
  }
  
}

task xhmm_filter_orig {

  input {
    File cov_intervals
    File orig_excluded_targets
    File norm_excluded_targets
    File orig_excluded_samples
    File norm_excluded_samples
    String container
  }
  output {
    File filtered_interval_summary = 'analysis/xhmm/test.filt.sample_interval_summary'
  }
  command <<<
    xhmm --matrix -r cov_intervals \
      --excludeTargets orig_excluded_targets \
      --excludeTargets norm_excluded_targets \
      --excludeSamples orig_excluded_samples \
      --excludeSamples norm_excluded_samples \
      -o filtered_interval_summary
  >>>
  runtime {
    cpu: 1
    memory: "4 GiB"
    disks: "local-disk 10 SSD"
    docker: container
  }
  
}

task xhmm_discover {

  input {
    File xhmm_params_file
    File rd_matrix_normalised
    File rd_matrix_original
    String container
  }
  output {
    File xcnv = 'analysis/xhmm/test.xhmm_discover.xcnv'
    File aux_xcnv = 'analysis/xhmm/test.xhmm_discover.aux_xcnv'
  }
  command <<<
    xhmm --discover \
      -p xhmm_params_file \
      -r rd_matrix_normalised \
      -R rd_matrix_original \
      -c xcnv_output_file \
      -a aux_xcnv_output_file
  >>>
  runtime {
    cpu: 1
    memory: "4 GiB"
    disks: "local-disk 10 SSD"
    docker: container
  }

}
