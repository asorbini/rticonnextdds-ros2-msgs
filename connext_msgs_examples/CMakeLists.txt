cmake_minimum_required(VERSION 3.8)
project(connext_msgs_examples)

# Default to C++14
if(NOT CMAKE_CXX_STANDARD)
  set(CMAKE_CXX_STANDARD 14)
endif()

if(CMAKE_COMPILER_IS_GNUCXX OR CMAKE_CXX_COMPILER_ID MATCHES "Clang")
  add_compile_options(-Wall -Wextra -Wpedantic)
endif()

# find dependencies
find_package(ament_cmake REQUIRED)
find_package(rclcpp REQUIRED)
find_package(rclcpp_components REQUIRED)
# The RTI Connext DDS libraries will be automatically loaded by the dependency
# chain of connext_msgs. You can customize the list of components to be 
# looked up by setting CONNEXTDDS_COMPONENTS (default: "metp").
find_package(connext_msgs REQUIRED)

set(lib_sources)
set(linked_libs RTIConnextDDS::cpp2_api)
set(need_metp false)
if("${connext_msgs_TYPES}" MATCHES ";ros2/std/std_msgs/msg/String;")
  list(APPEND lib_sources
    src/talker.cpp
    src/listener.cpp)
endif()
if("${connext_msgs_TYPES}" MATCHES ";ros2/flat/std_msgs/msg/String;")
  list(APPEND lib_sources
    src/talker_flat.cpp
    src/listener_flat.cpp)
endif()
if("${connext_msgs_TYPES}" MATCHES ";ros2/flat_zc/std_msgs/msg/String;")
  list(APPEND lib_sources
    src/talker_flat_zc.cpp
    src/listener_flat_zc.cpp)
    set(need_metp true)
endif()
if("${connext_msgs_TYPES}" MATCHES ";ros2/zc/std_msgs/msg/String;")
  list(APPEND lib_sources
    src/talker_zc.cpp
    src/listener_zc.cpp)
    set(need_metp true)
endif()
if(NOT lib_sources)
  message(WARNING "required types not enabled, skipping ${PROJECT_NAME}")
  ament_package()
  return()
endif()

if(need_metp)
  list(APPEND linked_libs RTIConnextDDS::metp)
endif()

add_library(${PROJECT_NAME} SHARED ${lib_sources})
ament_target_dependencies(${PROJECT_NAME}
  rclcpp
  rclcpp_components
  connext_msgs)
target_compile_definitions(${PROJECT_NAME}
  PRIVATE "CONNEXT_MSGS_EXAMPLES_BUILDING_DLL")
target_include_directories(${PROJECT_NAME}
  PRIVATE
    ${CMAKE_CURRENT_SOURCE_DIR}/include)
target_link_libraries(${PROJECT_NAME} ${linked_libs})
install(TARGETS ${PROJECT_NAME}
  ARCHIVE DESTINATION lib
  LIBRARY DESTINATION lib
  RUNTIME DESTINATION bin)

connext_components_register_node(${PROJECT_NAME}
  PLUGIN "rti::connext_msgs_examples::DdsTalker"
  EXECUTABLE talker)
connext_components_register_node(${PROJECT_NAME}
  PLUGIN "rti::connext_msgs_examples::DdsListener"
  EXECUTABLE listener)

connext_components_register_node(${PROJECT_NAME}
  PLUGIN "rti::connext_msgs_examples::DdsTalkerFlat"
  EXECUTABLE talker_flat)
connext_components_register_node(${PROJECT_NAME}
  PLUGIN "rti::connext_msgs_examples::DdsListenerFlat"
  EXECUTABLE listener_flat)

connext_components_register_node(${PROJECT_NAME}
  PLUGIN "rti::connext_msgs_examples::DdsTalkerFlatZc"
  EXECUTABLE talker_flat_zc)
connext_components_register_node(${PROJECT_NAME}
  PLUGIN "rti::connext_msgs_examples::DdsListenerFlatZc"
  EXECUTABLE listener_flat_zc)

connext_components_register_node(${PROJECT_NAME}
  PLUGIN "rti::connext_msgs_examples::DdsTalkerZc"
  EXECUTABLE talker_zc)
connext_components_register_node(${PROJECT_NAME}
  PLUGIN "rti::connext_msgs_examples::DdsListenerZc"
  EXECUTABLE listener_zc)

if(BUILD_TESTING)
  find_package(ament_lint_auto REQUIRED)
  ament_lint_auto_find_test_dependencies()
endif()

ament_package()
