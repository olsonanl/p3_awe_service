TOP_DIR = ../..
TARGET ?= /kb/deployment
DEPLOY_RUNTIME ?= /kb/runtime
SERVICE = p3_awe_service
SERVICE_DIR = $(TARGET)/services/$(SERVICE)

AUTO_DEPLOY_CONFIG ?= deploy.cfg

AWE_REPO = https://github.com/MG-RAST/AWE
AWE_RELEASE_VERSION = v0.9.50
AWE_RELEASE_URL = $(AWE_REPO)/releases/download/v0.9.50

SERVER_SITE_PORT=8001
SERVER_API_PORT=8000
SERVER_URL = http://localhost:$(SERVER_API_PORT)

MONGO_HOST = localhost
MONGO_TIMEOUT = 1200
MONGO_DB = AWEDB_dev
AWE_DIR = $(shell pwd)/awe-install
ADMIN_LIST = 

GLOBUS_TOKEN_URL = https://nexus.api.globusonline.org/goauth/token?grant_type=client_credentials
GLOBUS_PROFILE_URL = https://nexus.api.globusonline.org/users
CLIENT_AUTH_REQUIRED = false

GROUPS = P3_SLEEP
GROUP.P3_SLEEP.NAME = P3-Sleep
GROUP.P3_SLEEP.APPS = App-Sleep
GROUP.P3_SLEEP.CLIENT_COUNT = 4

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
    --define client_logs_dir=$(AWE_DIR)/logs/client \
    --define server_logs_dir=$(AWE_DIR)/logs \
    --define awfs_dir=$(AWE_DIR)/awfs \
    --define mongo_host=$(MONGO_HOST) \
    --define mongo_timeout=$(MONGO_TIMEOUT) \
    --define mongo_db=$(MONGO_DB) \
    --define work_dir=$(AWE_DIR)/work \
    --define server_url=$(SERVER_URL) \
    --define globus_token_url=$(GLOBUS_TOKEN_URL) \
    --define globus_profile_url=$(GLOBUS_PROFILE_URL) \
    --define client_auth_required=$(CLIENT_AUTH_REQUIRED) \
    --define admin_list=$(ADMIN_LIST) \
    --define max_work_failure=$(MAX_WORK_FAILURE) \
    --define max_client_failure=$(MAX_CLIENT_FAILURE) \
    --define awe_path_prefix=$(AWE_PATH_PREFIX) \
    --define awe_path_suffix=$(AWE_PATH_SUFFIX) \
    --define append_service_bins=$(APPEND_SERVICE_BINS)


all: build-awe |

include $(TOP_DIR)/tools/Makefile.common
include $(TOP_DIR)/tools/Makefile.common.rules

.PHONY : test

clean:
	if [ -f $(SERVICE_DIR)/stop_service ]; then $(SERVICE_DIR)/stop_service; fi;
	if [ -f $(SERVICE_DIR)/stop_aweclient ]; then $(SERVICE_DIR)/stop_aweclient; fi;
	-rm -f $(BIN_DIR)/awe-server
	-rm -f $(BIN_DIR)/awe-client
	-rm -f $(BIN_DIR)/awe-worker
	-rm -rf $(SERVICE_DIR)
	-rm -rf $(AWE_DIR)


build-awe: checkout-code $(BIN_DIR)/awe-server $(BIN_DIR)/awe-worker

checkout-code:
	if [ ! -d AWE ] ; then \
		git clone -b $(AWE_RELEASE_VERSION) $(AWE_REPO) ; \
	fi

download/awe-server:
	mkdir -p download
	curl -o $@ -L $(AWE_RELEASE_URL)/`basename $@`
	chmod +x $@

download/awe-worker:
	mkdir -p download
	curl -o $@ -L $(AWE_RELEASE_URL)/`basename $@`
	chmod +x $@

$(BIN_DIR)/awe-server: download/awe-server
	cp -p $^ $@

$(BIN_DIR)/awe-worker: download/awe-worker
	cp -p $^ $@

build-libs:
	-mkdir -p lib/Bio/KBase/AWE
	$(TPAGE) $(TPAGE_ARGS) Constants.pm.tt > lib/Bio/KBase/AWE/Constants.pm

build-dirs:
	mkdir -p $(BIN_DIR) 
	mkdir -p $(SERVICE_DIR) $(SERVICE_DIR)/conf $(SERVICE_DIR)/logs/awe $(SERVICE_DIR)/data/temp
	mkdir -p $(AWE_DIR)/data $(AWE_DIR)/logs/client $(AWE_DIR)/awfs $(AWE_DIR)/work
	chmod 777 $(AWE_DIR)/data $(AWE_DIR)/logs $(AWE_DIR)/logs/client $(AWE_DIR)/awfs $(AWE_DIR)/work

deploy: deploy-service deploy-client

deploy-awe-libs:
	rsync --exclude '*.bak' -arv AWE/utils/lib/. $(TARGET)/lib/.

deploy-client: build-libs deploy-binaries deploy-utils deploy-libs deploy-awe-libs deploy-awe-worker

deploy-service: build-libs deploy-binaries deploy-libs deploy-awe-libs deploy-awe-server

deploy-binaries: build-awe 
	cp $(BIN_DIR)/awe-server $(TARGET)/bin
	cp $(BIN_DIR)/awe-worker $(TARGET)/bin

deploy-awe-server: 
	mkdir -p $(SERVICE_DIR)/conf
	$(TPAGE) $(TPAGE_ARGS) awe_server.cfg.tt > $(SERVICE_DIR)/conf/awe.cfg
	$(TPAGE) $(TPAGE_ARGS) AWE/site/js/config.js.tt > AWE/site/js/config.js
	rsync -arv --exclude=.git AWE/site $(AWE_DIR)/.

	cp -r AWE/templates/awf_templates/* $(AWE_DIR)/awfs/
	$(TPAGE) $(TPAGE_ARGS) service/start_service.tt > service/start_service
	$(TPAGE) $(TPAGE_ARGS) service/stop_service.tt > service/stop_service
	cp service/start_service $(SERVICE_DIR)/
	chmod +x $(SERVICE_DIR)/start_service
	cp service/stop_service $(SERVICE_DIR)/
	chmod +x $(SERVICE_DIR)/stop_service

deploy-awe-worker: 
	mkdir -p $(SERVICE_DIR)/conf
	perl build-client-configs.pl $(TPAGE_ARGS) $(AUTO_DEPLOY_CONFIG) $(SERVICE) $(SERVICE_DIR)/conf awec.%s.cfg
	for cli in start_awe_client_group stop_awe_client_group; do \
		$(TPAGE) $(TPAGE_ARGS) service/$$cli.tt > service/$$cli ; \
		chmod +x service/$$cli; \
		cp -p service/$$cli $(SERVICE_DIR)/ ; \
	done
	$(TPAGE) $(TPAGE_ARGS) service/monitrc.tt > service/monitrc
	cp service/monitrc $(SERVICE_DIR)/monitrc
	chmod go-rwx $(SERVICE_DIR)/monitrc

deploy-upstart:
	$(TPAGE) $(TPAGE_ARGS) init/awe.conf.tt > /etc/init/awe.conf
	$(TPAGE) $(TPAGE_ARGS) init/awe-client.conf.tt > /etc/init/awe-client.conf

deploy-utils: SRC_PERL = $(wildcard AWE/utils/*.pl)
deploy-utils: deploy-scripts
