# Test fixtures

Saved output of system commands, fed to the parsers under test (ADR-0004).
Each file holds exactly what the command printed on stdout, nothing else.

| File | Command | Origin |
| --- | --- | --- |
| `sw_vers/captured-dev-mac.txt` | `/usr/bin/sw_vers -productVersion` | Captured on the development Mac |
| `sw_vers/27.0.txt`, `27.0.1.txt` | same | Hand-written: verified tier |
| `sw_vers/26.3.1.txt` | same | Hand-written: tolerated tier, never reachable on the development Mac |
| `sw_vers/15.7.1.txt`, `28.0.txt` | same | Hand-written: unsupported, older and newer |
| `sysctl/arm64-captured-dev-mac.txt` | `/usr/sbin/sysctl -n hw.optional.arm64` | Captured on the development Mac |
| `sysctl/arm64-apple-silicon.txt` | same | Hand-written |
| `sysctl/arm64-intel.txt` | same | Hand-written and empty: on Intel the key does not exist, so stdout is empty |
