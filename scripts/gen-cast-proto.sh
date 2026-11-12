#!/bin/sh
mkdir -p "$1/src/cast"
protoc --c_out="$1/src/cast" --proto_path="$2/src/cast" "$2/src/cast/cast.proto"
cp "$1/src/cast/cast.pb-c.c" "$1/cast.pb-c.c"
cp "$1/src/cast/cast.pb-c.h" "$1/cast.pb-c.h"
