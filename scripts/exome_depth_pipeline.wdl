#!
version development

workflow exome_depth_pipeline {
  input {
    File target_bed
    File ed_params
    Array[String] chromosomes
    Array[File] bam_or_cram_files
    Array[File]? bam_or_cram_indices
    File reference_fasta
    File? reference_fasta_index
    # String sex
    # String ed_docker
  }
  # call init_exome_depth {
  # TODO
  # }
  scatter (chr in chromosomes) {
    call exome_depth_count_fragments { 
      input: 
        chromosome = chr,
        bam_or_cram_inputs = bam_or_cram_files,
        TARGETS = target_bed,
        REF = reference_fasta,
        container = 'exome-depth'
    }
    call run_exome_depth {
      input:
        chromosome = chr,
        bam_or_cram_inputs = bam_or_cram_files,
        TARGETS = target_bed,
        REF = reference_fasta,
        container = 'exome-depth'
    }
  }
  # merge_ed {
  # TODO
  # }
  output {
    Array[File] counts.tsv
  }
}

task exome_depth_count_fragments {

  input {
    String chromosome
    Array[File] bam_or_cram_inputs
    File TARGETS
    File REF
    String container
  }
  output {
    File fragcounts = "analysis/ed/test.${chromosome}.counts.tsv.gz"
  }
  command <<<
    R -e 'library(ExomeDepth)' << Rscript
        source("$TOOLS/r-utils/cnv_utils.R")

        library(ExomeDepth)

        # Reference sequence
        ref.fasta = "$HGFA"

        # Read the target / covered region
        print(sprintf("Reading target regions for $chr from $target_region_to_use"))

        target.regions = read.bed.ranges(pipe("${exome_depth_split_chrs?"grep '^$chr[^0-9]' $target_region_to_use" : "cat $target_r
egion_to_use"}"))

        # Overlapping targets cause incorrect calls due to ordering applied inside the read counting functions
        # To avoid that, we flatten the target regions here
        targets.flattened = reduce(target.regions)

        # ExomeDepth wants the columns named in a specific way
        target.covered = data.frame(
          chromosome=seqnames(targets.flattened),
          start=start(targets.flattened),
          end=end(targets.flattened),
          name=paste(seqnames(targets.flattened),start(targets.flattened),end(targets.flattened),sep="-")
        )

        # Now we need all the bam files. Generate them from sample names
        ed.samples = c(${sample_list.collect{'"'+it+'"'}.join(",")})

        print(sprintf("Read %d samples",length(ed.samples)))

        # Here we rely on ASSUMPTIONs:  - Single BAM file per sample
        ed.bam.files = c(${sample_list.collect { s -> "'$s'='${sample_info[s].files.bam[0]}'"}.join(",") })

        print(sprintf("Found %d bam files",length(ed.bam.files)))

        # Finally we can call ExomeDepth
        ed.counts <- getBamCounts(bed.frame = target.covered,
                                  bam.files = ed.bam.files,
                                  include.chr = F,
                                  referenceFasta = ref.fasta)

        # Old versions of ExomeDepth return IRanges here, newer versions a pure data frame
        # To be more flexible, convert to data frame here.
        ed.counts = as.data.frame(ed.counts)

        # Note: at this point ed.counts has column names reflecting the file names => convert to actual sample names
        print(sprintf("Successfully counted reads in BAM files"))

        non.sample.columns = (length(colnames(ed.counts)) - length(ed.samples))

        colnames(ed.counts) = c(colnames(ed.counts)[1:non.sample.columns], ed.samples)

        count.file = gzfile('$output.gz','w')
        write.table(ed.counts, file=count.file, row.names=FALSE)
        close(count.file)
    Rscript
  >>>
  runtime {
    cpu: 1
    memory: "4 GiB"
    disks: "local-disk 10 SSD"
    docker: container
  }

}

task run_exome_depth {

  input {
    String chromosome
    Array[File] bam_or_cram_inputs
    File TARGETS
    File REF
    String container
  }
  output {
    File fragcounts = "analysis/ed/test.${chromosome}.exome_depth.tsv"
  }
  command <<<
    R -e 'library(ExomeDepth)' << Rscript
        source("$TOOLS/r-utils/cnv_utils.R")

        library(ExomeDepth)

        # Reference sequence
        ref.fasta = "$HGFA"

        # Read the target / covered region
        print(sprintf("Reading target regions for $chr from $target_region_to_use"))

        target.regions = read.bed.ranges(pipe("${exome_depth_split_chrs?"grep '^$chr[^0-9]' $target_region_to_use" : "cat $target_r
egion_to_use"}"))

        # Overlapping targets cause incorrect calls due to ordering applied inside the read counting functions
        # To avoid that, we flatten the target regions here
        targets.flattened = reduce(target.regions)

        # ExomeDepth wants the columns named in a specific way
        target.covered = data.frame(
          chromosome=seqnames(targets.flattened),
          start=start(targets.flattened),
          end=end(targets.flattened),
          name=paste(seqnames(targets.flattened),start(targets.flattened),end(targets.flattened),sep="-")
        )

        # Now we need all the bam files. Generate them from sample names
        ed.samples = c(${sample_list.collect{'"'+it+'"'}.join(",")})
        ed.test.samples = c(${test_samples.collect{'"'+it+'"'}.join(",")})

        print(sprintf("Read %d samples",length(ed.samples)))


        count.file = gzfile('$input.counts.tsv.gz','r')
        ed.counts = read.table(count.file, header=TRUE, stringsAsFactors=FALSE)
        close(count.file)

        print("Read counts from $input.gz for $chr")

        non.sample.columns = ncol(ed.counts) - length(ed.samples)

        colnames(ed.counts) = c(names(ed.counts)[1:non.sample.columns], ed.samples)

        write(paste("start.p","end.p","type","nexons","start","end","chromosome","id","BF","reads.expected","reads.observed","reads
.ratio","sample",sep="\\t"), "$output.exome_depth.tsv")

        reference.choices = data.frame(list(sample=c(), choices=c()))

        all.reference.stats = NA

        for(ed.test.sample in ed.test.samples) {

            print(sprintf("Processing sample %s", ed.test.sample))

            reference.set.samples = ed.samples[-match(ed.test.sample, ed.samples)]

            sample.reference.counts = as.data.frame(ed.counts[,reference.set.samples])

            ed.test.sample.counts = ed.counts[,ed.test.sample]

            #assign("last.warning", NULL, envir = baseenv())

            print(sprintf("Selecting reference set for %s ...", ed.test.sample ))
            reference.set = select.reference.set(
              test.counts = ed.test.sample.counts,
              reference.counts = as.matrix(sample.reference.counts),
              bin.length = target.covered\$end - target.covered\$start
            )

            sample.reference.stats = as.data.frame(reference.set\$summary.stats)
            sample.reference.stats$sample = ed.test.sample

            if(is.na(all.reference.stats)) {
              all.reference.stats = sample.reference.stats
            }
            else {
              all.reference.stats = rbind(all.reference.stats, sample.reference.stats)
            }

            all_warnings = data.frame(sample=c(), warning=c())
            if(length(warnings()) > 0) {
              all_warnings = rbind(
                all_warnings,
                data.frame(
                  sample=ed.test.sample,
                  warning=paste0(warnings(), ',', collapse = '')
                )
              )
            }

            # Get counts just for the reference set
            reference.set.counts = apply(sample.reference.counts[,reference.set\$reference.choice,drop=F],1,sum)

            print(sprintf("Creating ExomeDepth object ..."))
            sample.ed = new(
              "ExomeDepth",
              test = ed.test.sample.counts,
              reference = reference.set.counts,
              formula = "cbind(test, reference) ~ 1"
            )

            print(sprintf("Calling CNVs ..."))
            sample.cnvs = CallCNVs(
              x = sample.ed,
              transition.probability = $transition_probability,
              chromosome = target.covered\$chromosome,
              start = target.covered\$start,
              end = target.covered\$end,
              name = target.covered\$name,
              expected.CNV.length=$expected_cnv_length
            )

            sample.results = sample.cnvs@CNV.calls
            sample.results$sample = rep(ed.test.sample, nrow(sample.results))

            print(sprintf("Writing results ..."))
            if(nrow(sample.results)>0) {
              write.table(file="$output.exome_depth.tsv", x=sample.results, row.names=F, col.names=F, sep="\\t", append=T)
            }

            if(nrow(all_warnings)>0) {
              message(sprintf("Writing %d warnings to warnings file", nrow(all_warnings)))
            }

            write.table(file="$output.warnings.tsv", x=all_warnings, row.names=F, col.names=F, sep="\t", append=T)
        }

        write.table(file="$output.refstats.tsv", x=all.reference.stats, row.names=F, col.names=T, sep="\t")

        print(sprintf("Finished"))
    Rscript
  >>>
  runtime {
    cpu: 1
    memory: "4 GiB"
    disks: "local-disk 10 SSD"
    docker: container
  }

}

