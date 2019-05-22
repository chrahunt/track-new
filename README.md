# process-tracker

Process tracker enables tracking creation of child processes.

Usage:

```python
import process_tracker; process_tracker.install()

import os

os.fork()
os.fork()
os.fork()
print(process_tracker.children())
```

Prints a list of tuples with `(pid, create_time)` for each process.

`create_time` can be used to confirm that the current process (if any) with
the given pid is the same as the original. For example:

```python
import process_tracker
import psutil


processes = []
for pid, create_time in process_tracker.children():
    try:
        p = psutil.Process(pid=pid)
    except psutil.NoSuchProcess:
        continue
    if p.create_time() == create_time:
        processes.append(p)

# processes now has the list of active child processes
# psutil itself does a check before sensitive operations that the
# active process create time is the same as when the Process object
# was initialized.
for p in processes:
    p.terminate()
```

# Limitations

1. Only tracks children spawned from dynamically-linked executables.
2. Relies on `LD_PRELOAD` so will not work for setuid/setgid executables.
