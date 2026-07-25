RUST_TOOLCHAIN_NIGHTLY = nightly-2026-01-22

nightly = +${RUST_TOOLCHAIN_NIGHTLY}
# Convert 'programs/anything' to 'anything'.
program-target = $(subst /,-,$(patsubst programs/%,%,$1))
# All files directly inside programs.
PROGRAMS := $(wildcard programs/*)
# Generate the dashed target program names.
PROGRAM_TARGETS := $(foreach src,$(PROGRAMS),$(call program-target,$(src)))

# Hand-written assembly programs live in assembly/<name>/<name>.s, each with its
# own linker script assembly/<name>/<name>.ld.
ASM_PROGRAMS := $(wildcard assembly/*/)
ASM_TARGETS := $(foreach src,$(ASM_PROGRAMS),$(notdir $(patsubst %/,%,$(src))))
BUILD_ASM_TARGETS := $(addprefix build-asm-,$(ASM_TARGETS))

# Pinned platform-tools LLVM toolchain (matches `cargo-build-sbf` -> platform-tools v1.54).
PLATFORM_TOOLS_VERSION = v1.54
LLVM := $(HOME)/.cache/solana/$(PLATFORM_TOOLS_VERSION)/platform-tools/llvm/bin
# Output alongside the Rust programs so `make test` (SBF_OUT_DIR) finds the .so.
DEPLOY_DIR := target/deploy
# SBPF version. NB: cargo-build-sbf's `--arch v3` emits SBPF *V4* (ABIv2's
# register-passing entrypoint is V4-gated), so clang uses -mcpu=v4 to match.
SBF_MCPU := v4

# Run `cargo bench`.
bench:
	@cargo bench $(ARGS)

# Build all programs.
all:
	@for dir in $(PROGRAM_TARGETS); do \
		$(MAKE) build-$$dir; \
	done
	@$(MAKE) build-asm

# Build a program.
build-%:
	@RUSTFLAGS="-C embed-bitcode=yes -C lto=fat" cargo build-sbf --manifest-path programs/$*/Cargo.toml --arch v3 --abi-v2 $(ARGS)

.PHONY: build-asm $(BUILD_ASM_TARGETS)
build-asm: $(BUILD_ASM_TARGETS)

$(BUILD_ASM_TARGETS): build-asm-%:
	@mkdir -p $(DEPLOY_DIR)
	@$(LLVM)/clang -target sbf -mcpu=$(SBF_MCPU) -c assembly/$*/$*.s -o $(DEPLOY_DIR)/$*.o
	@$(LLVM)/ld.lld --threads=1 -z notext -shared \
		-T assembly/$*/$*.ld $(DEPLOY_DIR)/$*.o -o $(DEPLOY_DIR)/$*.so
	@$(LLVM)/llvm-objcopy --strip-sections $(DEPLOY_DIR)/$*.so
	@rm -f $(DEPLOY_DIR)/$*.o
	@echo "✅ built $(DEPLOY_DIR)/$*.so"

# Run `cargo clean`.
clean:
	@cargo clean

# Run `cargo clippy`.
clippy:
	@cargo clippy \
		--workspace --all-targets -- \
		--deny=warnings \
		--deny=clippy::default_trait_access \
		--deny=clippy::arithmetic_side_effects \
		--deny=clippy::manual_let_else \
		--deny=clippy::used_underscore_binding

# Run `cargo fmt`.
format:
	@cargo $(nightly) fmt --all $(ARGS)

test:
	SBF_OUT_DIR=$(PWD)/target/deploy cargo test --manifest-path benchmark/Cargo.toml $(ARGS)
