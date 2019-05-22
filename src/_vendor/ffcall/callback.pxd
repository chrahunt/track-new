from .vacall_r cimport va_alist


cdef extern from "callback.h":
    ctypedef int (*callback_t)

    ctypedef void (*callback_function_t)(void*, va_alist)

    callback_t alloc_callback(callback_function_t, void *)
    void free_callback(callback_t)
    int is_callback(void *)
    callback_function_t callback_address(callback_t)
    void * callback_data(callback_t)
