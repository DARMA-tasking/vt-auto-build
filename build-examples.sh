#!/bin/bash

if test $# -lt 1
then
    echo "usage $0 <build-mode> [frontend-dir] [backend-dir]"
    exit 1;
fi

build_mode=$1

root_dir_codes=/Users/jliffla/codes/

c_compiler=clang-mp-3.9
cxx_compiler=clang++-mp-3.9

if test $# -gt 1
then
    darma_frontend_dir=$2
else
    darma_frontend_dir=${root_dir_codes}/frontend-install
fi

darma_frontend_inc_dir=${darma_frontend_dir}/include
darma_frontend_con_dir=${darma_frontend_dir}/cmake
darma_frontend_lib_dir=${darma_frontend_dir}/lib

# darma_backend_libname=DarmaMPIBackend

if test $# -gt 2
then
    darma_backend_package=$3
else
    darma_backend_package=${root_dir_codes}/backend-install
fi

darma_backend_libname=darma_mpi_backend
darma_backend_dir=${darma_backend_package}
darma_backend_inc_dir=${darma_backend_package}/include
darma_backend_con_dir=${darma_backend_package}/cmake
darma_backend_lib_dir=${darma_backend_package}/lib

cmake ../examples \
      -DCMAKE_INSTALL_PREFIX=../examples-install \
      -DCMAKE_BUILD_TYPE=${build_mode} \
      -DCMAKE_CXX_COMPILER=${cxx_compiler} \
      -DCMAKE_C_COMPILER=${c_compiler} \
      -Ddarma_DIR=${darma_backend_package} \
      -DDARMA_FRONTEND_DIR=${darma_frontend_dir} \
      -DDARMA_FRONTEND_INCLUDE_DIR=${darma_frontend_inc_dir} \
      -DDARMA_FRONTEND_CONFIG_DIR=${darma_frontend_con_dir} \
      -DDARMA_BACKEND_LIBNAME=${darma_backend_libname} \
      -DDARMA_BACKEND_DIR=${darma_backend_dir} \
      -DDARMA_BACKEND_LIB_DIR=${darma_backend_lib_dir} \
      -DDARMA_BACKEND_INCLUDE_DIR=${darma_backend_inc_dir} \
      -DDARMA_BACKEND_CONFIG_DIR=${darma_backend_con_dir} \
      -DCMAKE_EXPORT_COMPILE_COMMANDS=true
