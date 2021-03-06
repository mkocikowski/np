SHELL:=/bin/bash

HASH:=$(shell git rev-parse --short HEAD)
DATE:=$(shell date -u '+%Y-%m-%dT%H:%M:%SZ')

.PHONY: test
test: gotest args 100k long

.PHONY: gotest
gotest:
	go test -v

.PHONY: 100k
100k: fan
	# test processing 100k short lines
	for i in {1..100000} ; do echo $$i ; done >/tmp/$@.in
	cat /tmp/$@.in | ./$< -n=4 python cat.py | sort --general-numeric-sort >/tmp/$@.out
	diff /tmp/$@.*

.PHONY: long
long: fan
	@# `printf '%s' {1..200000}` generates just over 1MiB, and is 7x faster than `printf '.%.0s' {1..1048576}`
	@# setting the number to 2500000 will yield about 16MiB
	# test processing 4 ~1MiB lines
	for i in {1..4} ; do echo `printf '%s' {1..200000}` ; done >/tmp/$@.in
	# setting n=16 even though there are only 4 lines to check if this is a problem
	cat /tmp/$@.in | ./$< -n=16 python cat.py >/tmp/$@.out
	diff /tmp/$@.*

# test command line args
.PHONY: args
args: fan
	# test missing command
	echo "ok" | ./$< 2>/dev/null ; test "$$?" == "1"
	# test invalid n
	echo "ok" | ./$< -n=666 2>/dev/null ; test "$$?" == "1"
	echo "ok" | ./$< -n=-99 2>/dev/null ; test "$$?" == "1"
	echo "ok" | ./$< -n=foo 2>/dev/null ; test "$$?" == "2"
	# smoke test correct invocation
	echo "ok" | ./$< cat >/dev/null ; test "$$?" == "0"

.PHONY: install
install: /usr/local/bin/fan

/usr/local/bin/fan: fan
	cp $< /usr/local/bin/fan

.INTERMEDIATE: fan
fan: fan.go
	go build \
		-ldflags "-X main.BuildHash=$(HASH) -X main.BuildDate=$(DATE)" \
		-o $@ $<

dist: fan-linux-amd64 fan-darwin-amd64

.INTERMEDIATE: fan-linux-amd64
.INTERMEDIATE: fan-darwin-amd64
fan-%-amd64: URL=gs://peakunicorn/bin/amd64/$*/fan
fan-%-amd64: fan.go test
	GOARCH=amd64 GOOS=$* go build \
		-ldflags "-X main.BuildHash=$(HASH) -X main.BuildDate=$(DATE)" \
		-o $@ $<
	gsutil cp $@ $(URL)
	gsutil setmeta -h "Cache-Control:public, max-age=60" $(URL)
	gsutil acl ch -u AllUsers:R $(URL)

