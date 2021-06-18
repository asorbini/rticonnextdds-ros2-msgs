// Copyright 2014 Open Source Robotics Foundation, Inc.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
//
// (c) 2021 Copyright, Real-Time Innovations, Inc.  All rights reserved.
//
// RTI grants Licensee a license to use, modify, compile, and create derivative
// works of the Software.  Licensee has the right to distribute object form
// only for use with RTI products.  The Software is provided "as is", with no
// warranty of any type, including any warranty for fitness for any purpose.
// RTI is under no obligation to maintain or support the Software.  RTI shall
// not be liable for any incidental or consequential damages arising out of the
// use or inability to use the software.

#include "rclcpp/rclcpp.hpp"
#include "rclcpp_components/register_node_macro.hpp"

#include "connext_msgs_examples/visibility_control.h"

// Include RTI Connext DDS "modern C++" API
#include <dds/dds.hpp>
// Include type support code generated by rtiddsgen
#include "ros2/std/std_msgs/msg/String.hpp"

using namespace dds::core;
using namespace ros2::std::std_msgs::msg;

namespace rti { namespace connext_msgs_examples
{
// Create a Listener class that subclasses the generic rclcpp::Node base class.
// The main function below will instantiate the class as a ROS node.
class DdsListener : public rclcpp::Node,
  public dds::sub::NoOpDataReaderListener<String>
{
public:
  CONNEXT_MSGS_EXAMPLES_PUBLIC
  explicit DdsListener(const rclcpp::NodeOptions & options)
  : Node("dds_listener", options)
  {
    setvbuf(stdout, NULL, _IONBF, BUFSIZ);
    // The DomainParticipant is created on domain 0 by default
    auto participant = dds::domain::find(0);
    assert(null != participant);
    // Create a DataReader for topic "rt/chatter"
    assert(null != participant);
    auto subscriber = dds::sub::Subscriber(participant);
    auto topic = dds::topic::Topic<String>(participant,
      "rt/chatter", "dds_::String_");
    dds::sub::qos::DataReaderQos reader_qos; 
    reader_qos << policy::Reliability::Reliable();
    reader_qos << policy::History(policy::HistoryKind::KEEP_LAST, 10);
    sub_ = dds::sub::DataReader<String>(
      subscriber, topic, reader_qos, this, status::StatusMask::all());
  }

  void on_data_available(dds::sub::DataReader<String> &reader)
  {
    assert(reader == sub_);
    dds::sub::LoanedSamples<String> samples = reader.take();
    for (auto it = samples.begin(); it != samples.end(); it++)
    {
      if (it->info().valid()) {
        const String& msg = it->data();
        RCLCPP_INFO(this->get_logger(),
          "I heard from Connext: [%s]", msg.data().c_str());
      }
    }
  }

private:
  dds::sub::DataReader<String> sub_{nullptr};
};

}  // namespace connext_nodes_cpp
}  // namespace rti

RCLCPP_COMPONENTS_REGISTER_NODE(rti::connext_msgs_examples::DdsListener)
