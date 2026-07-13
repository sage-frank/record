.PHONY: build run release start stop restart logs clean deploy status

BINARY := target/release/record-api
LOG_FILE := /root/record-log.log

# ── 开发 ────────────────────────────────

build:
	cargo build

run:
	cargo run

check:
	cargo check

fmt:
	cargo fmt

lint:
	cargo clippy -- -D warnings

test:
	cargo test

# ── 发布构建 ────────────────────────────

release:
	cargo build --release
	@echo "Binary: $(BINARY)"
	@ls -lh $(BINARY)

# ── 服务管理 ────────────────────────────

start:
	@if [ -f $(BINARY) ]; then \
		nohup $(BINARY) >> $(LOG_FILE) 2>&1 & \
		echo "Started PID=$$!"; \
	else \
		echo "Binary not found, run: make release"; \
		exit 1; \
	fi

stop:
	@PID=$$(ps -ef | grep "$(BINARY)" | grep -v grep | awk '{print $$2}'); \
	if [ -n "$$PID" ]; then \
		kill $$PID && echo "Stopped PID=$$PID"; \
	else \
		echo "Not running"; \
	fi

restart: stop release start

status:
	@PID=$$(ps -ef | grep "$(BINARY)" | grep -v grep | awk '{print $$2}'); \
	if [ -n "$$PID" ]; then \
		echo "Running PID=$$PID"; \
		ps -p $$PID -o pid,ppid,pcpu,pmem,etime,cmd --no-headers; \
	else \
		echo "Not running"; \
	fi

logs:
	@tail -f $(LOG_FILE)

logs100:
	@tail -n 100 $(LOG_FILE)

# ── 清理 ────────────────────────────────

clean:
	cargo clean
	@rm -f $(LOG_FILE)

clean-logs:
	@> $(LOG_FILE)
	@echo "Logs cleared"

# ── 部署 ────────────────────────────────

deploy: stop release start
	@echo "Deployed successfully"
	@make status
