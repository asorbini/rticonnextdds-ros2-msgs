# ROS 2 messages for RTI Connext DDS

The repository contains a ROS 2 package which provides a library with
C++11 message type supports to use most types included in ROS 2
with RTI Connext DDS.

The package is built with the help of [`rticonnextdds-ros2-helpers`](https://github.com/asorbini/rticonnextdds-ros2-helpers).

- [Package `connext_msgs`](#package-connext_msgs)
- [Use DDS types in a ROS 2 application](#use-dds-types-in-a-ros-2-application)
- [Included packages](#included-packages)
- [Unsupported types](#unsupported-types)

## Package `connext_msgs`

Package `connext_msg` contains a collection of IDL files extracted from the
ROS 2 Rolling distribution, and modified to compile with `rtiddsgen` so that
they may be compiled into a single, ready-to-use shared library.

Only IDL files for message types are included.

The IDL files can be updated using script `copy_idls.sh`.

The script will scan a ROS 2 installation, and it will copy all IDL files
to the `./idl` directory. It will also perform some lightweight processing on
the files to remove some incompatibilities.

This package takes inspiration from repository [`rticommunity/ros-data-types`](https://github.com/rticommunity/ros-data-types),
which offers a similar library that provides easy access to ROS 2 data types to
any Connext application.

## Use DDS types in a ROS 2 application

Since `connext_msgs` is a regular ROS 2 package, you can just add it to your
`package.xml` dependencies, and load it in your `CMakeLists.txt` like any other
package and library:

- `package.xml`:

  ```xml
  <package format="3">
    <name>my_package</name>
    
    <!-- ... -->

    <depend>connext_msgs</depend>
  
    <!-- ... -->
  </package>
  ```

- `CMakeLists.txt`

  ```cmake
  cmake_minimum_required(VERSION 3.5)
  project(my_package)

  # ...

  # Load package
  find_package(connext_msgs REQUIRED)

  # ...

  # Add dependency to your targets
  ament_target_dependencies(my_target  connext_msgs)
  ament_export_dependencies(connext_msgs)

  ```

In oder to you the types, you must `#include` the appropriate file in your C++
code. The path is slightly different from the one used for standard ROS 2 messages,
in that the file name is not converted to all lowercase and "snake case" format,
instead retaining the same name as the input `.idl`.

For example, in order to use type `sensor_msgs::msg::PointCloud`:

```cpp
// typical ROS 2 include
#include "sensor_msgs/msg/point_cloud.hpp"

// DDS type include
#include "sensor_msgs/msg/PointCloud.hpp"
```

## Included packages

Types from the following packages are currently included in the library:

```txt
actionlib_msgs           nav_msgs         std_msgs
action_msgs              pcl_msgs         stereo_msgs
builtin_interfaces       pendulum_msgs    test_msgs
diagnostic_msgs          rcl_interfaces   tf2_msgs
example_interfaces       rmw_dds_common   trajectory_msgs
geometry_msgs            rosgraph_msgs    turtlesim
libstatistics_collector  sensor_msgs      unique_identifier_msgs
lifecycle_msgs           shape_msgs       visualization_msgs
map_msgs                 statistics_msgs
```

## Unsupported types

The following types are currently unsupported, typically because their IDL files
contain multiple nested `#include`'s of the same file:

```txt
actionlib_msgs/GoalStatusArray
map_msgs/ProjectedMap
nav_msgs/OccupancyGrid
nav_msgs/Odometry
sensor_msgs/MultiDOFJointState
test_msgs/Arrays
test_msgs/BoundedSequences
test_msgs/Defaults
test_msgs/MultiNested
test_msgs/UnboundedSequences
trajectory_msgs/MultiDOFJointTrajectory
trajectory_msgs/MultiDOFJointTrajectoryPoint
visualization_msgs/InteractiveMarker
visualization_msgs/InteractiveMarkerControl
visualization_msgs/InteractiveMarkerFeedback
visualization_msgs/InteractiveMarkerInit
visualization_msgs/InteractiveMarkerUpdate
visualization_msgs/Marker
visualization_msgs/MarkerArray
```
