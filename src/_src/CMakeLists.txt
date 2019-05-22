add_library(utils STATIC utils.c)
add_library(track_new::utils ALIAS utils)

target_include_directories(
    utils
    PUBLIC
        ${CMAKE_CURRENT_LIST_DIR}
)

# Library for preload into child processes.
add_library(preload SHARED preload.c)

target_link_libraries(
    preload
    PRIVATE
        dl
        track_new::utils
)

install(
    TARGETS
    preload
    LIBRARY DESTINATION src/track_new/_lib
)

add_library(plthook STATIC plthook.c)
add_library(track_new::plthook ALIAS plthook)

target_link_libraries(
    plthook
    PUBLIC
        track_new::vendor_headers
)

add_library(_track_new MODULE)
add_library(track_new::_track_new ALIAS _track_new)

python_extension_module(_track_new)

target_link_libraries(
    _track_new
    # We don't speecify visibiity because it conflicts with the
    # target_liink_libraries call in python_extension_module.
    #PRIVATE
        track_new::plthook
        track_new::utils
        ffcall::callback_static
)

target_cython_sources(_track_new _track_new.pyx)

install(
    TARGETS
    _track_new
    LIBRARY DESTINATION src/track_new/_lib
)
