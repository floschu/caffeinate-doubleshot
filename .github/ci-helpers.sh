# Sourced by every CI step through BASH_ENV.

# Waits up to 15 s for SleepDisabled to reach the expected value.
expect_sleep_disabled() {
  for _ in $(seq 15); do
    pmset -g | grep -E "SleepDisabled[[:space:]]+$1" >/dev/null && return 0
    sleep 1
  done
  echo "SleepDisabled is not $1" >&2; pmset -g; doubleshot log; return 1
}
