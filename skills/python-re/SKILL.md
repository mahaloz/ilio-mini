---
name: python-re
description: Reverse Python targets fast - PyInstaller bundles (exe/ELF with MEI cookie, pythonXY.dll/libpython), .pyc/marshal blobs, layered zlib/base64/marshal loaders, Nuitka-compiled Python. Covers exact-version unmarshal/dis, pyinstxtractor-ng, pycdc/pycdas, xdis.
---

# Python targets

Bytecode only loads under the EXACT CPython minor version that wrote it. Get the version first.

## PyInstaller
- `triage.md` shows `pyver` (e.g. 312 = 3.12). Extract: `pyinstxtractor-ng target` -> `target_extracted/`.
- Entry script = TOC name without extension (e.g. `challenge`), written as `challenge.pyc`; libs are in `PYZ.pyz_extracted/`.
- Data files (json/pem/png) sit next to it; they are usually part of the puzzle.

## Pick the interpreter
- 3.12 = system `python3`; `python3.10`, `python3.13`, `python3.14` are preinstalled; others: `uv python install 3.X` then `uv run --python 3.X python ...`.
- `.pyc` magic (first 2 bytes, little endian) identifies the version; `xdis` maps magic -> version and disassembles cross-version (`pydisasm file.pyc`).

## Read the code
1. `pycdc file.pyc` (decompile) - good up to 3.10, partial on 3.11+. Never `pip install pycdc` (PyPI package is spam); use `/usr/local/bin/pycdc`.
2. When pycdc fails or output looks wrong: `pycdas file.pyc` or, under the right version,
   `python3.X -c "import marshal,dis;f=open('x.pyc','rb');f.seek(16);dis.dis(marshal.load(f))"`, and read the bytecode (it is short).
3. Rewrite the checker in plain Python yourself; run it; invert it.

## Layered loaders (exec(zlib/marshal/base85...))
- Replace `exec`/`eval` with printing/dumping, peel one layer at a time, and `dis` each code object (`co_consts` holds nested code).
- Dump code objects with `marshal.dumps` to files so subagents can work on stages in parallel.
- Guard checks (`os.getlogin()`, hostname, time) - solve the constraint (often XOR/rotate against a constant) instead of guessing.

## Nuitka / compiled
- Nuitka = native code: use kuna + `kuna strings`; constants live in a blob loaded at start - dump it at runtime (wine / emulate) if static recovery is slow.
