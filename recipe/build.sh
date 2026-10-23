#!/bin/bash

set -euxo pipefail

if [[ "${target_platform}" == osx-* ]]; then
    # See also https://gitlab.kitware.com/cmake/cmake/-/issues/25755
    export CFLAGS="${CFLAGS} -fno-define-target-os-macros -target ${HOST}"
    export LDFLAGS="${LDFLAGS} -target ${HOST}"
fi

source gen-bazel-toolchain

PROTOC_VERSION=$(${BUILD_PREFIX}/bin/protoc --version | cut -d" " -f2)
sed -i.bak "s/PROTOC_VERSION/${PROTOC_VERSION}/" third_party/systemlibs/protobuf/MODULE.bazel
cp -R ${PREFIX}/share/bazel/protobuf/bazel third_party/systemlibs/protobuf/
ln -s ${BUILD_PREFIX}/bin/protoc third_party/systemlibs/protobuf/protoc

chmod +x bazel-${PKG_VERSION}
pushd src/tools/singlejar
../../../bazel-${PKG_VERSION} build \
	--logging=6 \
	--subcommands \
	--verbose_failures \
	--@com_google_protobuf//bazel/flags:allow_nonstandard_protoc=true \
	--extra_toolchains=//bazel_toolchain:cc_cf_toolchain \
	--extra_toolchains=//bazel_toolchain:cc_cf_host_toolchain \
	--platforms=//bazel_toolchain:target_platform \
	--host_platform=//bazel_toolchain:build_platform \
	--cpu ${TARGET_CPU} \
	singlejar singlejar_local
mkdir -p $PREFIX/bin
cp ../../../bazel-out/${TARGET_CPU}-fastbuild/bin/src/tools/singlejar/singlejar $PREFIX/bin
cp ../../../bazel-out/${TARGET_CPU}-fastbuild/bin/src/tools/singlejar/singlejar_local $PREFIX/bin

if [[ "${target_platform}" == linux-* ]]; then
    chmod +w $PREFIX/bin/singlejar $PREFIX/bin/singlejar_local
    patchelf --set-rpath '$ORIGIN/../lib' $PREFIX/bin/singlejar $PREFIX/bin/singlejar_local
fi
