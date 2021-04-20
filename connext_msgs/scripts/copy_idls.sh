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

set -e

defaults()
{
  : ${SH:=$(basename ${0})}
  : ${ROS_DISTRO:=rolling}
  : ${ROS_DIR:=/opt/ros/${ROS_DISTRO}}
  : ${IDL_DIR:=./idl}
  : ${IDL_FLAT_DIR:=./idl/flat}
  : ${IDL_FLAT_ZC_DIR:=./idl/flat_zc}
  : ${IDL_ZC_DIR:=./idl/zc}
  : ${IDL_2_DIR:=./idl/xcdr2}
  : ${ARRAY_MAX_LEN:=100}
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
  printf "\n"
}

defaults

if [ $# -gt 0 ]; then
  help
  exit 0
fi

printf -- "-- deleting IDL directories...\n"
rm -rf ${IDL_DIR} \
       ${IDL_FLAT_DIR} \
       ${IDL_FLAT_ZC_DIR} \
       ${IDL_ZC_DIR} \
       ${IDL_2_DIR}

printf -- "-- copying ROS 2 %s IDL files from %s\n" \
  "${ROS_DISTRO}" \
  "${ROS_DIR}"
for idl in $(find ${ROS_DIR} \
  -name "*.idl" ! -path "*/dds_connext/*"); do
  # -name "*.idl" -path "*/msg/*" ! -path "*/dds_connext/*"); do
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
    string \
    wstring; do
  for f in $(grep -rEH "typedef ${t} ${t}__[1-9][0-9]*\[[1-9][0-9]*];" ${IDL_DIR} | cut -d: -f1); do
    for i in $(seq 0 ${ARRAY_MAX_LEN}); do
      if grep -qE "typedef ${t} ${t}__${i}\[${i}\];" ${f}; then
        printf -- "---- rm typedef [%s/%s] %s\n" "${t}" "${i}" "${f}"
        sed -i -r -e "s/typedef ${t} ${t}__${i}\[${i}\];//g" ${f}
        sed -i -r -e "s/${t}__${i} ([a-zA-Z0-9_]+);/${t} \1[${i}];/g" ${f}
      fi
    done
  done
done

################################################################################
# Process each file for some more substitution/removals
################################################################################
for f in $(find ${IDL_DIR} -mindepth 1 -name "*\.idl"); do
  printf -- "-- processing: %s\n" "${f}"

  # Add header guards to every include
  for inc_line in $(grep -E '^#include "' ${f} | cut -d\" -f2 | sort | uniq); do
    inc_guard=$(echo ${inc_line} | tr '/' '_' | tr '.' '_')

    sed -i -r -e \
      "s:^(#include \"${inc_line}\")$:#ifndef ${inc_guard}\n#define ${inc_guard}\n\1\n#endif  // ${inc_guard}:g" \
      "${f}"
  done

  # Remove comments and other unsupported annotations
  sed -i -r -e 's:@verbatim[ ]*\(language="comment", text=$::g' \
            -e 's:^[ ]+".*$::g' \
            -e 's:@unit[ ]*\(.*$::g' \
            ${f}
done

################################################################################
# Fix some issues with annotation bugs (currently disabled)
################################################################################
# sed -r -i -e "s:@default \(value=-50\):@default (value=50):" \
#   "${IDL_DIR}/test_msgs/msg/Defaults.idl"

################################################################################
# Helper function to generate alternative versions of the IDLs
################################################################################
idl_pkgs=$(ls ${IDL_DIR})

: "${IDL_STRING_MAX_LEN:=255}"
: "${IDL_SEQUENCE_MAX_LEN:=100}"

gen_alt_idl()
{
  local ns="${1}" \
        dst_dir="${2}" \
        annotations="${3}"

  rm -rf ${IDL_DIR}/.tmp-idl
  mkdir -p ${IDL_DIR}/.tmp-idl

  (
    cd ${IDL_DIR}
    cp -a ${idl_pkgs} .tmp-idl/
  )

  mv ${IDL_DIR}/.tmp-idl ${dst_dir}/

  for f in $(find ${dst_dir} -name "*\.idl"); do
    sed -i -r \
      -e "s:([ ]*)(struct [A-Za-z].*)$:\1${annotations}\n\1\2:" \
      -e "s:^(module .*)$:module ${ns} {\n\1:" \
      -e 's:^};$:};\n};:' \
      ${f}
    # Adjust types if types are @final with either SHMEM_REF or FLAT_DATA
    if echo "${annotations}" | grep -qE "^@final"  &&
      (echo "${annotations}" | grep -q SHMEM_REF ||
      echo "${annotations}" | grep -q FLAT_DATA); then
      sed -i -r \
        -e "s:wstring ([a-zA-Z].*);$:wchar \1[${IDL_STRING_MAX_LEN} + 1];:g" \
        -e "s:wstring<([^>]+)> ([a-zA-Z].*);$:wchar \2[\1 + 1];:g" \
        -e "s:string ([a-zA-Z].*);$:char \1[${IDL_STRING_MAX_LEN} + 1];:g" \
        -e "s:string<([^>]+)> ([a-zA-Z].*);$:char \2[\1 + 1];:g" \
        -e "s:sequence<([^,]+)> ([a-zA-Z].*);$:\1 \2[${IDL_SEQUENCE_MAX_LEN}];:g" \
        -e "s:sequence<([^,]+),([^>]+)> ([a-zA-Z].*);$:\1 \3[\2];:g" \
        -e "s:wstring ([a-zA-Z].*)(\[[0-9 ]*\]);$:wchar \1[${IDL_SEQUENCE_MAX_LEN}][${IDL_STRING_MAX_LEN} + 1];:g" \
        -e "s:string ([a-zA-Z].*)(\[[0-9 ]*\]);$:char \1[${IDL_SEQUENCE_MAX_LEN}][${IDL_STRING_MAX_LEN} + 1];:g" \
        ${f}
      
      # Remove default declarations for strings and wstrings. Do this iteratively
      # because only one line is removed by each sed invocation.
      while grep -A 1 -E "[ ]+@default [^\n]+" ${f} | grep -q "wchar "; do
        sed -i -z -r \
          -e 's:@default [^\n]+\n[ ]+(wchar [a-zA-Z0-9_]+\[[^\]+\];):\1:g' \
          ${f}
      done

      while grep -A 1 -E "[ ]+@default [^\n]+" ${f} | grep -q "char "; do
        sed -i -z -r \
          -e 's:@default [^\n]+\n[ ]+(char [a-zA-Z0-9_]+\[[^\]+\];):\1:g' \
          ${f}
      done
    fi
    for p in ${idl_pkgs}; do
      sed -i -r \
        -e "s/${p}::/${ns}::${p}::/g" \
        -e "s:#include \"${p}/:#include \"${ns}/${p}/:g" \
        ${f}
    done
  done
}
################################################################################
# Generate "flat-data" versions
################################################################################
printf -- "-- generating flat data types...\n"
gen_alt_idl flat "${IDL_DIR}/flat" \
  "@final\n\1@language_binding(FLAT_DATA)"

################################################################################
# Generate "flat-data/zero-copy" versions
################################################################################
printf -- "-- generating flat data/zero copy types...\n"
gen_alt_idl flat_zc "${IDL_DIR}/flat_zc" \
  "@final\n\1@transfer_mode(SHMEM_REF)\n\1@language_binding(FLAT_DATA)"

################################################################################
# Generate "zero-copy" versions
################################################################################
printf -- "-- generating zero copy types...\n"
gen_alt_idl zc "${IDL_DIR}/zc" \
  "@final\n\1@transfer_mode(SHMEM_REF)"

################################################################################
# Generate "xcdr2" versions
################################################################################
printf -- "-- generating xcdr2 types...\n"
gen_alt_idl xcdr2 "${IDL_DIR}/xcdr2" \
  "@final\n\1@allowed_data_representation(XCDR2)"


