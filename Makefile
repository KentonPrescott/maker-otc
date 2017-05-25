SHELL = bash

export ETH_GAS = 4000000
export SOLC_FLAGS = --optimize

lifetime = $(shell echo $$((60*60*24*365)))

all:; dapp build
test:; dapp test
deploy:; dapp create AuthMarket $(lifetime)
