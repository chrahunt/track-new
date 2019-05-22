include(ExternalProject)

# TODO: Cache download so it doesn't need to happen every time in conjunction with tox...
ExternalProject_Add(
    ffcall
    URL https://ftp.gnu.org/gnu/libffcall/libffcall-2.1.tar.gz
    PREFIX ${CMAKE_CURRENT_BINARY_DIR}/ffcall
    CONFIGURE_COMMAND ${CMAKE_CURRENT_BINARY_DIR}/ffcall/src/ffcall/configure --prefix=<INSTALL_DIR>
    BUILD_COMMAND ${MAKE}
)

function(add_ffcall_library name type path)
    add_library(${name} ${type} IMPORTED GLOBAL)

    target_link_libraries(
        ${name}
        INTERFACE
            ffcall::headers
    )

    set_target_properties(
        ${name}
        PROPERTIES
            IMPORTED_LOCATION ${CMAKE_CURRENT_BINARY_DIR}/ffcall/lib/${path}
    )
endfunction()


add_library(ffcall_headers INTERFACE)
add_library(ffcall::headers ALIAS ffcall_headers)

add_dependencies(ffcall_headers ffcall)

# Hack otherwise non-existent INTERFACE_INCLUDE_DIRECTORIES path causes an error.
# https://stackoverflow.com/a/47358004/1698058
file(MAKE_DIRECTORY "${CMAKE_CURRENT_BINARY_DIR}/ffcall/include")

target_include_directories(
    ffcall_headers
    INTERFACE
        ${CMAKE_CURRENT_BINARY_DIR}/ffcall/include
)


add_ffcall_library(ffcall::avcall SHARED libavcall.so.1.0.1)
add_ffcall_library(ffcall::avcall_static STATIC libavcall.a)
add_ffcall_library(ffcall::callback SHARED libcallback.so.1.0.1)
add_ffcall_library(ffcall::callback_static STATIC libcallback.a)
add_ffcall_library(ffcall::ffcall SHARED libffcall.so.0.0.1)
add_ffcall_library(ffcall::ffcall_static STATIC libffcall.a)
add_ffcall_library(ffcall::trampoline SHARED libtrampoline.so.1.0.1)
add_ffcall_library(ffcall::trampoline_static STATIC libtrampoline.a)
