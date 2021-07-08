# Makefile for perfSONAR Logstash pipeline
#
PACKAGE=perfsonar-logstash
ROOTPATH=/usr/lib/perfsonar/logstash
CONFIGPATH=/etc/perfsonar/logstash
PERFSONAR_AUTO_VERSION=4.4.0
PERFSONAR_AUTO_RELNUM=0.0.a1
VERSION=${PERFSONAR_AUTO_VERSION}
RELEASE=${PERFSONAR_AUTO_RELNUM}
DC_CMD_BASE=docker-compose
DC_CMD=${DC_CMD_BASE} -p ${PACKAGE}

default: build

local:
	touch .env
	cp -f ./ansible/vars/env.local.yml ./ansible/vars/env.yml

release:
	touch .env
	cp -f ./ansible/vars/env.release.yml ./ansible/vars/env.yml

build: dc_clean
	${DC_CMD} -f docker-compose.make.yml up ansible_runner
	${DC_CMD} -f docker-compose.make.yml down -v

docker: build
	${DC_CMD} build logstash

centos7: clean release build
	mkdir -p ./artifacts/centos7
	${DC_CMD} -f docker-compose.qa.yml up --build --no-start centos7
	docker cp ${PACKAGE}_centos7_1:/root/rpmbuild/SRPMS ./artifacts/centos7/srpms
	docker cp ${PACKAGE}_centos7_1:/root/rpmbuild/RPMS/noarch ./artifacts/centos7/rpms

dist:
	mkdir /tmp/$(PACKAGE)-$(VERSION).$(RELEASE)
	cp -rf . /tmp/$(PACKAGE)-$(VERSION).$(RELEASE)
	tar czf $(PACKAGE)-$(VERSION).$(RELEASE).tar.gz -C /tmp $(PACKAGE)-$(VERSION).$(RELEASE)
	rm -rf /tmp/$(PACKAGE)-$(VERSION).$(RELEASE)

install:
	mkdir -p ${ROOTPATH}/pipeline
	mkdir -p ${ROOTPATH}/ruby
	mkdir -p ${ROOTPATH}/scripts
	mkdir -p ${CONFIGPATH}
	cp -r pipeline/* ${ROOTPATH}/pipeline
	cp -r ruby/* ${ROOTPATH}/ruby
	cp -r scripts/* ${ROOTPATH}/scripts
	cp -r pipeline_etc/* ${CONFIGPATH}

# Some of the jobs require the containers to be down. Detects if we have 
# already generated a docker-compose.yml and stops containers accordingly
# Uses ${DC_CMD} and ${DC_CMD_BASE} to cleanup both default and non-default images
dc_clean:
ifneq ("$(wildcard ./docker-compose.yml)","")
	${DC_CMD} -f docker-compose.yml -f docker-compose.qa.yml -f docker-compose.make.yml down -v
	${DC_CMD_BASE} -f docker-compose.yml -f docker-compose.qa.yml -f docker-compose.make.yml down -v
else
	${DC_CMD} -f docker-compose.qa.yml -f docker-compose.make.yml down -v
	${DC_CMD_BASE} -f docker-compose.qa.yml -f docker-compose.make.yml down -v
endif

clean:
	rm -f docker-compose.yml .env pipeline/01-inputs.conf pipeline/99-outputs.conf
	rm -rf artifacts/
