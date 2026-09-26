FROM ubuntu:24.04
ENV DEBIAN_FRONTEND=noninteractive LANG=C.UTF-8 CODEX_HOME=/root/.codex \
    PATH=/opt/py/bin:/opt/kuna:/opt/dotnet-tools:/opt/jadx/bin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin \
    UV_PYTHON_INSTALL_DIR=/opt/uv-python UV_TOOL_DIR=/opt/uv-tools UV_TOOL_BIN_DIR=/usr/local/bin \
    DOTNET_CLI_TELEMETRY_OPTOUT=1 DOTNET_NOLOGO=1 WINEDEBUG=-all

# Core: build/debug, archives, windows (wine 32+64), formats, .NET, JVM. Apt lists are kept for runtime installs.
RUN dpkg --add-architecture i386 && apt-get update && \
    echo 'wireshark-common wireshark-common/install-setuid boolean false' | debconf-set-selections && \
    apt-get install -y --no-install-recommends \
      build-essential cmake git curl wget ca-certificates file xxd binutils gdb strace ltrace less procps \
      p7zip-full unzip zip zstd xz-utils binwalk upx-ucl ripgrep jq sqlite3 \
      python3 python3-dev python3-venv nodejs npm \
      wine wine64 wine32:i386 xvfb xauth xdotool x11-utils imagemagick \
      tshark qpdf mupdf-tools poppler-utils yara libimage-exiftool-perl \
      dotnet-sdk-8.0 mono-complete openjdk-21-jre-headless

# Python: one venv first on PATH, plus an exact-version 3.13 for marshal/dis (3.12 is the system python).
RUN curl -LsSf https://astral.sh/uv/install.sh | env UV_INSTALL_DIR=/usr/local/bin sh && \
    uv venv /opt/py --python /usr/bin/python3 && \
    uv pip install --python /opt/py/bin/python "angr<10" unicorn capstone z3-solver pefile lief pyelftools dnfile \
      cryptography pycryptodome gmpy2 sympy numpy pillow pikepdf scapy dpkt requests xdis pyinstxtractor-ng && \
    uv python install 3.13 3.11 && ln -sf $(uv python find 3.13) /usr/local/bin/python3.13
RUN uv pip install --python /opt/py/bin/python oletools pcode2code volatility3 pyevmasm || echo "WARN: py extras"

# Bytecode tools: pycdc/pycdas (never pip-install 'pycdc': spam), ilspycmd (9.x = net8), jadx, floss, findcrypt rules.
RUN git clone --depth 1 https://github.com/zrax/pycdc /tmp/pycdc && cmake -S /tmp/pycdc -B /tmp/pycdc/b && \
    make -C /tmp/pycdc/b -j"$(nproc)" && cp /tmp/pycdc/b/pycdc /tmp/pycdc/b/pycdas /usr/local/bin/ && rm -rf /tmp/pycdc
RUN dotnet tool install ilspycmd --version 9.1.0.7988 --tool-path /opt/dotnet-tools
RUN curl -fsSL -o /tmp/j.zip https://github.com/skylot/jadx/releases/download/v1.5.5/jadx-1.5.5.zip && \
      unzip -q /tmp/j.zip -d /opt/jadx && rm /tmp/j.zip || echo "WARN: jadx"; \
    curl -fsSL -o /tmp/f.zip https://github.com/mandiant/flare-floss/releases/download/v3.1.1/floss-v3.1.1-linux.zip && \
      unzip -q /tmp/f.zip -d /usr/local/bin && chmod +x /usr/local/bin/floss && rm /tmp/f.zip || echo "WARN: floss"; \
    curl -fsSL -o /opt/findcrypt3.rules https://raw.githubusercontent.com/polymorf/findcrypt-yara/master/findcrypt3.rules || echo "WARN: findcrypt"

# Codex (full npm package: ships codex-code-mode-host) + JS tooling.
RUN npm i -g @openai/codex@0.157.0 @electron/asar js-beautify && (npm i -g webcrack || echo "WARN: webcrack")

# Warm wine prefix (32+64) so the first run is fast.
RUN WINEDLLOVERRIDES="mscoree,mshtml=" xvfb-run -a wineboot -i && wineserver -w || echo "WARN: wineboot"

# Best-effort extras.
RUN (uv tool install --python 3.11 speakeasy-emulator || echo "WARN: speakeasy") && \
    (apt-get install -y --no-install-recommends dosbox qemu-system-x86 wabt iverilog || echo "WARN: apt extras")

# Extras (verified 2026-09-25): Node 22 (webcrack), exact Pythons, malduck, Windows python for ctypes-calling DLL exports, DIE, capa, GoReSym, unpackers, qemu-user.
RUN (curl -fsSL https://nodejs.org/dist/v22.23.3/node-v22.23.3-linux-x64.tar.xz | tar xJ -C /usr/local --strip-components=1 && \
      rm -f /usr/local/CHANGELOG.md /usr/local/README.md /usr/local/LICENSE && npm i -g webcrack && webcrack --version) || echo "WARN: node22/webcrack"; \
    (uv python install 3.10 3.14 && for v in 3.10 3.14; do ln -sf "$(uv python find $v)" /usr/local/bin/python$v; done) || echo "WARN: py3.10/3.14"; \
    uv pip install --python /opt/py/bin/python malduck autoit-ripper keystone-engine || echo "WARN: py extras2"; \
    (for a in amd64 win32; do mkdir -p /opt/winpy/$a && curl -fsSL -o /tmp/p.zip https://www.python.org/ftp/python/3.12.10/python-3.12.10-embed-$a.zip && \
       unzip -q -o /tmp/p.zip -d /opt/winpy/$a && rm /tmp/p.zip; done && \
     printf '#!/bin/sh\nexec wine /opt/winpy/amd64/python.exe "$@"\n' > /usr/local/bin/winpy64 && \
     printf '#!/bin/sh\nexec wine /opt/winpy/win32/python.exe "$@"\n' > /usr/local/bin/winpy32 && chmod +x /usr/local/bin/winpy64 /usr/local/bin/winpy32) || echo "WARN: winpy"; \
    (curl -fsSL -o /tmp/die.deb https://github.com/horsicq/DIE-engine/releases/download/3.21/die_3.21_Ubuntu_24.04_amd64.deb && apt-get update && \
      apt-get install -y --no-install-recommends /tmp/die.deb && rm -f /tmp/die.deb) || echo "WARN: diec"; \
    apt-get install -y --no-install-recommends innoextract cabextract msitools qemu-user gdb-multiarch binutils-avr simavr || echo "WARN: apt extras2"; \
    (curl -fsSL -o /tmp/c.zip https://github.com/mandiant/capa/releases/download/v9.4.0/capa-v9.4.0-linux.zip && unzip -q -o /tmp/c.zip -d /usr/local/bin && \
      chmod +x /usr/local/bin/capa && rm /tmp/c.zip) || echo "WARN: capa"; \
    (curl -fsSL -o /tmp/g.zip https://github.com/mandiant/GoReSym/releases/download/v3.4.1/GoReSym-linux.zip && unzip -q -o /tmp/g.zip GoReSym -d /usr/local/bin && \
      chmod +x /usr/local/bin/GoReSym && rm /tmp/g.zip) || echo "WARN: GoReSym"
# .NET cleanup/unpack helpers, PDF scripts, binary-refinery (units colliding with system tools - zstd/rev/lzma/js - are not linked).
RUN dotnet tool install sfextract --version 2.3.0 --tool-path /opt/dotnet-tools || echo "WARN: sfextract"; \
    (mkdir -p /opt/de4dot && curl -fsSL -o /tmp/d.zip https://github.com/ViRb3/de4dot-cex/releases/download/v4.0.0/de4dot-cex.zip && unzip -q /tmp/d.zip -d /opt/de4dot && rm /tmp/d.zip && \
      printf '#!/bin/sh\nexec mono /opt/de4dot/de4dot.exe "$@"\n' > /usr/local/bin/de4dot && chmod +x /usr/local/bin/de4dot) || echo "WARN: de4dot"; \
    (mkdir -p /opt/il2cppdumper && curl -fsSL -o /tmp/i.zip https://github.com/Perfare/Il2CppDumper/releases/download/v6.7.46/Il2CppDumper-net6-v6.7.46.zip && \
      unzip -q /tmp/i.zip -d /opt/il2cppdumper && rm /tmp/i.zip && sed -i 's/"RequireAnyKey": true/"RequireAnyKey": false/' /opt/il2cppdumper/config.json && \
      printf '#!/bin/sh\nDOTNET_ROLL_FORWARD=Major exec dotnet /opt/il2cppdumper/Il2CppDumper.dll "$@"\n' > /usr/local/bin/Il2CppDumper && chmod +x /usr/local/bin/Il2CppDumper) || echo "WARN: Il2CppDumper"; \
    (for f in pdf-parser.py pdfid.py; do curl -fsSL -o /usr/local/bin/$f https://raw.githubusercontent.com/DidierStevens/DidierStevensSuite/master/$f && chmod +x /usr/local/bin/$f; done) || echo "WARN: pdf-parser"; \
    (mkdir -p /opt/refinery/bin && UV_TOOL_BIN_DIR=/opt/refinery/bin uv tool install --python 3.12 binary-refinery && \
      for f in /opt/refinery/bin/*; do command -v "${f##*/}" >/dev/null || ln -s "$f" /usr/local/bin/; done) || echo "WARN: refinery"

# Kuna (release binaries + specs; specs are found next to the binary).
ARG KUNA_VERSION=v1.591
RUN mkdir -p /opt/kuna && \
    curl -fsSL https://github.com/Noelo-Lab/kuna/releases/download/${KUNA_VERSION}/kuna-${KUNA_VERSION}-linux-x86_64.tar.gz | tar xz --strip-components=1 -C /opt/kuna && \
    curl -fsSL https://github.com/Noelo-Lab/kuna/releases/download/${KUNA_VERSION}/kuna-${KUNA_VERSION}-specs.tar.gz | tar xz -C /opt/kuna && \
    kuna functions /bin/ls --summary >/dev/null

ENV VIRTUAL_ENV=/opt/py PIP_BREAK_SYSTEM_PACKAGES=1 \
    PATH=/opt/py/bin:/opt/kuna:/opt/dotnet-tools:/opt/jadx/bin:/root/.local/bin:/root/.dotnet/tools:/root/go/bin:/root/.cargo/bin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
COPY codex/ /root/.codex/
COPY skills/ /root/.agents/skills/
COPY ilio /usr/local/bin/ilio
RUN chmod +x /usr/local/bin/ilio /root/.codex/*.sh /root/.codex/*.py && kuna install-skill --dir /root/.agents/skills --force && \
    codex --version && python -c "import angr, z3, capstone, unicorn, pefile, lief, Crypto" && \
    wine --version && pycdc --help >/dev/null 2>&1; ilspycmd --version && uv pip install --python /opt/py/bin/python pip && ln -sf /usr/bin/upx-ucl /usr/local/bin/upx && mkdir -p /work
WORKDIR /work
CMD ["ilio", "agent"]
