---
name: dotnet
description: Reverse .NET / C# targets fast - managed PE assemblies (CLR header, mscoree, "Mono/.Net assembly"), Unity games (Assembly-CSharp.dll, IL2CPP), .NET single-file bundles, obfuscated assemblies. Covers ilspycmd decompilation, dnfile metadata, running under mono/dotnet, calling internal decrypt methods via a reflection harness, and IL patching with monodis/ilasm.
---

# .NET targets (Kuna does not decompile IL)

## Decompile
- Whole project, which also extracts embedded resources: `ilspycmd -p -o /work/cs target.exe`. Then `rg` the C# for input handling, `Decrypt`, `Convert.FromBase64String`, and resource names.
- Quick views: `ilspycmd -l c target.exe` lists the types; `ilspycmd -t Namespace.Type target.exe` prints one type.
- Ignore the "not using the latest version" warning (9.x is pinned for .NET 8).
- Metadata and resources from Python: `dnfile.dnPE('t.exe')` (`.net.mdtables`, `.net.resources`).

## Run and call it directly (usually the fastest path)
- .NET Framework exe: `mono t.exe` (GUI apps: `xvfb-run -a mono t.exe`, or wine; see `$windows-dynamic`). .NET Core/5+: `dotnet t.dll`.
- **Reflection harness**: rather than re-implementing a decryptor, call it.
  1. `cat > h.cs` with
     ```
     var t = Assembly.LoadFrom("t.exe").GetType("NS.Cls");
     var m = t.GetMethod("Dec", BindingFlags.NonPublic|BindingFlags.Static);
     Console.WriteLine(m.Invoke(null, new object[]{ ... }));
     ```
  2. `mcs -out:h.exe h.cs && mono h.exe`.

  Instance methods need `Activator.CreateInstance(t, true)`. Brute-force from the harness in a loop when the keyspace is small.
- **Patch IL**:
  1. `monodis t.exe > t.il`.
  2. Edit the branch or constant.
  3. `ilasm -out:t2.exe t.il && mono t2.exe`.

## Special cases
- **Obfuscated** (ConfuserEx and similar): names and strings are encrypted, but the reflection harness still works. Call the string decryptor or the method, or dump values at runtime. For static cleanup: `de4dot t.exe` (de4dot-cex under mono) writes `t-cleaned.exe`.
- **Unity**:
  - `*_Data/Managed/Assembly-CSharp.dll` means ilspycmd works.
  - `GameAssembly.dll` plus `global-metadata.dat` means IL2CPP. `Il2CppDumper GameAssembly.dll global-metadata.dat out/` recovers names; then use Kuna on `GameAssembly.dll` with those names.
- **Single-file bundle** (a large exe with an appended bundle): `sfextract t.exe -o out/`.
- **NativeAOT or ReadyToRun-only code**: this is native. Use Kuna, and grep the strings for type names.
- **Mixed-mode or P/Invoke**: follow the `DllImport` into the native DLL with Kuna.
