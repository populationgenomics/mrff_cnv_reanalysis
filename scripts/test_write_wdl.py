#!/usr/bin/env python3

"""
another quick and dirty "hello" wdl runner
"""


from cpg_utils.config import get_config
from cpg_utils.hail_batch import output_path
from cpg_workflows.batch import get_batch  # pipeline code, will be available in analysis-runner jobs
from analysis_runner.cromwell import (
    run_cromwell_workflow_from_repo_and_get_outputs,
    CromwellOutputType,
)


def main():
    """
    do the things
    """

    batch = get_batch('run the write hello workflow')

    _config = get_config()
    submit_j, workflow_outputs = run_cromwell_workflow_from_repo_and_get_outputs(
        b=batch,
        driver_image=get_config()['workflow']['driver_image'],
        job_prefix='hello',
        workflow='hello.wdl',
        cwd='scripts',
        input_dict={'hello.inp': 'Hello, Numbnuts!'},
        outputs_to_collect={
            # 'out_file': CromwellOutputType.single('echo.out'),
            'out_string': CromwellOutputType.single('hello.out')
        },
        libs=[],
        output_prefix=output_path('hello_world.txt'),
        dataset=get_config()['workflow']['dataset'],
        access_level=get_config()['workflow']['access_level'],
        copy_outputs_to_gcp=True
    )

    # should contain one single Resource Group
    # temporary in-batch Hail file, lost after completion unless persisted
    print(workflow_outputs)

    print_job = batch.new_job('cat the output to terminal')
    print_job.command(f"cat {workflow_outputs['out_string']}")
    print_job.depends_on(submit_j)

    batch.run(wait=False)

    batch.write_output(workflow_outputs['out_string'], output_path('hello_world.txt'))


if __name__ == '__main__':
    main()
