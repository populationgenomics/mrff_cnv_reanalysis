#!/usr/bin/env python3

"""
A runner to test the xhmm container. Runs xhmm discover only.
"""

from cpg_utils.config import get_config
from cpg_utils.hail_batch import output_path
from cpg_workflows.batch import get_batch  # pipeline code, will be available in analysis-runner jobs
from analysis_runner.cromwell import (
    run_cromwell_workflow_from_repo_and_get_outputs,
    CromwellOutputType,
)
import click

@click.command()
@click.argument('xhmm_params', type=click.Path(exists=True))
@click.argument('normalised_read_depth_matrix', type=click.Path(exists=True))
@click.argument('orig_read_depth_matrix', type=click.Path(exists=True))
def main(xhmm_params, normalised_read_depth_matrix, orig_read_depth_matrix):
    """
    Run xhmm discover in container and collect outputs
    """

    batch = get_batch('run the xhmm discover workflow')
    _config = get_config()

    submit_j, workflow_outputs = run_cromwell_workflow_from_repo_and_get_outputs(
        b=batch,
        driver_image=get_config()['workflow']['driver_image'],
        job_prefix='xhmm_container_test',
        workflow='xhmm_container_test.wdl',
        cwd='scripts',
        input_dict={
            'xhmm.xhmm_params': xhmm_params,
            'xhmm.normalised_read_depth_matrix': normalised_read_depth_matrix,
            'xhmm.orig_read_depth_matrix': orig_read_depth_matrix
        },
        outputs_to_collect={
            'xcnv_out_file': CromwellOutputType.single('xhmm.xcnv_output_file'),
            'aux_xcnv_out_file': CromwellOutputType.single('xhmm.aux_xcnv_output_file')
        },
        libs=[],
        output_prefix=output_path('xhmm', 'tmp'),
        dataset=get_config()['workflow']['dataset'],
        access_level=get_config()['workflow']['access_level'],
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
