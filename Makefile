#!/usr/bin/make
REBAR=./rebar
CT=./covertool
EUNIT_DIR=./.eunit
SRC_DIR=./src

all: clean deps compile test
deps:
				@$(REBAR) get-deps
clean:
				@$(REBAR) clean
compile: deps
				@$(REBAR) compile

test:
				@$(REBAR) compile eunit skip_deps=true
				@$(CT) -cover $(EUNIT_DIR)/eunit.coverdata -output $(EUNIT_DIR)/coverage.xml -src $(SRC_DIR)
