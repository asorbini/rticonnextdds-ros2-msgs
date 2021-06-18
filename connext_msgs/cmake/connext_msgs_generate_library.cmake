# (c) 2021 Copyright, Real-Time Innovations, Inc.  All rights reserved.
#
# RTI grants Licensee a license to use, modify, compile, and create derivative
# works of the Software.  Licensee has the right to distribute object form
# only for use with RTI products.  The Software is provided "as is", with no
# warranty of any type, including any warranty for fitness for any purpose.
# RTI is under no obligation to maintain or support the Software.  RTI shall
# not be liable for any incidental or consequential damages arising out of the
# use or inability to use the software.

function(connext_msgs_generate_library libname)
  cmake_parse_arguments(_args
    "" # boolean arguments
    "" # single value arguments
    "BROKEN;EXCLUDE;EXCLUDE_REGEX;INCLUDE;INCLUDE_REGEX;INCLUDE_PACKAGES;VARIANTS" # multi-value arguments
    ${ARGN} # current function arguments
  )

  connext_msgs_filter_idl_files(_library_idls
    WORKING_DIRECTORY "${connext_msgs_IDL_DIR}"
    VARIANTS ${_args_VARIANTS}
    BROKEN ${_args_BROKEN}
    EXCLUDE ${_args_EXCLUDE}
    EXCLUDE_REGEX ${_args_EXCLUDE_REGEX}
    INCLUDE ${_args_INCLUDE}
    INCLUDE_REGEX ${_args_INCLUDE_REGEX}
    INCLUDE_PACKAGES ${_args_INCLUDE_PACKAGES}
  )

  connext_generate_typesupport_library(${libname}
    IDLS ${_library_idls}
    INCLUDES "${connext_msgs_IDL_DIR}"
    WORKING_DIRECTORY "${connext_msgs_IDL_DIR}"
    ZEROCOPY
    SERVER
  )
endfunction()
