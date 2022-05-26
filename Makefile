# SPDX-License-Identifier: BSD-3-Clause
# Copyright (c) 2019-2022 Intel Corporation

#
# Head Makefile for compiling CNDP, but just a wrapper around
# meson and ninja using the tools/cnd-build.sh script.
#
# Use 'make' or 'make build' to build CNDP. If the build directory does
# not exist it will be created with these two build types.
#

docker-image: FORCE
	docker build -t quay.io/mtahhan/cndp-fedora-frr -f docker/Dockerfile .

FORCE:
