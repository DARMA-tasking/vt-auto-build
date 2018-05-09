#!/bin/bash

if test $# -lt 1
then
    echo "usage $0 <build-mode>"
    exit 1;
fi

build_mode=$1

root_dir_lib=/Users/jliffla/codes/
gtest_directory=${root_dir_lib}/gtest/gtest-install

c_compiler=clang-mp-3.9
cxx_compiler=clang++-mp-3.9

cmake ../frontend \
      -DCMAKE_INSTALL_PREFIX=../frontend-install \
      -DCMAKE_CXX_COMPILER=${cxx_compiler} \
      -DCMAKE_C_COMPILER=${c_compiler} \
      -DGTEST_DIR=${gtest_directory} \
      -DCMAKE_BUILD_TYPE=${build_mode} \
      -DCMAKE_EXPORT_COMPILE_COMMANDS=true
