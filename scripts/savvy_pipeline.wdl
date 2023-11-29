#!
version development

workflow savvy {
  input {
    File? savvy_params
    Array[File] bam_or_cram_files
    Array[File]? bam_or_cram_indices
    # File reference_fasta
    # File? reference_fasta_index
    # String sex
    # String savvy_docker
  }
  # call init_savvyCNV {
  # TODO
  # }
  scatter (sample in bam_or_cram_files) {
    # TODO: CACHED COVERAGE
    call savvy_bin_coverage {
      input:
        bam = sample,
        container = 'savvy-cnv'
    }
  }
  call savvy_call_cnvs {
    input:
      coverage_bins = savvy_bin_coverage.coverage_bin,
      container = 'savvy-cnv'
  }
  output {
    File savvy_cnvs
  }
}

# task init_savvyCNV {
# TODO
# }

task savvy_bin_coverage {

  input {
    File bam
    String container
  }
  output {
    File coverage_bin = "analysis/savvy/${bam}.coverageBinner"
  }
  command <<<
    java -Xmx1g CoverageBinner bam > coverage_bin
  >>>
  runtime {
    cpu: 1
    memory: "4 GiB"
    disks: "local-disk 10 SSD"
    docker: container
  }

}

task savvy_call_cnvs {

  input {
    Array[File] coverage_bins
    String container
  }
  output {
    File savvy_cnvs = 'analysis/savvy/savvy.cnvs.tsv'
  }
  command <<<
    java SavvyCNV -data \
      -d 800 \
      -trans 0.008 \
      coverage_bins \
      >> savvy_cnvs
  >>>
  runtime {
    cpu: 1
    memory: "16 GiB"
    disks: "local-disk 10 SSD"
    docker: container
  }

}

