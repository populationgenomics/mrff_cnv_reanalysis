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
        ref_fasta = ref_fasta,
        ref_fai = ref_fasta_index
    }
  }

  call savvy_call_cnvs {
    input:
      coverage_bins = savvy_bin_coverage.coverage_bin
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
    File? ref_fasta
    File? ref_fai
  }

  String bamBaseName = basename(bam, ".bam")

  output {
    File coverage_bin = "analysis/savvy/" + bamBaseName + ".coverageBinner"
  }

  command {
    mkdir -p analysis/savvy

    java -Xmx1g CoverageBinner -R ref ${bam} >  analysis/savvy/${bamBaseName}.coverageBinner
  }

  runtime {
    cpu: 1
    memory: "2 GiB"
    docker: 'australia-southeast1-docker.pkg.dev/cpg-common/images-dev/savvy-cnv:latest'
  }

}

task savvy_call_cnvs {

  input {
    Array[File] coverage_bins
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
    docker: 'savvy-cnv:v1.0'
  }

}

