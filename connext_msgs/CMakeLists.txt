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

if(NOT BUILD_STANDALONE)
  # Try to load ROS' build system.
  find_package(ament_cmake)

  if(NOT ament_cmake_FOUND)
    if(DEFINED ROS_DISTRO)
      message(FATAL_ERROR "ament_cmake not FOUND. "
        "ROS 2 seems to be loaded in the environment. Set BUILD_STANDALONE "
        "if you would like to build this package without ROS.")
    else()
      set(BUILD_STANDALONE true)
    endif()
  endif()
endif()

if(NOT BUILD_STANDALONE)
  # Since we're building with ROS, load `connext_node_helpers` as a dependency.
  find_package(connext_node_helpers REQUIRED)
else()
  # If we are not building as a ROS 2 package, then we expect the helpers
  # repository to be specified via CONNEXT_ROS2_HELPERS_DIR.
  # If unspecified, we resort to looking for a clone in the current source dir.
  if(NOT DEFINED CONNEXT_ROS2_HELPERS_DIR)
    get_filename_component(CONNEXT_NODE_HELPERS_DIR
      "${CMAKE_CURRENT_SOURCE_DIR}/../rticonnextdds-ros2-helpers/connext_node_helpers"
      REALPATH)
  else()
    set("${CONNEXT_ROS2_HELPERS_DIR}/connext_node_helpers")
  endif()

  include(${CONNEXT_NODE_HELPERS_DIR}/cmake/connext_node_helpers.cmake)
endif()

# List of types that don't build with rtiddsgen
set(MESSAGE_BROKEN
  actionlib_msgs/msg/GoalStatusArray
  map_msgs/msg/ProjectedMap
  nav_msgs/msg/OccupancyGrid
  nav_msgs/msg/Odometry
  sensor_msgs/msg/MultiDOFJointState
  test_msgs/msg/Arrays
  test_msgs/msg/BoundedSequences
  test_msgs/msg/Defaults
  test_msgs/msg/MultiNested
  test_msgs/msg/UnboundedSequences
  trajectory_msgs/msg/MultiDOFJointTrajectory
  trajectory_msgs/msg/MultiDOFJointTrajectoryPoint
  visualization_msgs/msg/InteractiveMarker
  visualization_msgs/msg/InteractiveMarkerControl
  visualization_msgs/msg/InteractiveMarkerFeedback
  visualization_msgs/msg/InteractiveMarkerInit
  visualization_msgs/msg/InteractiveMarkerUpdate
  visualization_msgs/msg/Marker
  visualization_msgs/msg/MarkerArray
  CACHE LIST "Messages which cannot be compiled with rtiddsgen")

set(MESSAGE_PACKAGES  ${MESSAGE_PACKAGES}
  CACHE LIST "Message packages to include in the library (all if empty)")

set(MESSAGE_INCLUDE  ${MESSAGE_INCLUDE}
  CACHE LIST "Message which should be included in the library (all if empty)")

set(MESSAGE_EXCLUDE  ${MESSAGE_EXCLUDE}
  CACHE LIST "Message which should not be included in the library")

message(STATUS "Included packages: ${MESSAGE_PACKAGES}")
message(STATUS "Included messages: ${MESSAGE_INCLUDE}")
message(STATUS "Excluded messages: ${MESSAGE_EXCLUDE}")
message(STATUS "Broken messages: ${MESSAGE_BROKEN}")

get_filename_component(pkg_msg_dir "${${pkg}_DIR}/../msg" REALPATH)
file(GLOB_RECURSE idl_files "${CMAKE_CURRENT_SOURCE_DIR}/idl/*.idl")

set(idl_input)
foreach(f ${idl_files})
  string(REGEX REPLACE "^${CMAKE_CURRENT_SOURCE_DIR}/idl/" "" idl_rel "${f}")
  get_filename_component(idl_pkg_msg "${idl_rel}" DIRECTORY)
  string(REGEX REPLACE "/msg$" "" idl_pkg "${idl_pkg_msg}")
  get_filename_component(idl_name_ext "${idl_rel}" NAME)
  string(REGEX REPLACE "[.]idl$" "" idl_name "${idl_name_ext}")

  if(MESSAGE_PACKAGES)
    list(FIND MESSAGE_PACKAGES "${idl_pkg}" idl_skip)
    if(idl_skip LESS 0)
      message(STATUS "package disabled: ${idl_pkg_msg}/${idl_name}")
      continue()
    endif()
  endif()

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

  if(MESSAGE_INCLUDE)
    list(FIND MESSAGE_INCLUDE "${idl_pkg_msg}/${idl_name}" idl_skip)
    if(idl_skip LESS 0)
      message(STATUS "not included: ${idl_pkg_msg}/${idl_name}")
      continue()
    endif()
  endif()

  list(APPEND idl_input "${f}@${idl_pkg_msg}")
endforeach()

connext_generate_typesupport_library(${PROJECT_NAME}
  IDLS ${idl_input}
  INCLUDES ${CMAKE_CURRENT_SOURCE_DIR}/idl
  ZEROCOPY)

if(NOT BUILD_STANDALONE)
  ament_export_libraries(${PROJECT_NAME})
  ament_export_targets(idl_${PROJECT_NAME})

  if(BUILD_TESTING)
    find_package(ament_lint_auto REQUIRED)
    ament_lint_auto_find_test_dependencies()
  endif()

  ament_package()
endif()
