"""Own the complete Windows process tree via a named kill-on-close Job Object."""

import ctypes
import sys
from ctypes import wintypes
from typing import Any


class BasicLimits(ctypes.Structure):
    _fields_ = [
        ("process_time", ctypes.c_longlong),
        ("job_time", ctypes.c_longlong),
        ("flags", wintypes.DWORD),
        ("minimum_working_set", ctypes.c_size_t),
        ("maximum_working_set", ctypes.c_size_t),
        ("active_processes", wintypes.DWORD),
        ("affinity", ctypes.c_size_t),
        ("priority", wintypes.DWORD),
        ("scheduling_class", wintypes.DWORD),
    ]


class ExtendedLimits(ctypes.Structure):
    _fields_ = [
        ("basic", BasicLimits),
        ("io_counters", ctypes.c_ulonglong * 6),
        ("process_memory", ctypes.c_size_t),
        ("job_memory", ctypes.c_size_t),
        ("peak_process_memory", ctypes.c_size_t),
        ("peak_job_memory", ctypes.c_size_t),
    ]


def name(execution_id: str) -> str:
    return "Local\\OverFactory-" + execution_id


def kernel() -> Any:
    if sys.platform != "win32":
        raise RuntimeError("Windows Job Objects require Windows")
    api = ctypes.WinDLL("kernel32", use_last_error=True)
    api.CreateJobObjectW.argtypes = [ctypes.c_void_p, wintypes.LPCWSTR]
    api.CreateJobObjectW.restype = wintypes.HANDLE
    api.OpenJobObjectW.argtypes = [wintypes.DWORD, wintypes.BOOL, wintypes.LPCWSTR]
    api.OpenJobObjectW.restype = wintypes.HANDLE
    api.SetInformationJobObject.argtypes = [
        wintypes.HANDLE,
        ctypes.c_int,
        ctypes.c_void_p,
        wintypes.DWORD,
    ]
    api.AssignProcessToJobObject.argtypes = [wintypes.HANDLE, wintypes.HANDLE]
    api.GetCurrentProcess.restype = wintypes.HANDLE
    api.CloseHandle.argtypes = [wintypes.HANDLE]
    return api


def enter(execution_id: str) -> None:
    if sys.platform != "win32":
        raise RuntimeError("Windows Job Objects require Windows")
    api = kernel()
    job = api.CreateJobObjectW(None, name(execution_id))
    if not job:
        raise ctypes.WinError(ctypes.get_last_error())
    limits = ExtendedLimits()
    limits.basic.flags = 0x00002000  # JOB_OBJECT_LIMIT_KILL_ON_JOB_CLOSE
    if not (
        api.SetInformationJobObject(job, 9, ctypes.byref(limits), ctypes.sizeof(limits))
        and api.AssignProcessToJobObject(job, api.GetCurrentProcess())
    ):
        error = ctypes.get_last_error()
        api.CloseHandle(job)
        raise ctypes.WinError(error)
    # Hold this non-inheritable handle until supervisor exit.


def live(execution_id: str) -> bool:
    if sys.platform != "win32":
        raise RuntimeError("Windows Job Objects require Windows")
    api = kernel()
    handle = api.OpenJobObjectW(0x0004, False, name(execution_id))  # JOB_OBJECT_QUERY
    if handle:
        api.CloseHandle(handle)
        return True
    return ctypes.get_last_error() != 2  # ERROR_FILE_NOT_FOUND is the only absent case.
