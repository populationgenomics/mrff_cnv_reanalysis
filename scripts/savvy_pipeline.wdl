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
        bam = sample
    }
  }

  call savvy_call_cnvs {
    input:
      coverage_bins = savvy_bin_coverage.coverage_bin,
      container = 'savvy-cnv'
  }

  output {
    File savvy_cnvs = savvy_call_cnvs.savvy_cnvs
  }
}

# task init_savvyCNV {
# TODO
# }

task savvy_bin_coverage {

  input {
    File bam
  }

  String bamBaseName = basename(bam, ".bam")

  output {
    File coverage_bin = "analysis/savvy/" + bamBaseName + ".coverageBinner"
  }

  command {
    mkdir -p analysis/savvy

    java -Xmx1g CoverageBinner ${bam} >  analysis/savvy/${bamBaseName}.coverageBinner
  }

  runtime {
    cpu: 1
    memory: "2 GiB"
    docker: 'savvy-cnv:latest'
  }

}

task savvy_call_cnvs {

  input {
    Array[File] coverage_bins
    String container
  }

  output {
    File savvy_cnvs = 'savvy.cnvs.tsv'
  }

  command {
    java SavvyCNV -data -d 800 -trans 0.008 ~{sep=" " coverage_bins} >> savvy.cnvs.tsv
  }

  runtime {
    cpu: 1
    memory: "16 GiB"
    #disks: "local-disk 10 SSD"
    docker: container
  }

}

