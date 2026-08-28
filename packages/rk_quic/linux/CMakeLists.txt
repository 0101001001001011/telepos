cmake_minimum_required(VERSION 3.10)

set(PROJECT_NAME "rk_quic")
project(${PROJECT_NAME} LANGUAGES NONE)

add_subdirectory("${CMAKE_CURRENT_SOURCE_DIR}/../src" "${CMAKE_CURRENT_BINARY_DIR}/shared")

# The Flutter tool copies everything named here into `bundle/lib/`.
set(rk_quic_bundled_libraries
  "${RK_LIBRARY_PATH}"
  PARENT_SCOPE
)
