"""
A driver for UFS_UTILS's orog.
"""

from pathlib import Path

from iotaa import asset, external, task, tasks

from uwtools.drivers.driver import DriverTimeInvariant
from uwtools.drivers.support import set_driver_docstring
from uwtools.strings import STR
from uwtools.utils.file import writable
from uwtools.utils.tasks import filecopy, symlink


class Orog(DriverTimeInvariant):
    """
    A driver for orog.
    """

    # Workflow tasks

    @tasks
    def files_copied(self):
        """
        Files copied for run.
        """
        yield self.taskname("files copied")
        yield [
            filecopy(src=Path(src), dst=self.rundir / dst)
            for dst, src in self.config.get("files_to_copy", {}).items()
        ]

    @tasks
    def files_linked(self):
        """
        Files linked for run.
        """
        yield self.taskname("files linked")
        yield [
            symlink(target=Path(target), linkname=self.rundir / linkname)
            for linkname, target in self.config.get("files_to_link", {}).items()
        ]

    @external
    def grid_file(self):
        """
        The input grid file.
        """
        grid_file = Path(self.config["grid_file"])
        yield self.taskname("Input grid file")
        yield asset(grid_file, grid_file.is_file) if str(grid_file) != "none" else None

    @task
    def input_config_file(self):
        """
        The input config file.
        """
        path = self._input_config_path
        yield self.taskname(str(path))
        yield asset(path, path.is_file)
        yield self.grid_file()
        inputs = self.config.get("old_line1_items")
        if inputs:
            ordered_entries = [
                "mtnres",
                "lonb",
                "latb",
                "jcap",
                "nr",
                "nf1",
                "nf2",
                "efac",
                "blat",
            ]
            inputs = " ".join([str(inputs[i]) for i in ordered_entries])
        outgrid = self.config["grid_file"]
        orogfile = self.config.get("orog_file")
        mask_only = self.config.get("mask", ".false.")
        merge_file = self.config.get("merge", "none")  # string none is intentional
        content = [i for i in [inputs, outgrid, orogfile, mask_only, merge_file] if i is not None]
        with writable(path) as f:
            f.write("\n".join(content))

    @tasks
    def provisioned_rundir(self):
        """
        Run directory provisioned with all required content.
        """
        yield self.taskname("provisioned run directory")
        yield [
            self.files_copied(),
            self.files_linked(),
            self.input_config_file(),
            self.runscript(),
        ]

    # Public helper methods

    @property
    def driver_name(self) -> str:
        """
        The name of this driver.
        """
        return STR.orog

    # Private helper methods

    @property
    def _input_config_path(self) -> Path:
        """
        Path to the input config file.
        """
        return self.rundir / "INPS"

    @property
    def _runcmd(self):
        """
        The full command-line component invocation.
        """
        executable = self.config[STR.execution][STR.executable]
        return "%s < %s" % (executable, self._input_config_path.name)


set_driver_docstring(Orog)
