from infraxys.logger import Logger
import subprocess
import os
import sys


class OsUtils(object):

    logger = Logger.get_logger("OsUtils")

    @staticmethod
    def run_command(command_line, workdir=None, hide_stdout=False, hide_stderr=False):
        OsUtils.logger.debug('command_line: ' + command_line)
        command_parts = command_line.split()
        if workdir:
            os.chdir(workdir)

        stdout = subprocess.PIPE
        stderr = subprocess.PIPE

        if hide_stdout or hide_stdout:
            dev_null = open(os.devnull, 'w')
            if hide_stdout:
                stdout = dev_null
            if hide_stderr:
                stderr = dev_null

        process = subprocess.Popen(command_parts, stdout=stdout, stderr=stderr)
        stdout_result = process.communicate()[0].decode()
        stderr_result = process.communicate()[1].decode()
        exitcode = process.returncode
        return exitcode, stdout_result, stderr_result

    @staticmethod
    def ensure_dir(path, extra_dir=None, exit_on_error=True):
        if not os.path.exists(path):
            try:
                os.mkdir(path)
            except Exception as e:
                print(e)
                if exit_on_error:
                    sys.exit(1)

        if extra_dir:
            OsUtils.ensure_dir(f'{path}/{extra_dir}', exit_on_error=exit_on_error)
