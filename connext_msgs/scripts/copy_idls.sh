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

################################################################################
# This script can be used to copy all `.idl` files inside out of a ROS 2
# installation to a local directory, and to post process them so that they may
# be fed to `rtiddsgen` and built into a single library.
################################################################################

defaults()
{
  : ${SH:=$(basename ${0})}
  : ${ROS_DISTRO:=rolling}
  : ${ROS_DIR:=/opt/ros/${ROS_DISTRO}}
  : ${IDL_DIR:=./idl}
  : ${ARRAY_MAX_LEN:=100}
  : ${CLEAN_IDL:=}
}

help()
{
  var_help()
  {
    printf "  ${1}\n"
    printf "    %s" "${2}"
    printf " (default: %s)\n" "$(eval "echo \${${1}}")"
  }

  printf "%s: copy ROS 2 IDL files and prepare them for rtiddsgen\n" "${SH}"
  printf "\n"
  printf "usage: [VAR1=foo [VAR2=bar [...]]] %s\n" "${SH}"
  printf "\n"
  printf "Control variables:\n"
  var_help IDL_DIR "Directory where to copy the IDL files"
  var_help ROS_DISTRO "ROS 2 version identifier"
  var_help ROS_DIR "ROS 2 installation directory"
  var_help ARRAY_MAX_LEN "maximum length of arrays for typedef substitution"
  var_help CLEAN_IDL "delete IDL directory before copying if set"
  printf "\n"
}

defaults

if [ $# -gt 0 ]; then
  help
  exit 0
fi

if [ -n "${CLEAN_IDL}" ]; then
  printf -- "-- deleting IDL directory: %s\n" "${IDL_DIR}"
  rm -rf ${IDL_DIR}
fi

printf -- "-- copying ROS 2 %s IDL files from %s\n" \
  "${ROS_DISTRO}" \
  "${ROS_DIR}"
for idl in $(find ${ROS_DIR} \
  -name "*.idl" -path "*/msg/*" ! -path "*/dds_connext/*"); do
  idl_rel="${idl#${ROS_DIR}/share/}"
  p="${IDL_DIR}/$(dirname ${idl_rel})"
  [ -d "${p}" ] || mkdir -p ${p}
  rsync -a ${idl} ${p}
  printf -- "---- ${idl_rel}\n"
done

################################################################################
# The IDL files use typedef's for all primitive arrays. This causes conflicts
# because of multiple definitions when all translation units are linked into
# a single library.
# Since the arrays can be expressed without typedef, we try to get rid of this
# idiom with a simple (aka brute force) search&replace.
# Use variable ARRAY_MAX_LEN to specify the maximum length that will be searched
# for (default: 100).
# 
# The script will get rid of all lines that match:
#
#   typedef <type> <type>__<size>[<size>];
#
# And transform lines that used the typedefs:
#
#   <type>__<size>  <identifier>;  ==>  <type> <identifier>[<size>];
# 
################################################################################
printf -- "-- replacing primitive array typedefs up to [%d]\n" "${ARRAY_MAX_LEN}"
for t in \
  uint8 \
  uint16 \
  uint32 \
  uint64 \
  int8 \
  int16 \
  int32 \
  int64 \
  float \
  double \
  boolean \
  octet \
  string; do
  for i in $(seq 0 ${ARRAY_MAX_LEN}); do
    for f in $(grep -rEH "typedef ${t} ${t}__${i}\[${i}\];" idl | cut -d: -f1); do
      printf -- "---- rm typedef [%s/%s] %s\n" "${t}" "${i}" "${f}"
      sed -i -r -e "s/typedef ${t} ${t}__${i}\[${i}\];//g" ${f}
      sed -i -r -e "s/${t}__${i} ([a-zA-Z0-9_]+);/${t} \1[${i}];/g" ${f}
    done
  done
done

################################################################################
# Several types cannot be compiled by rtiddsgen because they end up including
# the same IDL file multiple times, which isn't supported.
# Files which only have one duplicate `#include`, and the duplicate is in the
# file itself (and not nested in one of its included files) can be fixed by
# removing the duplicate from the top-level file.
################################################################################
printf -- "-- removing redudant #include's...\n"
remove_include()
{
  local idl="${1}" \
        inc="${2}"
  local idl_file="idl/${idl}.idl" \
        inc_file="${inc}.idl"
  printf -- "---- rm #include [%s] %s\n" "${inc_file}" "${idl_file}"
  sed -i -r -e "s:^#include \"${inc_file}\"$::g" ${idl_file}
}

remove_include \
  "rmw_dds_common/msg/ParticipantEntitiesInfo" \
  "rmw_dds_common/msg/Gid"

remove_include \
  "map_msgs/msg/PointCloud2Update" \
  "std_msgs/msg/Header"

remove_include \
  "nav_msgs/msg/Path" \
  "std_msgs/msg/Header"

remove_include \
  "pcl_msgs/msg/PolygonMesh" \
  "std_msgs/msg/Header"

remove_include \
  "sensor_msgs/msg/TimeReference" \
  "builtin_interfaces/msg/Time"

remove_include \
  "stereo_msgs/msg/DisparityImage" \
  "std_msgs/msg/Header"
