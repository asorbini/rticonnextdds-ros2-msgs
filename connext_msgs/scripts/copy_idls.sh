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
  : ${SH_DIR:=$(cd $(dirname "${0}") && pwd)}
  : ${ROS_DISTRO:=foxy}
  : ${ROS_DIR:=/opt/ros/${ROS_DISTRO}}
  : ${IDL_DIR:=./idl}
  : ${IDL_IMPORT_DIR:=${IDL_DIR}/import}
  : ${IDL_BASIC_DIR:=${IDL_DIR}/ros2/basic}
  : ${IDL_SH_DIR:=${SH_DIR}/idl}
  : ${ARRAY_MAX_LEN:=100}
  : ${IDL_STRING_MAX_LEN:=255}
  : ${IDL_SEQUENCE_MAX_LEN:=100}
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

################################################################################
# Helper functions to manipulate IDL files
################################################################################
_idl_annotate_structs() {
  local f="${1}" \
        annotations="${2}"
  # echo "-- Annotate ${f}:\n${annotations}\n"
  sed -i -r \
      -e "s:([ ]*)(struct [A-Za-z].*)$:\1${annotations}\n\1\2:" \
      ${f}
}

_idl_add_namespace_prefix() {
  local f="${1}"
  shift
  local ns_prefix="$(
    for m in $@; do
      printf "%s" "${m}::"
    done
  )"
  local inc_prefix="$(
    for m in $@; do
      printf "%s" "${m}/"
    done
  )"

  for p in ${IDL_PKGS}; do
    sed -i -r \
      -e "s/${p}::/${ns_prefix}${p}::/g" \
      -e "s:#include \"${p}/:#include \"${inc_prefix}${p}/:g" \
      ${f}
  done
}

_idl_wrap_in_modules() {
  local f="${1}"
  shift
  local modules="$(
    for m in $@; do
      printf "module %s { " "${m}"
    done
  )"
  local modules_close="$(
    for m in $@; do
      printf " };"
    done
  )"
  sed -i -r \
      -e "s:^(module [^{]+\{)$:${modules}\1:" \
      -e "s:^\};$:};${modules_close}:" \
      ${f}
  
  # Add prefix to all namespace references and #include's.
  _idl_add_namespace_prefix "${f}" ros2 ${ns}
}

_idl_check_requires_mutable() {
  # We annotate a type as @mutable if it uses both SHMEM_REF and FLAT_DATA.
  local f="${1}" \
        annotations="${2}"

  if echo "${annotations}" | grep -qE "^@final" ||
     ! (echo "${annotations}" | grep -q SHMEM_REF &&
        echo "${annotations}" | grep -q FLAT_DATA); then
    return 1
  fi

  # if ! grep -qE "^[ ]*sequence<" "${f}" &&
  #   ! grep -qE "^[ ]*[w]*string[< ]" "${f}"; then
  #   return 1
  # fi

  # echo "-- mutable: ${f}"
}

_idl_check_requires_fixed_size() {
  local annotations="${1}"

  if echo "${annotations}" | grep -qE "^@final"  &&
     (echo "${annotations}" | grep -q SHMEM_REF ||
     echo "${annotations}" | grep -q FLAT_DATA); then
    return 0
  else
    return 1
  fi
}

_idl_delete_string_constants() {
  local f="${1}"

  sed -i -r \
      -e "s:[ ]+const wstring [^\n]*::g" \
      -e "s:[ ]+const string [^\n]*::g" \
      ${f}
}

_idl_convert_strings_to_arrays() {
  local f="${1}" \
        string_len="${2}"

  sed -i -r \
      -e "s:wstring ([a-zA-Z].*);$:wchar \1[${string_len} + 1];:g" \
      -e "s:wstring<([^>]+)> ([a-zA-Z].*);$:wchar \2[\1 + 1];:g" \
      -e "s:string ([a-zA-Z].*);$:char \1[${string_len} + 1];:g" \
      -e "s:string<([^>]+)> ([a-zA-Z].*);$:char \2[\1 + 1];:g" \
      -e "s:wstring ([a-zA-Z].*)(\[[0-9 ]*\]);$:wchar \1[${seq_len}][${string_len} + 1];:g" \
      -e "s:string ([a-zA-Z].*)(\[[0-9 ]*\]);$:char \1[${seq_len}][${string_len} + 1];:g" \
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
}

_idl_convert_sequences_to_arrays() {
  local f="${1}" \
        seq_len="${2}"

  sed -i -r \
      -e "s:sequence<([^,]+)> ([a-zA-Z].*);$:\1 \2[${seq_len}];:g" \
      -e "s:sequence<([^,]+),([^>]+)> ([a-zA-Z].*);$:\1 \3[\2];:g" \
      ${f}
}

_idl_convert_unbounded_to_bounded() {
  local f="${1}" \
        seq_len="${2}" \
        string_len="${3}"

  sed -i -r \
      -e "s:sequence<([w]*string)([^>]*)> ([a-zA-Z].*);$:sequence<\1<${string_len}>\2> \3;:g" \
      -e "s:sequence<([^,]+)> ([a-zA-Z].*);$:sequence<\1, ${seq_len}> \2;:g" \
      -e "s:wstring ([a-zA-Z].*);$:wstring<${string_len}> \1;:g" \
      -e "s:string ([a-zA-Z].*);$:string<${string_len}> \1;:g" \
      ${f}
}


################################################################################
# Helper function to generate alternative versions of the IDLs
################################################################################
gen_alt_idl()
{
  local ns="${1}" \
        dst_dir="${2}" \
        annotations="${3}"

  rm -rf ${IDL_IMPORT_DIR}/.tmp-idl
  mkdir -p ${IDL_IMPORT_DIR}/.tmp-idl

  (
    cd ${IDL_IMPORT_DIR}
    cp -a ${IDL_PKGS} .tmp-idl/
  )

  mkdir -p ${dst_dir}/
  mv ${IDL_IMPORT_DIR}/.tmp-idl/* ${dst_dir}/
  rm -r ${IDL_IMPORT_DIR}/.tmp-idl

  for f in $(find ${dst_dir} -name "*\.idl"); do
    # Check if there is a custom preprocessing script for the file.
    # Determine the relative path of the file wrt ${IDL_DIR}/ros2/${ns}
    local f_rpath="${f#${IDL_DIR}/ros2/${ns}/}"
    # Base name of the IDL file
    local f_name=$(basename "${f_rpath%.idl}")
    # Path of the optional preprocessing script
    local f_sh="${IDL_SH_DIR}/${f_rpath%.idl}.sh"
    # Name of the preprocessing function associated with this configuration
    local f_fn="${f_name}_${ns}"
    # printf -- "----------------------------------------------------\n"
    # printf "SH_DIR=%s\n" "${SH_DIR}"
    # printf "IDL_SH_DIR=%s\n" "${IDL_SH_DIR}"
    # printf "f=%s\n" "${f}"
    # printf "f_rpath=%s\n" "${f_rpath}"
    # printf "f_name=%s\n" "${f_name}"
    # printf "f_sh=%s\n" "${f_sh}"
    # printf "f_fn=%s\n" "${f_fn}"
    if [ -f "${f_sh}" ]; then
      (
        # Load preprocessing script
        . "${f_sh}"
        # Check if a function exist for this configuration,
        # and if so, call it passing it the input file's path
        if type ${f_fn} >/dev/null 2>&1; then
          printf -- "-- custom [%s]: %s\n" "${ns}" "${f_rpath}"
          ${f_fn} "${f}"
        fi
      )
    fi

    #
    # Add ${annotations} in front of all `struct` fields.
    local struct_annotations="${annotations}"
    local mutable=
    if _idl_check_requires_mutable "${f}" "${struct_annotations}"; then
      struct_annotations="@mutable\n\1${struct_annotations}"
      mutable=mutable
    else
      struct_annotations="@final\n\1${struct_annotations}"
    fi
    _idl_annotate_structs "${f}" "${struct_annotations}"
    
    # Enclose `module` in `ros2::${ns}`
    _idl_wrap_in_modules "${f}" ros2 ${ns}

    # Adjust types if types are @final with either SHMEM_REF or FLAT_DATA
    if _idl_check_requires_fixed_size "${struct_annotations}"; then
      # Delete string and wstring constants
      _idl_delete_string_constants "${f}"

      # Convert all variable-length fields to a fixed-size version.
      # First convert sequences to arrays, then convert strings to arrays
      _idl_convert_sequences_to_arrays "${f}" "${IDL_SEQUENCE_MAX_LEN}"
      _idl_convert_strings_to_arrays "${f}" "${IDL_STRING_MAX_LEN}"
    elif [ -n "${mutable}" ]; then
      # Convert all unbounded fields to bounded
      _idl_convert_unbounded_to_bounded "${f}" \
        "${IDL_SEQUENCE_MAX_LEN}" "${IDL_STRING_MAX_LEN}"
    fi
  done
}

################################################################################
# Begin script
################################################################################
# Load defaults
defaults

if [ $# -gt 0 ]; then
  help
  exit 0
fi

printf -- "-- deleting IDL directory...\n"
rm -rf ${IDL_DIR}

printf -- "-- copying ROS 2 %s IDL files from %s\n" \
  "${ROS_DISTRO}" \
  "${ROS_DIR}"
for idl in $(find ${ROS_DIR} \
  -name "*.idl" ! -path "*/dds_connext/*"); do
  # -name "*.idl" -path "*/msg/*" ! -path "*/dds_connext/*"); do
  idl_rel="${idl#${ROS_DIR}/share/}"
  p="${IDL_IMPORT_DIR}/$(dirname ${idl_rel})"
  [ -d "${p}" ] || mkdir -p ${p}
  rsync -a ${idl} ${p}
  # printf -- "---- ${idl_rel}\n"
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
  for f in $(grep -rEH "typedef ${t} ${t}__[1-9][0-9]*\[[1-9][0-9]*];" ${IDL_IMPORT_DIR} | cut -d: -f1); do
    for i in $(seq 0 ${ARRAY_MAX_LEN}); do
      if grep -qE "typedef ${t} ${t}__${i}\[${i}\];" ${f}; then
        # printf -- "---- rm typedef [%s/%s] %s\n" "${t}" "${i}" "${f}"
        sed -i -r -e "s/typedef ${t} ${t}__${i}\[${i}\];//g" ${f}
        sed -i -r -e "s/${t}__${i} ([a-zA-Z0-9_]+);/${t} \1[${i}];/g" ${f}
      fi
    done
  done
done

################################################################################
# Process each file for some more substitutions/removals
################################################################################
for f in $(find ${IDL_IMPORT_DIR} -mindepth 1 -name "*\.idl"); do
  # printf -- "-- processing: %s\n" "${f}"

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
#   "${IDL_IMPORT_DIR}/test_msgs/msg/Defaults.idl"

# List of type packages (used to drive some processing operations)
IDL_PKGS=$(ls ${IDL_IMPORT_DIR})

################################################################################
# Generate "basic" versions
################################################################################
printf -- "-- generating standard data types...\n"
gen_alt_idl basic "${IDL_DIR}/ros2/basic" \
  ""

################################################################################
# Generate "flat-data" versions
################################################################################
printf -- "-- generating flat data types...\n"
gen_alt_idl flat "${IDL_DIR}/ros2/flat" \
  "@language_binding(FLAT_DATA)"

################################################################################
# Generate "flat-data/zero-copy" versions
################################################################################
printf -- "-- generating flat data/zero copy types...\n"
gen_alt_idl flat_zc "${IDL_DIR}/ros2/flat_zc" \
  "@transfer_mode(SHMEM_REF)\n\1@language_binding(FLAT_DATA)"

################################################################################
# Generate "zero-copy" versions
################################################################################
printf -- "-- generating zero copy types...\n"
gen_alt_idl zc "${IDL_DIR}/ros2/zc" \
  "@transfer_mode(SHMEM_REF)"

################################################################################
# Generate "xcdr2" versions
################################################################################
printf -- "-- generating xcdr2 types...\n"
gen_alt_idl xcdr2 "${IDL_DIR}/ros2/xcdr2" \
  "@allowed_data_representation(XCDR2)"

################################################################################
# Delete imported files
################################################################################
printf -- "-- deleting imported files: ${IDL_IMPORT_DIR}\n"
rm -r "${IDL_IMPORT_DIR}"
