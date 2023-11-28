#!
version development

workflow xhmm {
  input {
    # File bam_or_cram
    # File? bam_or_cram_index
    # File reference_fasta
    # File? reference_fasta_index
    File xhmm_params
    File normalised_read_depth_matrix
    File orig_read_depth_matrix
    # String sex
    # String xhmm_docker
  }
  call run_xhmm_discover {
    input:
      # bam_or_cram_file = bam_or_cram
      # bam_or_cram_index = bam_or_cram_index
      # reference_file = reference_fasta
      # reference_index = reference_fasta_index
      xhmm_params_file = xhmm_params
      rd_matrix_normalised = normalised_read_depth_matrix
      rd_matrix_original = orig_read_depth_matrix
      container = 'xhmm'
  }
  output {
    File xcnv_output_file = run_xhmm_discover.xcnv
    File aux_xcnv_output_file = run_xhmm_discover.aux_xcnv
  }
}

task run_xhmm_discover {

  input {
    File xhmm_params_file
    File rd_matrix_normalised
    File rd_matrix_original
    String xcnv_output_file
    String aux_xcnv_output_file
    String container
  }

  output {
      xcnv = 'analysis/xhmm/test.xhmm_discover.xcnv'
      aux_xcnv = 'analysis/xhmm/test.xhmm_discover.aux_xcnv'
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
