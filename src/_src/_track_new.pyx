# Enable function annotations.
# cython: binding=True
"""
C interface to intercept calls to fork and clone.
"""
import ctypes
import errno
import inspect
import logging
import os

from collections import namedtuple
from ctypes import CFUNCTYPE
from functools import partial
from io import BytesIO
from itertools import chain

cimport plthook

from contextlib import contextmanager
from cpython.exc cimport PyErr_Format
from ffcall.callback cimport alloc_callback
from libc.stdint cimport uint16_t, uint32_t, uint64_t
from libc.stdlib cimport malloc
from posix.types cimport pid_t
from posix.types import pid_t
from posix.unistd cimport fork

from .utils cimport write_identity


logger = logging.getLogger(__name__)


__all__ = ['install']


cdef extern from "elf.h":
    ctypedef uint16_t Elf32_Half
    ctypedef uint16_t Elf64_Half

    ctypedef uint32_t Elf32_Word
    ctypedef uint32_t Elf64_Word

    ctypedef uint64_t Elf32_Xword
    ctypedef uint64_t Elf64_Xword

    ctypedef uint32_t Elf32_Addr
    ctypedef uint64_t Elf64_Addr

    ctypedef uint32_t Elf32_Off
    ctypedef uint64_t Elf64_Off

    ctypedef struct Elf32_Ehdr:
        Elf32_Off e_phoff
        Elf32_Half e_ehsize
        Elf32_Half e_phentsize
        Elf32_Half e_phnum

    ctypedef struct Elf64_Ehdr:
        Elf64_Off e_phoff
        Elf64_Half e_ehsize
        Elf64_Half e_phentsize
        Elf64_Half e_phnum

    ctypedef struct Elf32_Phdr:
        Elf32_Word p_type
        Elf32_Addr p_vaddr
        Elf32_Word p_memsz

    ctypedef struct Elf64_Phdr:
        Elf64_Word p_type
        Elf64_Addr p_vaddr
        Elf64_Xword p_memsz


DEF PT_LOAD = 1


ctypedef fused Elf_Ehdr:
    Elf32_Ehdr
    Elf64_Ehdr


ctypedef fused Elf_Phdr:
    Elf32_Phdr
    Elf64_Phdr


ctypedef pid_t (*fork_type)()


ELF_MAGIC = b'\x7fELF'


def get_view(start, length):
    with open('/proc/self/mem', 'rb') as f:
        f.seek(start)
        return f.read(length)


def get_process_maps():
    """Retrieve process map sections.
    """
    with open('/proc/self/maps', 'r', encoding='utf-8') as f:
        lines = f.readlines()

    for line in lines:
        addresses, protection, rest = line.split(maxsplit=2)
        if not protection.startswith('r'):
            continue

        start, end = [int(v, 16) for v in addresses.split('-')]
        length = end - start
        if '[vsyscall]' in rest:
            # Skip since the offset is larger than what can be represented with ssize_t.
            # Attempting to seek to location in memory fails with EIO.
            continue

        if '[vvar]' in rest:
            # Skip due to EIO.
            continue

        try:
            view = get_view(start, length)
        except:
            logging.exception(f'Error reading {line}')
            raise
        else:
            # TODO: Lazy-evaluated bytes objects.
            yield start, BytesIO(view)


def get_libs():
    for offset, mem in get_process_maps():
        if mem.read(4) != ELF_MAGIC:
            continue
        logger.debug('Found ELF at offset %d', offset)
        yield offset, mem


def get_lib_pointer(offset, lib):
    """Get some valid pointer in the library to pass to dladdr.
    """
    # TODO: 32-bit.
    lib.seek(4)
    data = lib.read(sizeof(Elf64_Ehdr))
    cdef Elf64_Ehdr * e_hdr = <Elf64_Ehdr *>(<char *>data)
    phoff = e_hdr.e_phoff
    phnum = e_hdr.e_phnum
    phentsize = e_hdr.e_phentsize
    cdef Elf64_Phdr * p_hdr = NULL
    for pos in range(phoff, phoff + phnum * phentsize, phentsize):
        lib.seek(pos)
        data = lib.read(phentsize)
        p_hdr = <Elf64_Phdr *>(<char *>data)
        if p_hdr.p_type == PT_LOAD and p_hdr.p_memsz != 0:
            return offset + p_hdr.p_vaddr


def _fail(msg):
    raise RuntimeError(f'{msg} failed due to: {plthook.plthook_error()}')


ctypedef struct CallbackInfo:
    void * callback
    """Callback function that should be invoked to get the original
    behavior.
    """
    void * address_callback


cdef pid_t my_fork(CallbackInfo * info):
    #logger.debug('my_fork()')
    cdef pid_t pid = original_fork()
    if pid == 0:
        write_identity()
    return pid


functions = []


def get_func(cls, wrapped):
    wrapper = cls(wrapped)
    functions.append(wrapper)
    return wrapper


cdef class Func:
    """
    https://stackoverflow.com/a/51054667/1698058
    """
    cdef object f

    def __cinit__(self, f):
        """
        Args:
            f function annotated with ctypes args.
        """
        # Map annotations to args for CFUNCTYPE.
        args = inspect.getfullargspec(f)
        functype_args = []
        for arg in args.args:
            # Cython function annotations are represented as strings, so it's enough
            # to try and retrieve them from the ctypes module.
            functype_args.append(getattr(ctypes, args.annotations[arg]))

        return_t = args.annotations.get('return')

        ftype = ctypes.CFUNCTYPE(return_t, *functype_args)
        self._wrapper = ftype(f)

    cdef void * ptr(self):
        return <void *>ctypes.addressof(self._wrapper)


def install():
    """Install hooks for fork, clone, and dlopen into all PLTs.
    """
    # 1. If the current PLT entry is the default stub then we cannot naively
    #    replace it - the replacement function needs to be aware of and check
    #    whether the PLT was updated after the first call to the function and
    #    then re-replace the function, otherwise our callback will only get
    #    invoked the first time.
    # 2. Each PLT has its own distinct callback. To accommodate this we
    #    allocate a new function for each shared object into which we are
    #    injecting our handler.
    fork_func_t = CFUNCTYPE(pid_t)

    def fork(data):
        # Extract original function from data and call it.
        # Call write_identity in child.
        # Try to reset the function with plthook_replace in case it was the original stub.
        pass

    cdef plthook.plthook_t * hook

    # Opens executable.
    if plthook.plthook_open(&hook, NULL):
        _fail('plthook.plthook_open')

    if plthook.plthook_replace(hook, "fork", <void *>my_fork, <void **>&original_fork):
        logger.info('plthook.plthook_replace failed with %s', plthook.plthook_error())

    plthook.plthook_close(hook)

    libs = get_libs()

    for offset, lib in get_libs():
        ptr = get_lib_pointer(offset, lib)
        if plthook.plthook_open_by_address(&hook, <void *>ptr):
            logger.info(
                'plthook.plthook_open_by_address ([%d]) failed with %s',
                offset,
                plthook.plthook_error()
            )
            continue

        logger.info('plthook.plthook_open_by_address worked for %d', offset)

        if plthook.plthook_replace(hook, "fork", <void *>my_fork, original_function_out):
            # May be OK if it doesn't reference fork.
            logger.info('plthook.plthook_replace failed with %s', plthook.plthook_error())

        plthook.plthook_close(hook)

    if original_fork == NULL:
        logger.warning('No fork function overridden')
