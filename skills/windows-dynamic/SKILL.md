---
name: windows-dynamic
description: Run and observe Windows challenge binaries on Linux with wine (32/64-bit), Xvfb, screenshots, xdotool GUI driving, WINEDEBUG API tracing, winedbg --gdb, mono for .NET Framework, and single-routine emulation with speakeasy or unicorn. Use when a PE must be executed to confirm a flag, reveal a runtime-decrypted value, or handle GUI/Qt apps.
---

# Windows dynamic analysis
- Always run a copy and put a timeout on every run: `cp /work/src/x.exe /work/run/ && cd /work/run && timeout 60 xvfb-run -a wine x.exe args`.
  - 32-bit and 64-bit both work, and the wine prefix is already warmed.
- **GUI apps:**
  1. Start the program in the background with a fixed display: `Xvfb :9 & DISPLAY=:9 wine x.exe &`.
  2. Take a screenshot (`DISPLAY=:9 import -window root /work/run/shot.png`) and **view the image**.
  3. Drive it with xdotool: `DISPLAY=:9 xdotool search --name 'Title' windowactivate type 'input'`, `key Return`, `mousemove X Y click 1`.
- **Qt apps:** `QT_QPA_PLATFORM_PLUGIN_PATH=$PWD wine x.exe` (see any shipped `run.bat`).
- **Console I/O:** pipe stdin: `printf 'guess\n' | timeout 30 wine x.exe`.
- **API tracing:** `WINEDEBUG=+relay,+seh timeout 60 wine x.exe 2>relay.log`, then grep for the imports you care about (e.g. `CryptDecrypt`, `CreateFileW`, `strcmp`). `+file` and `+reg` show file and registry access.
- **Debugging:** `winedbg --gdb x.exe`, then attach gdb with the port it prints. Break after the decrypt routine and dump memory.
- **.NET Framework:** `mono x.exe` (faster than wine-mono). .NET Core: `dotnet x.dll`.
- **Emulate just one routine** when running the whole program is impractical. Cases: anti-debug, NTFS alternate data streams, registry or host state that wine lacks, or you only need one function's output.
  - `speakeasy -t x.exe` does a full PE emulation with an API log. For shellcode: `speakeasy -t sc.bin -r -a x86|amd64`.
  - unicorn:
    1. Map the image with `lief`/`pefile` at `ImageBase`.
    2. Map a stack and point RSP/ESP at it.
    3. Write the args and buffers.
    4. Stub imports with hooks that set the return value and skip the call.
    5. `emu_start(func, ret_addr)`, then read the output buffer.
- **Anti-debug or timing checks:** patch a copy (`EB` short jump, `90` NOPs) with Python byte edits, then rerun.
- **Self-modifying or self-copying exes:** run them in an isolated dir, diff the produced files, and repeat until the final stage shows the flag.
