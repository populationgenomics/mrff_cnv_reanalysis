#!/usr/bin/env python3

"""
An analysis runner to test the savvy-cnv container.
"""

from cpg_utils.config import get_config
from cpg_utils.hail_batch import output_path
from cpg_workflows.batch import get_batch  # pipeline code, will be available in analysis-runner jobs
from analysis_runner.cromwell import (
    run_cromwell_workflow_from_repo_and_get_outputs,
    CromwellOutputType,
)
import click

#@click.command()
#@click.argument('bam_or_cram_files', type=click.Path(exists=True))
#@click.argument('bam_or_cram_indices', type=click.Path(exists=True))
#@click.argument('savvy_params', type=click.Path(exists=True))
#def main(bam_or_cram_files, bam_or_cram_indices, savvy_params):
def main():
    """
    Run the savvy workflow and collect outputs
    """

    batch = get_batch('run the savvy-cnv workflow')
    _config = get_config()

    submit_j, workflow_outputs = run_cromwell_workflow_from_repo_and_get_outputs(
        b=batch,
        driver_image=get_config()['workflow']['driver_image'],
        job_prefix='savvycnv_pipeline_test',
        workflow='savvy_pipeline.wdl',
        cwd='scripts/wdl',
        input_dict = get_config()['cromwell_args'],
        outputs_to_collect={
            'savvy_cnv_calls': CromwellOutputType.single('savvy.savvy_cnvs')
            # '2nd_out_file': List of savvy coverage bins
        },
        libs=[],
        output_prefix=output_path('savvycnv', 'tmp'),
        dataset=get_config()['workflow']['dataset'],
        #access_level=get_config()['workflow']['access_level'],
        copy_outputs_to_gcp=True
    )

    # should contain one single Resource Group
    # temporary in-batch Hail file, lost after completion unless persisted
    print(workflow_outputs)

    # print_job = batch.new_job('cat the output to terminal')
    # print_job.command(f"cat {workflow_outputs['out_file']}")
    # print_job.depends_on(submit_j)

    batch.run(wait=False)

    # batch.write_output(workflow_outputs['out_file'], output_path('hello_wdl.txt'))


if __name__ == '__main__':
    main()
