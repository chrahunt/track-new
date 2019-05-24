import multiprocessing
import os
import shutil
import subprocess

from contextlib import contextmanager
from pathlib import Path

import track_new


@contextmanager
def enabled_tracking():
    track_new.install()

    try:
        yield
    finally:
        for p in Path(track_new._pid_dir).glob('*'):
            p.unlink()


def target(q, level):
    q.put(os.getpid())
    if level == 0:
        return
    p = multiprocessing.Process(target=target, args=(q, level - 1,))
    p.start()
    p.join()


def test_descendants_are_tracked():
    num_procs = 5
    q = multiprocessing.Queue()

    with enabled_tracking():
        p = multiprocessing.Process(target=target, args=(q, num_procs - 1))
        p.start()
        pids = []
        for i in range(num_procs):
            pids.append(q.get())

        p.join()

        assert p.exitcode == 0

        tracked_children = track_new.children()

    tracked_pids = sorted(p[0] for p in tracked_children)
    assert sorted(pids) == tracked_pids


def noop():
    pass


def test_immediate_child_processes_are_seen():
    with enabled_tracking():
        pids = []
        for i in range(5):
            p = multiprocessing.Process(target=noop)
            p.start()
            p.join()
            assert p.exitcode == 0, 'Process must have exited cleanly.'
            pids.append(p.pid)
        tracked_procs = track_new.children()

    tracked_pids = [p[0] for p in tracked_procs]
    assert sorted(pids) == sorted(tracked_pids), 'Must have tracked all children.'


def test_distinct_child_processes_are_seen():
    # Given a process run with subprocess.run
    # And tracking is turned on
    # When the list of pids is retrieved
    # Then it will include the sub process.
    ...
