# __APP__ — make targets (driven by keenetic-dev or standalone)
VERSION ?= 0.1.0
NAME    ?= __APP__
ARCH    ?= aarch64-3.10

.PHONY: build ipk feed deploy clean

build:
	keenetic-dev build --version $(VERSION)

ipk: build
	keenetic-dev ipk --bin dist/$(NAME)_linux_arm64 --arch $(ARCH) --version $(VERSION)

ipk-all: build
	@for a in aarch64-3.10 armv7-3.2 mipsel-3.4 mips-3.4; do \
	  case $$a in aarch64-3.10) g=arm64;; armv7-3.2) g=arm;; mipsel-3.4) g=mipsle;; mips-3.4) g=mips;; esac; \
	  keenetic-dev ipk --bin dist/$(NAME)_linux_$$g --arch $$a --version $(VERSION) || exit 1; \
	done

feed: ipk-all
	keenetic-dev feed --dir dist

deploy: build
	keenetic-dev deploy --bin dist/$(NAME)_linux_arm64

clean:
	rm -rf dist
