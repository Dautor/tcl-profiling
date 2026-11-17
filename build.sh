#/bin/sh
set -e

TRACY_DIR="${TRACY_DIR:-tracy}"

CC="${CC:-cc}"
CXX="${CXX:-c++}"

p() {
	echo $@; $@
}

p "$CC"  -fPIC ${CPPFLAGS:-} ${CFLAGS:-} -std=c23 -DUSE_TCL_STUBS -DTRACY_ENABLE -I"$TRACY_DIR/public" -c profiling.c -o profiling.o
p "$CXX" -fPIC ${CPPFLAGS:-} ${CXXFLAGS:-}        -DTRACY_ENABLE                 -I"$TRACY_DIR/public" -c "$TRACY_DIR/public/TracyClient.cpp" -o TracyClient.o

p "$CXX" -shared ${LDFLAGS:-} -o profiling.so profiling.o TracyClient.o -ltclstub8.6 -pthread -ldl
