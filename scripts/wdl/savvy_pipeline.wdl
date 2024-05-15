#!
version development

# TODO
# [x] GNGS CONTAINER
# [x] COMPUTING of sample intervals summaries (& stats)
# [] CONTROL SELECTION based on interval summaries
# [x] COMPUTING of savvy coverage bins
# [] VARIABLE LOGIC

workflow savvy {
  input {
    File? savvy_params
    Array[File] bam_or_cram_files
    Array[File]? bam_or_cram_indices
    File? ref_fasta
    File? ref_fasta_index
    String param_d
    String param_trans
    String param_sv
    String param_subset
  }
  # call init_savvyCNV {
  # TODO
  # }
  scatter (sample in bam_or_cram_files) {
    # TODO: CACHED COVERAGE
    call savvy_bin_coverage {
      input:
        bam = sample,
        ref_fasta = ref_fasta,
        ref_fai = ref_fasta_index
    }
  }

  call savvy_select_controls {
    input:
      d = param_d,
      coverage_bins = savvy_bin_coverage.coverage_bin
  }

  scatter (coverage_bin in savvy_bin_coverage.coverage_bin) {
    call savvy_call_cnvs {
      input:
        d = param_d,
        trans = param_trans,
        sv = param_sv,
        subset = param_subset,
        coverage_bins = coverage_bin,
        control_summary = savvy_select_controls.control_summary
    }
  }

  output {
    Array[File] savvy_cnvs = savvy_call_cnvs.savvy_cnvs
    File control_summary = savvy_select_controls.control_summary
  }
}

task savvy_bin_coverage {

  input {
    File bam
    File? ref_fasta
    File? ref_fai
  }

  String bamBaseName = basename(bam, ".bam")

  output {
    File coverage_bin = bamBaseName + ".coverageBinner"
  }

  command {
    java -Xmx1g CoverageBinner -R ${ref_fasta} ${bam} > ${bamBaseName}.coverageBinner
  }

  runtime {
    cpu: 1
    memory: "2 GiB"
    docker: 'australia-southeast1-docker.pkg.dev/cpg-common/images-dev/savvy-cnv:latest'
  }

}

task savvy_select_controls {

  input {
    String d
    Array[File] coverage_bins
  }

  output {
    File control_summary = 'savvy.control_select.summary'
  }

  command {
    java -Xmx16g SelectControlSamples -${d} 800 ~{sep=" " coverage_bins} >savvy.control_select.summary
  }

  runtime {
    cpu: 1
    memory: "16 GiB"
    docker: 'australia-southeast1-docker.pkg.dev/cpg-common/images-dev/savvy-cnv:latest'
  }

}

task savvy_call_cnvs {

  input {
    String d
    String trans
    String sv
    String subset
    File coverage_bins
    File control_summary
  }
  
  String baseName = basename(coverage_bins, ".coverageBinner")

  output {
    File savvy_cnvs = baseName + ".savvy_cnvs.tsv"
    File log_files = baseName + ".log_messages.txt"
  }

  command {
    java SavvyCNV -data -d ${d} -trans ${trans} -sv ${sv} -case ${coverage_bins} -control `java -Xmx24g SelectControlSamples -subset ${subset} -summary ${control_summary}` >${baseName}.savvy_cnvs.tsv
  }

  runtime {
    cpu: 1
    memory: "16 GiB"
    docker: 'australia-southeast1-docker.pkg.dev/cpg-common/images-dev/savvy-cnv:latest'
  }

}