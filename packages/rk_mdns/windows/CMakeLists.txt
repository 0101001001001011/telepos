cmake_minimum_required(VERSION 3.14)

set(PROJECT_NAME "rk_mdns")
project(${PROJECT_NAME} LANGUAGES NONE)

add_subdirectory("${CMAKE_CURRENT_SOURCE_DIR}/../src" "${CMAKE_CURRENT_BINARY_DIR}/shared")

# The Flutter tool copies everything named here next to the runner executable.
set(rk_mdns_bundled_libraries
  "${RK_LIBRARY_PATH}"
  PARENT_SCOPE
)
