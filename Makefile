BINARY ?= liquent_node
FEATURE ?=
MODE ?= release

BIN_DIRS := liquent_node bench kvstore liquent_cli
BIN_PATHS := $(addprefix bin/, $(BIN_DIRS))

ifeq ($(MODE),release)
    CARGO_FLAGS := --release
else ifeq ($(MODE),quick-release)
    CARGO_FLAGS := --profile quick-release
else
    CARGO_FLAGS :=
endif

CARGO_FEATURES := $(if $(FEATURE),--features $(FEATURE),)

.PHONY: all $(BIN_DIRS) clean

all: $(BINARY)

liquent_node:
	RUSTFLAGS="--cfg tokio_unstable" cargo build -p liquent_node $(CARGO_FLAGS) $(CARGO_FEATURES)

bench:
	cargo build -p bench $(CARGO_FLAGS) $(CARGO_FEATURES)

kvstore:
	cargo build -p kvstore $(CARGO_FLAGS) $(CARGO_FEATURES)

liquent_cli:
	RUSTFLAGS="--cfg tokio_unstable" cargo build -p liquent_cli $(CARGO_FLAGS) $(CARGO_FEATURES)

clean:
	for dir in $(BIN_PATHS); do \
		(cd $$dir && cargo clean); \
	done