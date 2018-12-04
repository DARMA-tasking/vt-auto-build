#!/bin/bash

if test $# -lt 2
then
    echo "usage $0 <build-mode>"
    exit 1;
fi

build_mode=$1

compiler_c=clang-mp-3.9
compiler_cxx=clang++-mp-3.9

if test $# -gt 1; then compiler_c=$2; fi
if test $# -gt 2; then compiler_cxx=$3; fi

has_ccache=`which ccache`

if test $? -eq 0
then
    maybe_ccache="-DCMAKE_CXX_COMPILER_LAUNCHER=ccache "
else
    maybe_ccache=""
fi

cmake ../fmt                                                           \
      -DCMAKE_INSTALL_PREFIX=../fmt-install                            \
      -DCMAKE_CXX_COMPILER=${compiler_cxx}                             \
      -DCMAKE_C_COMPILER=${compiler_c}                                 \
      -DCMAKE_BUILD_TYPE=${build_mode}                                 \
      -DCMAKE_EXPORT_COMPILE_COMMANDS=true                             \
      ${maybe_ccache}

# cmake ../fmt/ -DCMAKE_INSTALL_PREFIX=../fmt-gnu-install
#   -DCMAKE_BUILD_TYPE=Release  -DCMAKE_CXX_COMPILER=mpicxx-mpich-devel-gcc6
#   -DCMAKE_C_COMPILER=mpicc-mpich-devel-gcc6
