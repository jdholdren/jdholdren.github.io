.PHONY: dev tools

dev:
	smolblog -manifest=manifest.json

tools:
	go install github.com/jdholdren/smolblog@latest

docs:
	smolblog -manifest=manifest.json -output=docs
