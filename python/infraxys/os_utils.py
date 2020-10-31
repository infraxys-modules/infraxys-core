from infraxys.logger import Logger
import subprocess
import os
import sys


class OsUtils(object):

    logger = Logger.get_logger("OsUtils")

    @staticmethod
    def run_command_over_ssh(hostname, command_line, workdir=None, hide_stdout=False, hide_stderr=False, exit_on_error=False, log_command=True):
        return OsUtils.run_command(f'ssh -k {hostname}', command_line, workdir, hide_stdout, hide_stderr, exit_on_error)

    @staticmethod
    def run_command(command_line, arguments=None, workdir=None, hide_stdout=False, hide_stderr=False,
                    exit_on_error=False, log_command=True, string_for_stdin=None):
        if log_command:
            if arguments:
                OsUtils.logger.debug(f'command_line: {command_line}')
            else:
                OsUtils.logger.debug(f'command_line: {command_line}')

        command_parts = command_line.split()
        if arguments:
            command_parts.append(arguments)

        if workdir:
            os.chdir(workdir)

        stdout = subprocess.PIPE
        stderr = subprocess.PIPE
        stdin = subprocess.PIPE
        #stdin = subprocess.PIPE if string_for_stdin else None

        if hide_stdout or hide_stderr:
            dev_null = open(os.devnull, 'w')
            if hide_stdout:
                stdout = dev_null
            if hide_stderr:
                stderr = dev_null

        process = subprocess.Popen(
            command_parts, stdout=stdout, stderr=stderr, stdin=stdin)
        if string_for_stdin:
            stdout_result = process.communicate(
                input=str.encode(string_for_stdin))[0].decode()
        else:
            stdout_result = process.communicate()[0].decode()

        exitcode = process.returncode
        perror = process.communicate()[1]
        stderr_result = perror.decode() if perror else ''

        if exitcode != 0 and exit_on_error:
            OsUtils.logger.error(
                f'Exit code {exitcode} {stdout_result} {stderr_result}')
            sys.exit(1)

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
            OsUtils.ensure_dir(f'{path}/{extra_dir}',
                               exit_on_error=exit_on_error)
