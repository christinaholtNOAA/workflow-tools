#!/usr/bin/env python3
#pylint: disable=unused-import, unused-variable, unused-argument
# remove these disables once implemented
'''
This file contains the scaffolding for the forecast driver.
It is a python script that will be called by the user to run the
forecast. It will call the other tools in the uwtools package
to do the work. It will also be responsible for setting up the
working directory and moving files around.

See UW documentation for more information:
https://github.com/ufs-community/workflow-tools/wiki/Migrating-Production-Workflows-to-the-Unified-Workflow-using-the-Strangler-Fig-Pattern#component-drivers
'''

import abc


class Driver: # pragma: no cover
    #remove pragma when completed

    '''
    This base class provides the interface to methods used to read in
    a user-provided YAML configuration file, convert it to the required
    config file, fix files, and namelist for a forecast. Subsequent
    methods will be used to stage the input files and run the forecast.

    Attributes
    ----------
    config_path : Path
        The file path to the configuration file to be parsed.

    Methods
    -------
    requirements()
        Recursively parse config and platform files to determine and
        fill in any dependencies.

    resources()
        Determine necessary task objects and fill in resource requirements of each.
        Returns a Config object containing the HPC resources needed.

    validate()
        Validates the objects generated by the driver from the provided
        config and platform files. If the --dry_run flag is provided, complete all
        stages through validation and print results without running the forecast.


    output()
        Holds the knowledge for how to modify a list of output files and
        stages them in the working directory.

    job_card()
        Turns the resources config object into a batch card for the
        configured Task. Can be called from the command line on the front end
        node to show the user what the job card would have looked like.

    Notes
    -------
    Several functions such as create_model_config() and run() are relegated to
    specific forecast drivers. This is because they are unique to the app being
    run and will appropriately parse subsequent stages of the workflow.
    '''

    def __init__(self):

        '''
        Initialize the Forecast driver.

        '''

    @abc.abstractmethod
    def requirements(self):

        ''' Recursively parse config and platform files to determine and
         fill in any dependencies. '''

    @abc.abstractmethod
    def resources(self):

        ''' Determine necessary task objects and fill in resource requirements of each.
         Returns a Config object containing the HPC resources needed.'''

    @abc.abstractmethod
    def validate(self):

        ''' Validates the objects generated by the driver from the provided
        config and platform files. If the --dry_run flag is provided, complete all
        stages through validation and print results without running the forecast.'''

    @abc.abstractmethod
    def output(self):

        ''' Holds the knowledge for how to modify a list of output files and
        stages them in the working directory. Output files usually are
        specific to a given app.'''

    @abc.abstractmethod
    def job_card(self):

        ''' Turns the resources config object into a batch card for the
        configured Task. Can be called from the command line on the front end
        node to show the user what the job card would have looked like.'''