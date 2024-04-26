cmake_minimum_required(VERSION 3.24)
set(CMAKE_CXX_STANDARD 17)

IF(DEFINED ENV{ET_BUILD_DIR})
  set(ET_BUILD_DIR $ENV{ET_BUILD_DIR})
ELSE()
  set(ET_BUILD_DIR "et-build")
ENDIF()

MESSAGE(STATUS "Using ET BUILD DIR: --[${ET_BUILD_DIR}]--")

IF(DEFINED ENV{CMAKE_OUT_DIR})
  set(CMAKE_OUT_DIR $ENV{CMAKE_OUT_DIR})
ELSE()
  set(CMAKE_OUT_DIR "cmake-out")
ENDIF()

IF(DEFINED ENV{TORCHCHAT_ROOT})
    set(TORCHCHAT_ROOT $ENV{TORCHCHAT_ROOT})
ELSE()
    set(TORCHCHAT_ROOT ${CMAKE_CURRENT_SOURCE_DIR})
ENDIF()

project(Torchchat)

IF(CMAKE_INSTALL_PREFIX_INITIALIZED_TO_DEFAULT)
  SET(CMAKE_INSTALL_PREFIX ${TORCHCHAT_ROOT}/${ET_BUILD_DIR}/install CACHE PATH "Setting it to a default value" FORCE)
ENDIF(CMAKE_INSTALL_PREFIX_INITIALIZED_TO_DEFAULT)

# Building for Android. Since Android overwrites CMAKE_FIND_ROOT_PATH normal
# CMAKE_INSTALL_PREFIX won't work. Redirect CMAKE_FIND_ROOT_PATH to it.
# This should check any cross compilation but let's do Android for now
if(ANDROID)
  set(CMAKE_FIND_ROOT_PATH "${CMAKE_INSTALL_PREFIX}")
endif()

include(CMakePrintHelpers)
include(runner/Utils.cmake)

cmake_print_variables(TORCHCHAT_ROOT)

MESSAGE(STATUS "Looking for excutorch in ${CMAKE_INSTALL_PREFIX}")

find_package(executorch CONFIG HINTS ${CMAKE_INSTALL_PREFIX})
# For some reason on android cmake is looking for executorch_DIR to be set
# to find executorch
if (ANDROID)
  set(executorch_DIR ${TORCHCHAT_ROOT}/${ET_BUILD_DIR}/install/lib/cmake/ExecuTorch)
  find_package(executorch CONFIG REQUIRED PATHS ${TORCHCHAT_ROOT}/${ET_BUILD_DIR}/install/lib/cmake/ExecuTorch)
endif()

if(executorch_FOUND)
  set(_common_include_directories ${TORCHCHAT_ROOT}/${ET_BUILD_DIR}/src)

  cmake_print_variables(_common_include_directories)

  target_include_directories(executorch INTERFACE ${_common_include_directories}) # Ideally ExecuTorch installation process would do this
  add_executable(et_run runner/run.cpp)

  target_compile_options(et_run PUBLIC -D__ET__MODEL -D_GLIBCXX_USE_CXX11_ABI=1)

  # Link ET runtime + extensions
  target_link_libraries(
    et_run PRIVATE
    executorch
    extension_module
    extension_data_loader
    optimized_kernels
    quantized_kernels
    portable_kernels
    cpublas
    eigen_blas
    # The libraries below need to be whole-archived linked
    optimized_native_cpu_ops_lib
    quantized_ops_lib
    xnnpack_backend
    XNNPACK
    pthreadpool
    cpuinfo
  )
  target_link_options_shared_lib(optimized_native_cpu_ops_lib)
  target_link_options_shared_lib(quantized_ops_lib)
  target_link_options_shared_lib(xnnpack_backend)
  # Not clear why linking executorch as whole-archive outside android/apple is leading
  # to double registration. Most likely because of linkage issues.
  # Will figure this out later. Until then use this.
  if(ANDROID OR APPLE)
    target_link_options_shared_lib(executorch)
  endif()

  target_link_libraries(et_run PRIVATE
  "$<LINK_LIBRARY:WHOLE_ARCHIVE,${TORCHCHAT_ROOT}/${ET_BUILD_DIR}/install/lib/libcustom_ops.a>")
  # This one is needed for cpuinfo where it uses android specific log lib
  if(ANDROID)
    target_link_libraries(et_run PRIVATE log)
  endif()

  # Adding target_link_options_shared_lib as commented out below leads to this:
  #
  # CMake Error at Utils.cmake:22 (target_link_options):
  #   Cannot specify link options for target
  #   "/Users/scroy/etorch/torchchat/et-build/src/executorch/${CMAKE_OUT_DIR}/examples/models/llama2/custom_ops/libcustom_ops_lib.a"
  #   which is not built by this project.
  # Call Stack (most recent call first):
  #   Utils.cmake:30 (macos_kernel_link_options)
  #   CMakeLists.txt:41 (target_link_options_shared_lib)
  #
  #target_link_options_shared_lib("${TORCHCHAT_ROOT}/et-build/src/executorch/${CMAKE_OUT_DIR}/examples/models/llama2/custom_ops/libcustom_ops_lib.a") # This one does not get installed by ExecuTorch

  # This works on mac, but appears to run into issues on linux
  # It is needed to solve:
  # E 00:00:00.055965 executorch:method.cpp:536] Missing operator: [8] llama::sdpa_with_kv_cache.out
else()
  MESSAGE(FATAL_ERROR "Executorch package not found")
endif()
