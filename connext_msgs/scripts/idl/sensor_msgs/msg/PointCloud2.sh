# Data length: 12MB
PointCloud2_data_LENGTH=12582912
# Fields length: 12MB
PointCloud2_fields_LENGTH=8

PointCloud2_fixed_size() {
  sed -i -r \
    -e "s/sequence<sensor_msgs::msg::PointField> fields;$/sensor_msgs::msg::PointField fields[${PointCloud2_fields_LENGTH}];/" \
    -e "s/sequence<uint8> data;$/uint8 data[${PointCloud2_data_LENGTH}];/" \
    ${1}
}

PointCloud2_bounded() {
  sed -i -r \
    -e "s/sequence<sensor_msgs::msg::PointField> fields;$/sequence<sensor_msgs::msg::PointField, ${PointCloud2_fields_LENGTH}> fields;/" \
    -e "s/sequence<uint8> data;$/sequence<uint8, ${PointCloud2_data_LENGTH}> data;/" \
    ${1}
}

PointCloud2_flat() {
  PointCloud2_fixed_size "${1}"
}

PointCloud2_flat_zc() {
  PointCloud2_bounded "${1}"
}

PointCloud2_zc() {
  PointCloud2_fixed_size "${1}"
}
