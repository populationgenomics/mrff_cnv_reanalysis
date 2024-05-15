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
      coverage_bins = savvy_bin_coverage.coverage_bin
  }

  scatter (coverage_bin in savvy_bin_coverage.coverage_bin) {
    call savvy_call_cnvs {
      input:
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

task savvy_call_cnvs {

  input {
    File coverage_bins
    File control_summary
  }
  
  String baseName = basename(coverage_bins, ".coverageBinner")

  output {
    File savvy_cnvs = baseName + ".savvy_cnvs.tsv"
  }

  command {
    java SavvyCNV -data -d 800 -trans 0.008 -sv 0 -case ${coverage_bins} -control `java -Xmx24g SelectControlSamples -subset 20 -summary ${control_summary}` >${baseName}.savvy_cnvs.tsv
  }

  runtime {
    cpu: 1
    docker: 'australia-southeast1-docker.pkg.dev/cpg-common/images-dev/savvy-cnv:latest'
    memory: "16 GiB"
  }

}

task savvy_select_controls {

  input {
    Array[File] coverage_bins
  }

  output {
    File control_summary = 'savvy.control_select.summary'
  }

  command {
    java -Xmx24g SelectControlSamples -d 800 ~{sep=" " coverage_bins} >savvy.control_select.summary
  }

  runtime {
    cpu: 1
    #disks: "local-disk 10 SSD"
    docker: 'australia-southeast1-docker.pkg.dev/cpg-common/images-dev/savvy-cnv:latest'
    memory: "16 GiB"
  }

}