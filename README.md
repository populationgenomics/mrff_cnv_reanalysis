# MRFF CNV Reanalysis Project

A simple pipeline that runs the Savvy control selection and CNV calling on exome data.

For a full explanation of how Savvy works, the original repository can be found here:

> https://github.com/rdemolgen/SavvySuite

The aim of this pipeline is to achieve high specificity whilst maintaining sensitivity. The most important parameters affecting this balance are:
+ -trans (transition probability)
+ -d (chunk size)
+ -subset (number of controls to be used)
+ -sv (number of vectors removed for noise reduction; must be less than the number of controls used)

Default values for these have been provided in the example inputs. Based on limited testing, the best values for the subset and sv parameters are heavily dependent on the number and homogeneity of samples run through the pipeline. The higher the number of controls that can be provided, the better, although there is a tradeoff in compute time.

The number of vectors that should be removed depends on how homogenous the subset group of control samples are. If there are (for example) two groups of samples with dictinct coverage profiles (say from different assays), the sv parameter should be set higher to remove this signal. If the samples are homogenous, it should be set lower. It can be difficult to know the most appropriate value in advance; however, the Savvy CNV caller does output the 'noisiness' of each sample to the log files. A good rule of thumb is the noisiness should be in the range of 0.1-0.2. If you tail the log files and see that too many samples are above this range, consider increasing sv. If too many are below Savvy, will struggle to detect anything, so consider decreasing it.

One final note: Although SelectControlSamples need in theory be run only once for an entire batch of samples, the output encodes the paths of the coverage bin files provided to it. Since this pipeline is containerised, those paths will not be uniform from one stage to the next, and so CNV calling will fail to see the controls. One solution might have been to mount the filepaths directly into the container, but as far as I can tell WDL does not provide this option. The current workaround is thus to run it within the same container as the CNV calling, which unfortunately means SelectControlSamples has to be rerun for each sample.
