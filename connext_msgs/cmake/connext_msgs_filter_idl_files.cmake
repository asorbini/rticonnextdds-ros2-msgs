# (c) 2021 Copyright, Real-Time Innovations, Inc.  All rights reserved.
#
# RTI grants Licensee a license to use, modify, compile, and create derivative
# works of the Software.  Licensee has the right to distribute object form
# only for use with RTI products.  The Software is provided "as is", with no
# warranty of any type, including any warranty for fitness for any purpose.
# RTI is under no obligation to maintain or support the Software.  RTI shall
# not be liable for any incidental or consequential damages arising out of the
# use or inability to use the software.

function(connext_msgs_filter_idl_files outvar)
  cmake_parse_arguments(_args
    "" # boolean arguments
    "WORKING_DIRECTORY" # single value arguments
    "BROKEN;EXCLUDE;EXCLUDE_REGEX;INCLUDE;INCLUDE_REGEX;INCLUDE_PACKAGES;VARIANTS" # multi-value arguments
    ${ARGN} # current function arguments
  )

  file(GLOB_RECURSE idl_files "${_args_WORKING_DIRECTORY}/*.idl")

  set(idl_variants_dir "${_args_WORKING_DIRECTORY}/ros2")
  file(GLOB idl_variants "${idl_variants_dir}/*")
  foreach(_variant_dir IN LISTS idl_variants)
    get_filename_component(_variant "${_variant_dir}" NAME)
    string(TOUPPER "${_variant}" _VARIANT)
    message(STATUS "Configure message variant [${_variant}]: ${_variant_dir}")

    if(NOT _args_VARIANTS OR NOT "${_variant}" IN_LIST _args_VARIANTS)
      message(STATUS "Message variant [${_variant}]: DISABLED")
      file(GLOB_RECURSE idl_files_${_variant} "${_variant_dir}/*.idl")
      if(idl_files_${_variant})
        message(STATUS "Remove disabled variant's files: ${_variant}")
        list(REMOVE_ITEM idl_files ${idl_files_${_variant}})
      else()
        message(WARNING "no files associated with variant: ${_variant}")
      endif()
    else()
      message(STATUS "Message variant [${_variant}]: ENABLED")
    endif()
  endforeach()

  set(idl_input)
  foreach(f ${idl_files})
    string(REGEX REPLACE "^${_args_WORKING_DIRECTORY}/" "" idl_rel "${f}")

    get_filename_component(idl_pkg_msg "${idl_rel}" DIRECTORY)
    if(idl_pkg_msg MATCHES "/msg$")
      string(REGEX REPLACE "/msg$" "" idl_pkg "${idl_pkg_msg}")
    elseif(idl_pkg_msg MATCHES "/srv$")
      string(REGEX REPLACE "/srv$" "" idl_pkg "${idl_pkg_msg}")
    elseif(idl_pkg_msg MATCHES "/action$")
      string(REGEX REPLACE "/action$" "" idl_pkg "${idl_pkg_msg}")
    else()
      message(WARNING "neither msg nor srv nor action: ${f}")
    endif()

    get_filename_component(idl_name_ext "${idl_rel}" NAME)
    string(REGEX REPLACE "[.]idl$" "" idl_name "${idl_name_ext}")

    list(FIND _args_BROKEN "${idl_pkg_msg}/${idl_name}" idl_skip)
    if(idl_skip GREATER_EQUAL 0)
      message(STATUS "unsupported: ${idl_pkg_msg}/${idl_name}")
      continue()
    endif()

    list(FIND _args_EXCLUDE "${idl_pkg_msg}/${idl_name}" idl_skip)
    if(idl_skip GREATER_EQUAL 0)
      message(STATUS "excluded: ${idl_pkg_msg}/${idl_name}")
      continue()
    endif()

    if(_args_EXCLUDE_REGEX)
      if("${idl_pkg_msg}/${idl_name}" MATCHES _args_EXCLUDE_REGEX)
        message(STATUS "excluded: ${idl_pkg_msg}/${idl_name}")
        continue()
      endif()
    endif()

    if(_args_INCLUDE)
      list(FIND _args_INCLUDE "${idl_pkg_msg}/${idl_name}" idl_skip)
      if(idl_skip LESS 0)
        message(STATUS "not included: ${idl_pkg_msg}/${idl_name}")
        continue()
      endif()
    endif()

    if(_args_INCLUDE_REGEX)
      if(NOT "${idl_pkg_msg}/${idl_name}" MATCHES "${_args_INCLUDE_REGEX}")
        message(STATUS "not included (regex): ${idl_pkg_msg}/${idl_name}")
        continue()
      endif()
    endif()

    if(_args_INCLUDE_PACKAGES)
      list(FIND _args_INCLUDE_PACKAGES "${idl_pkg}" idl_skip)
      if(idl_skip LESS 0)
        message(STATUS "package disabled: ${idl_pkg_msg}/${idl_name}")
        continue()
      endif()
    endif()

    list(APPEND idl_input "${f}@${idl_pkg_msg}")
  endforeach()

  set(${outvar} "${idl_input}" PARENT_SCOPE)
endfunction()