---
name: flareon
description: Flare-On reverse-engineering playbook. Covers the solve loop; routing by file type (PE, ELF, .NET, PyInstaller, Python bytecode, PDF, pcap, Office/VBA, JS/Electron, APK, Go/Rust, DOS/MBR/UEFI, WASM, Verilog, memory dumps); Kuna speed rules; Flare-On lore (runtime-decrypted flags, anti-debug, obfuscation, giant generated code); crypto-constant hunting; and z3/angr recipes. Use at the start of every challenge and whenever you are stuck or picking a tool.
---

# Flare-On solve loop
1. Read `README.md`: the title and description are hints, often puns. Then read `triage.md` and `/solves.md`.
2. Find the check or win condition: where your input enters, and what gets compared or decrypted. For native code, search strings first (`kuna strings B --filter '(?i)flag|correct|wrong|key|password|@flare'`).
3. Derive keys, tables and constants from the binary. Then invert the check in Python, solve it (z3), or emulate it (unicorn/speakeasy/wine). Pick whichever is cheapest.
4. If running the target to confirm a candidate is cheap, do it. Then `ilio submit`.
5. Rules:
   - Use the smallest tool action that answers the current question.
   - Don't downgrade to broad `objdump` dumps when a decompiler or debugger is needed.
   - Trust the original artifacts over your own reimplementation.
   - If brute force would need more than 2 h of compute, you are on the wrong path. You have 80 cores, so use `multiprocessing`.
   - When stuck, trace your input from the entry point, and read the assembly around wherever the decompiler looks wrong.

## Routing by what `triage.md` or `file` says
Unsure what it is? `diec -d -j F` (packer/compiler/installer ID) and `capa F` (capabilities: crypto, anti-debug, embedded PE).
| Target | First move |
|---|---|
| Native PE/ELF | The Kuna export in `/work/kuna/`, plus `strings`/`xrefs`/targeted `decompile` (see Kuna speed rules) |
| PyInstaller, .pyc, marshal blobs, Nuitka | `$python-re` |
| .NET (CLR header, Mono/.Net), Unity | `$dotnet` (ilspycmd, reflection harness calling the decryptor, IL patch) |
| UPX | `kuna unpack B -o B.unp` (or `upx -d` on a copy) |
| Corrupted headers | Use `*.fixed.exe` from triage, or patch the bytes in a copy |
| Embedded payloads, resources | Extract with `pefile`/`lief`, or `binwalk -e`. Recognize aPLib (`M8Z`), zlib, LZNT1 and XOR, then decompress with a script. |
| PDF | `qpdf --qdf --object-streams=disable in.pdf out.pdf`, then read the objects. Also `pikepdf`, `mutool show/extract`. Encrypted with an empty password: `qpdf --decrypt`. Inline images: decode them with PIL. |
| pcap | `tshark -r f -qz conv,tcp`; `-qz follow,tcp,raw,N`; `--export-objects http,out/`. Decrypt the payloads with keys recovered from the binary. |
| Office/VBA | `olevba -a --decode f`, `pcode2code f` (for VBA stomping) |
| JS/Electron | `asar extract app.asar out/`, then `webcrack` / `js-beautify` |
| APK/JAR/DEX | `jadx -d out f` |
| Go/Rust | Kuna recovers the names (gopclntab, demangling). Strings are not NUL-terminated, so grep the raw bytes too. |
| DOS/MBR/UEFI/raw | `kuna ... --raw-image --target 'x86:LE:16:Real Mode' --base 0x100 --entry 0x100`; `dosbox`; `qemu-system-x86_64` |
| Installers | `innoextract`, `msiextract`, `cabextract`, NSIS/Inno via refinery (`emit F \| xtinno`/`xtnsis`) |
| Encoded blobs | refinery chains (`emit f \| b64 \| xor k \| zl \| dump out`), malduck (`malduck.aplib/lznt1/rc4`) |
| Call a DLL's export directly | `winpy32`/`winpy64 s.py` (Windows Python under wine) with `ctypes.WinDLL(r'Z:\\work\\run\\x.dll')` |
| Go | `GoReSym -t -d -p F` for types/build info, plus Kuna |
| WASM / Verilog / memory dump | `wasm-decompile` / `iverilog` / `vol -f dump windows.pslist` |
| Windows GUI or anything dynamic | `$windows-dynamic` |

## Kuna speed rules (in addition to `$kuna-decompiler`)
- Every export gets `--max-fn-seconds 10 --jobs 8`. One huge function otherwise stalls everything: FlareAuthenticator went from 175 s to 18 s.
- Binaries over 5 MB, or with giant functions: don't run a whole export. Use `kuna functions B --summary --json`, `strings --filter`, `xrefs --to/--from`, and `decompile` on specific addresses.
- MSVC PE: add `--option msvcstackguard on`. Huge function: add `--option maxinstruction 4000000`.
- A computed jump through a constant table: `--assert 'readonly 0xSTART+0xLEN'` lets Kuna resolve the target.
- Every call reloads the binary, so batch with `decompile-all --functions a,b,c --json`.
- Kuna has **no** .NET, PyInstaller or resource support. Use ilspycmd, pyinstxtractor-ng, or pefile/lief instead.
- Start every native binary with `kuna functions B --summary --json`: `summary.main` is the program's own entry (MSVC/MinGW `main`/`WinMain` are named; go straight to `kuna decompile B main`), and `summary.runtime` lists packer/runtime hints (PyInstaller+version, .NET, UPX, AutoIt, Nuitka, VB/twinBASIC). Act on those hints instead of decompiling the wrapper. A PE with a corrupted `MZ` still loads, with a warning.

## Flare-On lore
- The flag is usually decrypted or computed at runtime. Emulate the decrypt routine, or break right after it, instead of reversing everything.
- Anti-analysis (IsDebuggerPresent, rdtsc/timing loops, self-checks): patch a copy with `EB` / `90 90`, or emulate past it.
- MBA, opaque predicates, flattened control flow, computed jumps: emulate with unicorn, or pattern-match the obfuscation with capstone. Don't read it by hand.
- Giant generated code (state machines, thousands of DLLs or functions): script capstone or regex over the disassembly to extract the graph or tables, then solve with a search, z3 or linear algebra. Never decompile all of it.
- Self-modifying or multi-stage code (the exe writes or patches a copy of itself): reimplement the patcher, or dump each stage.
- Crypto by constants: `kuna crypto B` lists AES/SHA/MD5/CRC/ChaCha/TEA/Base64 constants and the functions using them (`--json`). Fallback: `yara -s /opt/findcrypt3.rules B`, then `kuna xrefs B --to 0xVA`.
  - Common: AES, RC4 (256-byte KSA), ChaCha/Salsa (`expand 32-byte k`), TEA/XTEA (`0x9E3779B9`), SHA/MD5, CRC32, a custom base64 alphabet.
  - Use pycryptodome with the recovered key/IV. Check the mode and endianness against one known block.
  - LCG or RSA built from weak randomness: recover the parameters with gcd, sympy or gmpy2, or with z3.
- Network challenges: the pcap holds the encrypted C2. The key usually comes from host info (user, computer name, time), so derive it and test it on the first message.

## Solvers
- **z3:** `s=Solver(); x=[BitVec(f'x{i}',8) for i in range(N)]`. Constrain each byte to printable (0x20–0x7e). Model the check with bitwise ops. `s.check()`, then read `s.model()`.
- **angr:**
  - `p=angr.Project(B, auto_load_libs=False)`. On an isolated checker use `p.factory.call_state(addr, buf_ptr)` or `blank_state(addr=...)`.
  - Use fixed-length symbolic input `claripy.BVS('in', 8*N)` with printable constraints, then `simgr.explore(find=ok, avoid=bad)`.
  - Never put symbolic values in a Python `if`.
  - If the path count explodes, change the model (hook the helper, start deeper), not the search.
  - Validate the answer on the real binary: check the trailing newline and the NUL terminator.
- **unicorn** (single routine): map the sections from pefile/lief, set up a stack, hook imports and stub them, write the input, run the routine, read memory.
