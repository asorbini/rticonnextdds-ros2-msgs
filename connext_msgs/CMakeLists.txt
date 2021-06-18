# (c) 2021 Copyright, Real-Time Innovations, Inc. (RTI)
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

cmake_minimum_required(VERSION 3.8)
project(connext_msgs)

# Default to C99
if(NOT CMAKE_C_STANDARD)
  set(CMAKE_C_STANDARD 99)
endif()

# Default to C++14
if(NOT CMAKE_CXX_STANDARD)
  set(CMAKE_CXX_STANDARD 14)
endif()

if(CMAKE_COMPILER_IS_GNUCXX OR CMAKE_CXX_COMPILER_ID MATCHES "Clang")
  add_compile_options(-Wall -Wextra -Wpedantic)
endif()

if(NOT MESSAGE_STANDALONE)
  # Try to load ROS' build system.
  find_package(ament_cmake)

  if(NOT ament_cmake_FOUND)
    if(DEFINED ROS_DISTRO)
      message(FATAL_ERROR "ament_cmake not FOUND. "
        "ROS 2 seems to be loaded in the environment. Set MESSAGE_STANDALONE "
        "if you would like to build this package without ROS.")
    else()
      set(MESSAGE_STANDALONE true)
    endif()
  endif()
endif()

set(LIB_NAME    "${PROJECT_NAME}")

if(NOT MESSAGE_STANDALONE)
  # Since we're building with ROS, load `connext_node_helpers` as a dependency.
  find_package(connext_node_helpers REQUIRED)

  # Also export dependencies through ament
  ament_export_dependencies(connext_node_helpers)
else()
  # If we are not building as a ROS 2 package, then we expect the helpers
  # repository to be specified via CONNEXT_ROS2_HELPERS_DIR.
  # If unspecified, we resort to looking for a clone in the parent of the
  # current source dir.
  if(NOT DEFINED CONNEXT_NODE_HELPERS_DIR)
    get_filename_component(CONNEXT_NODE_HELPERS_DIR
      "${CMAKE_CURRENT_SOURCE_DIR}/../rticonnextdds-ros2-helpers/connext_node_helpers"
      REALPATH)
  endif()

  include(${CONNEXT_NODE_HELPERS_DIR}/cmake/connext_node_helpers.cmake)

  if(MESSAGE_LIBRARY)
    set(LIB_NAME    "${MESSAGE_LIBRARY}")
  endif()
endif()


set(MESSAGE_VARIANTS_DIR    "${CMAKE_CURRENT_SOURCE_DIR}/idl/ros2"
  CACHE INTERNAL "Directory where alternative IDL versions are stored.")

set(MESSAGE_VARIANTS
  basic
  zc
  flat
  flat_zc
  xcdr2
  CACHE INTERNAL "List of alternative IDL versions generated for each ROS 2 type"
)

# Build a list of types which currently don't compile with rtiddsgen.
set(MESSAGE_BROKEN)

# Disable "broken" messages in every variant
foreach(alt ${MESSAGE_VARIANTS})
  foreach(msg
      test_msgs/msg/Arrays
      test_msgs/msg/BoundedSequences
      test_msgs/msg/MultiNested
      test_msgs/msg/UnboundedSequences
      test_msgs/msg/Defaults
      test_msgs/srv/Arrays
      action_tutorials_interfaces/action/Fibonacci
      example_interfaces/action/Fibonacci
      test_msgs/action/Fibonacci)
    list(APPEND MESSAGE_BROKEN "ros2/${alt}/${msg}")
  endforeach()
endforeach()
  
# Disable these "string-heavy" types for variants which convert
# strings to char arrays.
foreach(alt flat zc)
  foreach(msg test_msgs/msg/Strings)
    list(APPEND MESSAGE_BROKEN "ros2/${alt}/${msg}")
  endforeach()
endforeach()

# Disable these types for flat data
# (TODO asorbini: why? would they work at least with flat_zc and @mutable?)
foreach(alt flat flat_zc)
  foreach(msg
    visualization_msgs/msg/InteractiveMarkerInit
    visualization_msgs/msg/InteractiveMarkerUpdate
    visualization_msgs/srv/GetInteractiveMarkers)
    list(APPEND MESSAGE_BROKEN "ros2/${alt}/${msg}")
  endforeach()
endforeach()

list(REMOVE_DUPLICATES MESSAGE_BROKEN)

set(MESSAGE_BROKEN ${MESSAGE_BROKEN}
  CACHE INTERNAL "List of messages which cannot be compiled with rtiddsgen")

set(MESSAGE_INCLUDE_PACKAGES  ${MESSAGE_INCLUDE_PACKAGES}
  CACHE INTERNAL "List of packages to include in the library (all if empty)")

set(MESSAGE_INCLUDE  ${MESSAGE_INCLUDE}
  CACHE INTERNAL "List of messages which should be included in the library (all if empty)")

set(MESSAGE_INCLUDE_REGEX  ${MESSAGE_INCLUDE_REGEX}
  CACHE INTERNAL "Regex to select message which should be included in the library (all if empty)")

set(MESSAGE_EXCLUDE  ${MESSAGE_EXCLUDE}
  CACHE INTERNAL "List of messages which should not be excluded from the library")

set(MESSAGE_EXCLUDE_REGEX  ${MESSAGE_EXCLUDE_REGEX}
  CACHE INTERNAL "Regex to select message which should be excluded from the library (all if empty)")

if(NOT DEFINED MESSAGE_VARIANT_ALL)
  set(MESSAGE_VARIANT_ALL OFF)
endif()
if(NOT DEFINED MESSAGE_VARIANT_BASIC)
  if(CONNEXT_MSGS_NO_LIBRARY)
    set(MESSAGE_VARIANT_BASIC OFF)
  else()
    set(MESSAGE_VARIANT_BASIC ON)
  endif()
endif()

if(MESSAGE_INCLUDE_PACKAGES)
  message(STATUS "Included packages: ${MESSAGE_INCLUDE_PACKAGES}")
else()
  message(STATUS "Included packages: all")
endif()

if(MESSAGE_INCLUDE)
  message(STATUS "Included messages: ${MESSAGE_INCLUDE}")
else()
  message(STATUS "Included messages: all")
endif()

if(MESSAGE_INCLUDE_REGEX)
  message(STATUS "Included messages (regex): ${MESSAGE_INCLUDE_REGEX}")
else()
  message(STATUS "Included messages (regex): all")
endif()

if(MESSAGE_EXLUDE)
  message(STATUS "Excluded messages: ${MESSAGE_EXCLUDE}")
else()
  message(STATUS "Excluded messages: none")
endif()

if(MESSAGE_EXCLUDE_REGEX)
  message(STATUS "Included messages (regex): ${MESSAGE_EXCLUDE_REGEX}")
else()
  message(STATUS "Included messages (regex): all")
endif()

if(MESSAGE_BROKEN)
  message(STATUS "Broken messages: ${MESSAGE_BROKEN}")
else()
  message(STATUS "Broken packages: none")
endif()

set(CONNEXT_MSGS_NO_LIBRARY ${CONNEXT_MSGS_NO_LIBRARY}
  CACHE INTERNAL "Skip building a library with Connext type supports")

if(NOT CONNEXT_MSGS_NO_LIBRARY)
  set(ENABLED_VARIANTS)
  foreach(_variant ${MESSAGE_VARIANTS})
    if(NOT DEFINED MESSAGE_VARIANT_${_VARIANT})
      set(MESSAGE_VARIANT_${_VARIANT} ${MESSAGE_VARIANT_ALL})
    endif()
    set(MESSAGE_VARIANT_${_VARIANT}    ${MESSAGE_VARIANT_${_VARIANT}}
      CACHE BOOL "Whether to build message variant: ${_variant}")
    if(MESSAGE_VARIANT_${_VARIANT})
      list(APPEND ENABLED_VARIANTS "${_variant}")
    endif()
  endforeach()

  # Load CMake helper functions
  include("${CMAKE_CURRENT_SOURCE_DIR}/cmake/connext_msgs_filter_idl_files.cmake")

  # 

  connext_msgs_filter_idl_files(ENABLED_IDLS
    WORKING_DIRECTORY "${CMAKE_CURRENT_SOURCE_DIR}/idl"
    VARIANTS ${ENABLED_VARIANTS}
    BROKEN ${MESSAGE_BROKEN}
    EXCLUDE ${MESSAGE_EXCLUDE}
    EXCLUDE_REGEX ${MESSAGE_EXCLUDE_REGEX}
    INCLUDE ${MESSAGE_INCLUDE}
    INCLUDE_REGEX ${MESSAGE_INCLUDE_REGEX}
    INCLUDE_PACKAGES ${MESSAGE_INCLUDE_PACKAGES}
  )

  connext_generate_typesupport_library(${LIB_NAME}
    IDLS ${ENABLED_IDLS}
    INCLUDES "${CMAKE_CURRENT_SOURCE_DIR}/idl"
    ZEROCOPY
    SERVER
    WORKING_DIRECTORY "${CMAKE_CURRENT_SOURCE_DIR}/idl"
    EXPORT_TYPES_LIST CONNEXT_MSGS_TYPES
  )

  if(NOT MESSAGE_STANDALONE)
    ament_export_libraries(${PROJECT_NAME})
    ament_export_targets(idl_${PROJECT_NAME})

    if(BUILD_TESTING)
      find_package(ament_lint_auto REQUIRED)
      ament_lint_auto_find_test_dependencies()
    endif()
  else()
    install(EXPORT idl_${PROJECT_NAME}
      FILE connext_msgs.cmake
      NAMESPACE connext_msgs::
      DESTINATION cmake)
  endif()
endif()

# Install the IDL directory so that users may generate their own type supports
install(
  DIRECTORY "${CMAKE_CURRENT_SOURCE_DIR}/idl/ros2"
  DESTINATION "share/${PROJECT_NAME}/idl"
)

# Install the CMake helper functions
install(
  FILES
    cmake/connext_msgs_filter_idl_files.cmake
    cmake/connext_msgs_generate_library.cmake
  DESTINATION
    share/${PROJECT_NAME}/cmake
)

if(NOT MESSAGE_STANDALONE)
  ament_package(CONFIG_EXTRAS_POST "${PROJECT_NAME}-extras.cmake.in")
endif()
