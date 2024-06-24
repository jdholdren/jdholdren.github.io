.PHONY: dev tools

dev:
	smolblog -manifest=manifest.json

tools:
	go install github.com/jdholdren/smolblog@v0.2.1

build:
	smolblog -manifest=manifest.json -output=build
