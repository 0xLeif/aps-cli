# Swift integration harness

This example compiles a small Swift program that invokes aps as a subprocess.
It models an integration test or developer tool controlling the same
AppState-backed state surface that a human or agent can inspect.

```bash
fledge run build
APS_BIN="$PWD/.build/debug/aps" \
APS_HOME="$(mktemp -d)" \
./examples/swift-harness/run.sh
```

The harness writes the default structured `profile` value in one process and
reads it back in another. Production projects can use the same boundary to seed
fixtures, change feature state, or inspect state after an application test.

This is a subprocess integration example, not an aps Swift library API.
