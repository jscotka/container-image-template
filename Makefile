.PHONY: dg doc build run test clean

DISTRO = fedora-26-x86_64
VERSION = 2.4
VARIANT = upstream
DG = /usr/bin/dg
GOMD2MAN = /usr/bin/go-md2man
DOCKERFILE_SRC := Dockerfile.template
DOCKERFILE := Dockerfile
TEST_IMAGE_NAME := container-images-tests

SELECTORS = --distro ${DISTRO}.yaml --multispec-selector version=${VERSION} --multispec-selector variant=${VARIANT}
DG_EXEC = ${DG} --max-passes 25 --spec specs/common.yml --multispec specs/multispec.yml ${SELECTORS}
DISTRO_ID = $(shell ${DG_EXEC} --template "{{ config.os.id }}")
TAG = ${DISTRO_ID}/awesome:${VERSION}


non_default_dependencies:
	dnf install -q -y /usr/bin/go-md2man /usr/bin/dg /usr/bin/s2i

non_default_testdependencies:
	dnf copr enable phracek/meta-test-family-devel
	dnf install -q -y python2-tests python3-tests meta-test-family  ...

dg:
	${DG_EXEC} --template $(DOCKERFILE_SRC) --output $(DOCKERFILE)
	${DG_EXEC} --template help/help.md --output help/help.md.rendered

doc: dg
	mkdir -p ./root/
	${GOMD2MAN} -in=help/help.md.rendered -out=./root/help.1

build: non_default_dependencies doc dg
	docker build --tag=${TAG} -f $(DOCKERFILE) .

run: build
	docker run -p 9000:9000 -d ${TAG}

test: build non_default_testdependencies MODULE=docker URL="docker=${TAG}" DOCKERFILE="../$(DOCKERFILE)" VERSION=${VERSION} DISTRO=${DISTRO}
	cd tests; mtf -l *.py

test-in-container: test-image
	docker run --rm -ti -v /var/run/docker.sock:/var/run/docker.sock:Z -v ${PWD}:/src ${TEST_IMAGE_NAME} "SELECTORS=${SELECTORS}"

test-image:
	docker build --tag=${TEST_IMAGE_NAME} -f ./Dockerfile.tests .

clean:
	rm -f $(DOCKERFILE)
	rm -f help/help.md.*
	rm -rf root
