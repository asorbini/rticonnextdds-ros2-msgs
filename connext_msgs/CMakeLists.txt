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
else()
  # If we are not building as a ROS 2 package, then we expect the helpers
  # repository to be specified via CONNEXT_ROS2_HELPERS_DIR.
  # If unspecified, we resort to looking for a clone in the current source dir.
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

if(NOT MESSAGE_BROKEN)
  set(MESSAGE_BROKEN
    test_msgs/msg/Arrays
    test_msgs/msg/BoundedSequences
    test_msgs/msg/MultiNested
    test_msgs/msg/UnboundedSequences
    test_msgs/msg/Defaults
    test_msgs/srv/Arrays
    
    action_tutorials_interfaces/action/Fibonacci
    example_interfaces/action/Fibonacci
    test_msgs/action/Fibonacci)
endif()

set(MESSAGE_BROKEN ${MESSAGE_BROKEN}
  CACHE LIST "List of messages which cannot be compiled with rtiddsgen")

set(MESSAGE_PACKAGES  ${MESSAGE_PACKAGES}
  CACHE LIST "List of packages to include in the library (all if empty)")

set(MESSAGE_INCLUDE  ${MESSAGE_INCLUDE}
  CACHE LIST "List of messages which should be included in the library (all if empty)")

set(MESSAGE_INCLUDE_REGEX  ${MESSAGE_INCLUDE_REGEX}
  CACHE LIST "Regex to select message which should be included in the library (all if empty)")

set(MESSAGE_EXCLUDE  ${MESSAGE_EXCLUDE}
  CACHE LIST "List of messages which should not be excluded from the library")

set(MESSAGE_EXCLUDE_REGEX  ${MESSAGE_EXCLUDE_REGEX}
  CACHE LIST "Regex to select message which should be excluded from the library (all if empty)")

if(MESSAGE_PACKAGES)
  message(STATUS "Included packages: ${MESSAGE_PACKAGES}")
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


file(GLOB_RECURSE idl_files "${CMAKE_CURRENT_SOURCE_DIR}/idl/*.idl")

set(idl_input)
foreach(f ${idl_files})
  string(REGEX REPLACE "^${CMAKE_CURRENT_SOURCE_DIR}/idl/" "" idl_rel "${f}")
  get_filename_component(idl_pkg_msg "${idl_rel}" DIRECTORY)
  if(idl_pkg_msg MATCHES "/msg$")
    string(REGEX REPLACE "/msg$" "" idl_pkg "${idl_pkg_msg}")
  elseif(idl_pkg_msg MATCHES "/srv$")
    string(REGEX REPLACE "/srv$" "" idl_pkg "${idl_pkg_msg}")
  elseif(idl_pkg_msg MATCHES "/action$")
    string(REGEX REPLACE "/action$" "" idl_pkg "${idl_pkg_msg}")
  else()
    message(STATUS "neither msg nor srv nor action: ${f}")
  endif()
  get_filename_component(idl_name_ext "${idl_rel}" NAME)
  string(REGEX REPLACE "[.]idl$" "" idl_name "${idl_name_ext}")

  list(FIND MESSAGE_BROKEN "${idl_pkg_msg}/${idl_name}" idl_skip)
  if(idl_skip GREATER_EQUAL 0)
    message(STATUS "unsupported: ${idl_pkg_msg}/${idl_name}")
    continue()
  endif()

  list(FIND MESSAGE_EXCLUDE "${idl_pkg_msg}/${idl_name}" idl_skip)
  if(idl_skip GREATER_EQUAL 0)
    message(STATUS "excluded: ${idl_pkg_msg}/${idl_name}")
    continue()
  endif()

  if(MESSAGE_EXCLUDE_REGEX)
    if("${idl_pkg_msg}/${idl_name}" MATCHES MESSAGE_EXCLUDE_REGEX)
      message(STATUS "excluded: ${idl_pkg_msg}/${idl_name}")
      continue()
    endif()
  endif()

  if(MESSAGE_INCLUDE)
    list(FIND MESSAGE_INCLUDE "${idl_pkg_msg}/${idl_name}" idl_skip)
    if(idl_skip LESS 0)
      message(STATUS "not included: ${idl_pkg_msg}/${idl_name}")
      continue()
    endif()
  endif()

  if(MESSAGE_INCLUDE_REGEX)
    if(NOT "${idl_pkg_msg}/${idl_name}" MATCHES "${MESSAGE_INCLUDE_REGEX}")
      message(STATUS "not included (regex): ${idl_pkg_msg}/${idl_name}")
      continue()
    endif()
  endif()

  if(MESSAGE_PACKAGES)
    list(FIND MESSAGE_PACKAGES "${idl_pkg}" idl_skip)
    if(idl_skip LESS 0)
      message(STATUS "package disabled: ${idl_pkg_msg}/${idl_name}")
      continue()
    endif()
  endif()

  list(APPEND idl_input "${f}@${idl_pkg_msg}")
endforeach()

connext_generate_typesupport_library(${LIB_NAME}
  IDLS ${idl_input}
  INCLUDES ${CMAKE_CURRENT_SOURCE_DIR}/idl
  ZEROCOPY)

if(NOT MESSAGE_STANDALONE)
  ament_export_libraries(${PROJECT_NAME})
  ament_export_targets(idl_${PROJECT_NAME})

  if(BUILD_TESTING)
    find_package(ament_lint_auto REQUIRED)
    ament_lint_auto_find_test_dependencies()
  endif()

  ament_package()
else()
  install(EXPORT idl_${PROJECT_NAME}
    FILE connext_msgs.cmake
    NAMESPACE connext_msgs::
    DESTINATION cmake)
endif()
