.PHONY: all prepare build clean oc-create-build oc-start-build
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

oc-create-build:
	@oc new-build --name collectd-operator --dockerfile - < $(BUILD_DIR)/Dockerfile

oc-start-build:
	@oc start-build collectd-operator --wait --from-dir .

clean:
	@ansible-galaxy remove infrawatch.collectd-config
	@buildah rmi infrawatch/collectd-operator
