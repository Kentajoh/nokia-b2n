#!/bin/bash
# Resolve host-side Android / filesystem tools on Linux and macOS.
# Prefer PATH (Ubuntu packages, platform-tools on PATH), then common SDK
# install locations. Callers may still override with ADB, FASTBOOT, or MKE2FS.

b2n_find_tool() {
  local name="$1"
  local candidate
  if command -v "$name" >/dev/null 2>&1; then
    command -v "$name"
    return 0
  fi
  for candidate in \
    "${ANDROID_HOME:+$ANDROID_HOME/platform-tools/$name}" \
    "${ANDROID_SDK_ROOT:+$ANDROID_SDK_ROOT/platform-tools/$name}" \
    "$HOME/Android/Sdk/platform-tools/$name" \
    "$HOME/Library/Android/sdk/platform-tools/$name" \
    "/usr/lib/android-sdk/platform-tools/$name" \
    "/usr/lib/android-sdk/cmdline-tools/latest/bin/$name"
  do
    [[ -n "$candidate" && -x "$candidate" ]] || continue
    printf '%s\n' "$candidate"
    return 0
  done
  return 1
}

b2n_require_tool() {
  local var_name="$1"
  local tool_name="$2"
  local resolved
  if [[ -n "${!var_name:-}" ]]; then
    if [[ -x "${!var_name}" ]]; then
      return 0
    fi
    echo "$var_name is set but not executable: ${!var_name}" >&2
    return 1
  fi
  if ! resolved="$(b2n_find_tool "$tool_name")"; then
    echo "Need $tool_name on PATH or under Android platform-tools" >&2
    return 1
  fi
  printf -v "$var_name" '%s' "$resolved"
}

b2n_sha256_check() {
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum -c SHA256SUMS
  elif command -v shasum >/dev/null 2>&1; then
    shasum -a 256 -c SHA256SUMS
  else
    echo "Need sha256sum or shasum to verify SHA256SUMS" >&2
    return 1
  fi
}

b2n_sha256_write() {
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$@" > SHA256SUMS
  elif command -v shasum >/dev/null 2>&1; then
    shasum -a 256 "$@" > SHA256SUMS
  else
    echo "Need sha256sum or shasum to write SHA256SUMS" >&2
    return 1
  fi
}
