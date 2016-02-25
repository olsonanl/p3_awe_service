TOP_DIR = ../..
TARGET ?= /kb/deployment
DEPLOY_RUNTIME ?= /kb/runtime
SERVICE = awe_service
SERVICE_DIR = $(TARGET)/services/$(SERVICE)

SERVER_URL = http://localhost:8000
GO_TMP_DIR = /tmp/go_build.tmp
CLIENT_GROUP = kbase
CLIENT_NAME = $(CLIENT_GROUP)-client
APP_LIST = '*'
PRODUCTION = 0

MONGO_HOST = localhost
MONGO_TIMEOUT = 1200
MONGO_DB = AWEDB
AWE_DIR = /mnt/awe
ADMIN_LIST = 

N_AWE_CLIENTS=1

GLOBUS_TOKEN_URL = https://nexus.api.globusonline.org/goauth/token?grant_type=client_credentials
GLOBUS_PROFILE_URL = https://nexus.api.globusonline.org/users
CLIENT_AUTH_REQUIRED = false

ifeq ($(PRODUCTION), 1)

    AWE_DIR = /disk0/awe
	
    SERVER_SITE_URL = https://kbase.us/services/awe
    SERVER_URL = https://kbase.us/services/awe-api
    SERVER_API_PORT = 7107
    SERVER_SITE_PORT = 7106

else

    APP_LIST = $(shell ls $(TARGET)/bin | perl -e '@a = <>; chomp @a; print join(",", @a)')
    SERVER_URL =
    SERVER_SITE_URL =

    ifneq ($(SERVER_URL),)
    SERVER_API_PORT = $(shell perl -MURI -e "print URI->new('$(SERVER_URL)')->port")
    endif

    ifneq ($(SERVER_SITE_URL),)
    SERVER_SITE_PORT = $(shell perl -MURI -e "print URI->new('$(SERVER_SITE_URL)')->port")
    endif


endif

TPAGE_ARGS = --define kb_top=$(TARGET) \
    --define kb_runtime=$(DEPLOY_RUNTIME) \
    --define kb_service_dir=$(SERVICE) \
    --define kb_service_name=$(SERVICE) \
    --define site_url=$(SERVER_SITE_URL) \
    --define api_url=$(SERVER_URL) \
    --define site_port=$(SERVER_SITE_PORT) \
    --define api_port=$(SERVER_API_PORT) \
    --define site_dir=$(AWE_DIR)/site \
    --define data_dir=$(AWE_DIR)/data \
    --define logs_dir=$(AWE_DIR)/logs \
    --define awfs_dir=$(AWE_DIR)/awfs \
    --define mongo_host=$(MONGO_HOST) \
    --define mongo_timeout=$(MONGO_TIMEOUT) \
    --define mongo_db=$(MONGO_DB) \
    --define work_dir=$(AWE_DIR)/work \
    --define server_url=$(SERVER_URL) \
    --define client_group=$(CLIENT_GROUP) \
    --define client_name=$(CLIENT_NAME) \
    --define supported_apps=$(APP_LIST) \
    --define globus_token_url=$(GLOBUS_TOKEN_URL) \
    --define globus_profile_url=$(GLOBUS_PROFILE_URL) \
    --define client_auth_required=$(CLIENT_AUTH_REQUIRED) \
    --define admin_list=$(ADMIN_LIST) \
    --define n_awe_clients=$(N_AWE_CLIENTS) \
    --define max_work_failure=$(MAX_WORK_FAILURE) \
    --define max_client_failure=$(MAX_CLIENT_FAILURE) \
    --define awe_path_prefix=$(AWE_PATH_PREFIX) \
    --define awe_path_suffix=$(AWE_PATH_SUFFIX) \
    --define append_service_bins=$(APPEND_SERVICE_BINS)


all: initialize build-awe |

include $(TOP_DIR)/tools/Makefile.common
include $(TOP_DIR)/tools/Makefile.common.rules

.PHONY : test

clean:
	if [ -f $(SERVICE_DIR)/stop_service ]; then $(SERVICE_DIR)/stop_service; fi;
	if [ -f $(SERVICE_DIR)/stop_aweclient ]; then $(SERVICE_DIR)/stop_aweclient; fi;
	-rm -f $(BIN_DIR)/awe-server
	-rm -f $(BIN_DIR)/awe-client
	-rm -rf $(SERVICE_DIR)
	-rm -rf $(AWE_DIR)


build-awe: $(BIN_DIR)/awe-server

build-update: update build-awe |

$(BIN_DIR)/awe-server: AWE/awe-server/awe-server.go
	rm -rf $(GO_TMP_DIR)
	mkdir -p $(GO_TMP_DIR)/src/github.com/MG-RAST
	cp -r AWE $(GO_TMP_DIR)/src/github.com/MG-RAST/
	mkdir -p $(GO_TMP_DIR)/src/github.com/docker
	wget -O $(GO_TMP_DIR)/src/github.com/docker/docker.zip https://github.com/docker/docker/archive/v1.6.1.zip
	unzip -d $(GO_TMP_DIR)/src/github.com/docker $(GO_TMP_DIR)/src/github.com/docker/docker.zip
	mv -v $(GO_TMP_DIR)/src/github.com/docker/docker-1.6.1 $(GO_TMP_DIR)/src/github.com/docker/docker
	export GOPATH=$(GO_TMP_DIR); go get -v github.com/MG-RAST/AWE/...
	cp -v $(GO_TMP_DIR)/bin/awe-server $(BIN_DIR)/awe-server
	cp -v $(GO_TMP_DIR)/bin/awe-client $(BIN_DIR)/awe-client

build-libs:
	-mkdir -p lib/Bio/KBase/AWE
	$(TPAGE) $(TPAGE_ARGS) Constants.pm.tt > lib/Bio/KBase/AWE/Constants.pm

build-dirs:
	mkdir -p $(BIN_DIR) $(SERVICE_DIR) $(SERVICE_DIR)/conf $(SERVICE_DIR)/logs/awe $(SERVICE_DIR)/data/temp
	mkdir -p $(AWE_DIR)/data $(AWE_DIR)/logs $(AWE_DIR)/awfs $(AWE_DIR)/work
	chmod 777 $(AWE_DIR)/data $(AWE_DIR)/logs $(AWE_DIR)/awfs $(AWE_DIR)/work

deploy: deploy-service deploy-client deploy-utils deploy-libs deploy-awe-libs

deploy-awe-libs:
	rsync --exclude '*.bak' -arv AWE/utils/lib/. $(TARGET)/lib/.

deploy-client: build-libs deploy-utils deploy-libs deploy-awe-libs

deploy-service: build-libs deploy-awe-server deploy-awe-client deploy-libs deploy-awe-libs

deploy-awe-server: all build-dirs build-awe
	cp $(BIN_DIR)/awe-server $(TARGET)/bin
	$(TPAGE) $(TPAGE_ARGS) awe_server.cfg.tt > awe.cfg
	$(TPAGE) $(TPAGE_ARGS) AWE/site/js/config.js.tt > AWE/site/js/config.js
	rsync -arv --exclude=.git AWE/site $(AWE_DIR)/.
	#cp -v -r AWE/site $(AWE_DIR)/site
	mkdir -p $(BIN_DIR) $(SERVICE_DIR) $(SERVICE_DIR)/conf $(SERVICE_DIR)/logs/awe $(SERVICE_DIR)/data/temp
	cp -v awe.cfg $(SERVICE_DIR)/conf/awe.cfg
	cp -r AWE/templates/awf_templates/* $(AWE_DIR)/awfs/
	$(TPAGE) $(TPAGE_ARGS) service/start_service.tt > service/start_service
	$(TPAGE) $(TPAGE_ARGS) service/stop_service.tt > service/stop_service
	cp service/start_service $(SERVICE_DIR)/
	chmod +x $(SERVICE_DIR)/start_service
	cp service/stop_service $(SERVICE_DIR)/
	chmod +x $(SERVICE_DIR)/stop_service

deploy-awe-client: all build-dirs build-awe
	cp $(BIN_DIR)/awe-client $(TARGET)/bin
	id=1; while [ $$id -le $(N_AWE_CLIENTS) ] ; do \
	    $(TPAGE) $(TPAGE_ARGS) --define client_index=$$id awe_client.cfg.tt > awec.$$id.cfg; \
	    cp -v awec.$$id.cfg $(SERVICE_DIR)/conf/awec.$$id.cfg; \
	    id=`expr $$id + 1`; \
	done
	$(TPAGE) $(TPAGE_ARGS) awe_client.cfg.tt > awec.cfg
	cp -v awec.cfg $(SERVICE_DIR)/conf/awec.cfg
	$(TPAGE) $(TPAGE_ARGS) service/start_aweclient.tt > service/start_aweclient
	$(TPAGE) $(TPAGE_ARGS) service/stop_aweclient.tt > service/stop_aweclient
	cp service/start_aweclient $(SERVICE_DIR)/
	chmod +x $(SERVICE_DIR)/start_aweclient
	cp service/stop_aweclient $(SERVICE_DIR)/
	chmod +x $(SERVICE_DIR)/stop_aweclient
	$(TPAGE) $(TPAGE_ARGS) service/monitrc.tt > service/monitrc
	cp service/monitrc $(SERVICE_DIR)/monitrc
	chmod go-rwx $(SERVICE_DIR)/monitrc

deploy-upstart:
	$(TPAGE) $(TPAGE_ARGS) init/awe.conf.tt > /etc/init/awe.conf
	$(TPAGE) $(TPAGE_ARGS) init/awe-client.conf.tt > /etc/init/awe-client.conf

initialize:
	git submodule init
	git submodule update --init --recursive

update:
	cd AWE; git pull origin master

deploy-utils: SRC_PERL = $(wildcard AWE/utils/*.pl)
deploy-utils: deploy-scripts
