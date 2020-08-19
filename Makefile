.PHONY: all prepare build clean
BUILD = upstream
BUILD_DIR = ./build
ROOTDIR = $(realpath .)
NAME = $(notdir $(ROOTDIR))
ROLES_PATH = ./roles/

all: prepare build

prepare:
	@ansible-galaxy install -r requirements.yml --roles-path $(ROLES_PATH)

build:
	@buildah bud -f ${BUILD_DIR}/Dockerfile -t infrawatch/collectd-operator .

clean:
	@ansible-galaxy remove infrawatch.collectd-config
	@buildah rmi infrawatch/collectd-operator
