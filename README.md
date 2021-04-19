# ROS 2 messages for RTI Connext DDS

The repository contains a library of C++11 message type supports generated by
`rtiddsgen`, which allows any DDS application to use most types included in ROS 2
with RTI Connext DDS.

The library is packaged in a ROS 2 package for convenience, but it may also be
built without ROS 2 as a stand-alone dependency.

The package is built with the help of [`rticonnextdds-ros2-helpers`](https://github.com/asorbini/rticonnextdds-ros2-helpers).

This repository takes inspiration from [`rticommunity/ros-data-types`](https://github.com/rticommunity/ros-data-types),
which offers a similar library that provides easy access to ROS 2 data types to
any Connext application.

- [Use `connext_msgs` in a ROS 2 package](#use-connext_msgs-in-a-ros-2-package)
- [Use `connext_msgs` in any DDS application](#use-connext_msgs-in-any-dds-application)
- [Included IDL files](#included-idl-files)
- [Included packages](#included-packages)
- [Unsupported types](#unsupported-types)
- [Other useful resources](#other-useful-resources)

## Use `connext_msgs` in a ROS 2 package

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

Make sure to clone the repository to your workspace, along with `rticonnextdds-ros2-helpers`,
and `colcon build` will automatically build everything a needed:

```sh
cd my-workspace/

git clone https://github.com/asorbini/rticonnextdds-ros2-msgs

git clone https://github.com/asorbini/rticonnextdds-ros2-helpers

colcon build
```

You can also use the included `ros2.repos` file to clone all required repositories
with `vcs`:

```sh
cd my-workspace/

wget https://raw.githubusercontent.com/asorbini/rticonnextdds-ros2-msgs/master/ros2.repos

vcs import < ros2.repos
```

In order to use the types, you must `#include` the appropriate file in your C++
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

## Use `connext_msgs` in any DDS application

The type supprts library provided by this repository does not have any direct
dependency on ROS 2, and it may also be built as a stand-alone dependency.

In order to do this, you must clone all required dependencies and run `cmake`
by hand:

```sh
git clone https://github.com/asorbini/rticonnextdds-ros2-msgs

cd rticonnextdds-ros2-msgs

git clone https://github.com/asorbini/rticonnextdds-ros2-helpers

mkdir build

cd build

cmake ../connext_msgs -DCMAKE_INSTALL_PREFIX=../install

cmake --build . -- -j4 install
```

The library will be installed under `${CMAKE_INSTALL_PREFIX}/lib` while all
header files will be placed under `${CMAKE_INSTALL_PREFIX}/include`.

By default, the library will be named `connext_msgs`, but you can customize
this name with variable `MESSAGE_LIBRARY`.

If you prefer to clone `rticonnextdds-ros2-helpers` somewhere else, you can specify
its location using variable `CONNEXT_ROS2_HELPERS_DIR`.

You can also force the library to be built in standalone mode by setting
`MESSAGE_STANDALONE` to `true`.

## Included IDL files

Package `connext_msg` contains a collection of IDL files extracted from the
ROS 2 Rolling distribution, and modified to compile with `rtiddsgen` so that
they may be compiled into a single, ready-to-use shared library.

Only IDL files for message types are included.

The IDL files can be updated using script `copy_idls.sh`.

The script will scan a ROS 2 installation, and it will copy all IDL files
to the `./idl` directory. It will also perform some lightweight processing on
the files to remove some incompatibilities.

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

The list of included message packages can be restricted by specifying variable
`MESSAGE_PACKAGES`, e.g. `-DMESSAGE_PACKAGES="std_msgs;builtin_interfaces"`, in
which case only messages from the specified packages will be included.

You can further customize the list of messages included in the generated
library using variables `MESSAGE_INCLUDE` and `MESSAGE_EXCLUDE`. Messages must
be specified as `<pkg>/msg/<type>`, and exclusions take precedence over includes.

## Unsupported types

The following types are currently unsupported, typically because their IDL
contains multiple nested `#include`'s of the same file which is not
supported by `rtiddsgen`.

```txt
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
```

## Other useful resources

- [`rticonnextdds-ros2-demos`](https://github.com/asorbini/rticonnextdds-ros2-demos)
  - Collection of example hybrid ROS 2/Connext applications.
- [`rticonnextdds-ros2-helpers`](https://github.com/asorbini/rticonnextdds-ros2-helpers)
  - Collection of utilities to built ROS 2 applications with RTI Connext DDS.
