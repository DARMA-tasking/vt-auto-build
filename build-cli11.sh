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

cmake ../cli11                                                         \
      -DCMAKE_INSTALL_PREFIX=../cli11-install                          \
      -DCMAKE_CXX_COMPILER=${compiler_cxx}                             \
      -DCMAKE_C_COMPILER=${compiler_c}                                 \
      -DCMAKE_BUILD_TYPE=${build_mode}                                 \
      -DCLI11_TESTING:BOOL=OFF                                         \
      -DCMAKE_EXPORT_COMPILE_COMMANDS=true

