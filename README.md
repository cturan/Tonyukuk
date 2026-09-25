# Tonyukuk

UCI chess engine in T. The compiler is `t.lua`. It emits native code for macOS and Linux (arm64, x86_64) and Windows (x86_64).

The engine is `tonyukuk.t`: bitboards, Chess960, PVS, quiescence, transposition table, Lazy SMP, Syzygy, Polyglot, NNUE.

Estimated strength is above 3300 Elo, but has not been officially measured on any rating list.

## Download

- [Windows x86_64 AVX2](https://github.com/cturan/Tonyukuk/releases/download/0.1-dev/tonyukuk-0.1-dev-windows-x86_64-avx2.exe)
- [Windows x86_64 AVX](https://github.com/cturan/Tonyukuk/releases/download/0.1-dev/tonyukuk-0.1-dev-windows-x86_64-avx.exe)
- [macOS Apple silicon](https://github.com/cturan/Tonyukuk/releases/download/0.1-dev/tonyukuk-0.1-dev-macos-arm64-neon)

Other builds are on the [releases page](https://github.com/cturan/Tonyukuk/releases).

## Build

Lua 5.4 or newer.

```
lua t.lua tonyukuk.t --arch macos --cpu arm64 --instruction neon --gom netv2.tnnk --output tonyukuk
lua t.lua tonyukuk.t --arch linux --cpu x86_64 --instruction auto --gom netv2.tnnk --output tonyukuk
lua t.lua tonyukuk.t --arch windows --cpu x86_64 --instruction auto --gom netv2.tnnk --output tonyukuk.exe
```

`--instruction` sets the instruction set. x86_64: `auto`, `scalar`, `sse2`, `avx`, `avx2`, `avx512`, `avx512bw`. arm64: `neon`, `scalar`.

AVX2 Windows build:

```
lua t.lua tonyukuk.t --arch windows --cpu x86_64 --instruction avx2 --gom netv2.tnnk --output tonyukuk.exe
```

## Run

```
setoption name EvalFile value netv2.tnnk
```

Options: `Threads`, `Hash`, `MultiPV`, `Ponder`, `EvalFile`, `SyzygyPath`, `SyzygyProbeDepth`, `Book`, `OwnBook`, `BookDepth`, `UCI_Chess960`.

## Network

`netv2.tnnk` (19 MB): 768 king-bucketed inputs, 768 -> 32 -> 16, four phase heads, PSQT. Bootstrapped on self-play data generated with Stockfish 19 on EPYC servers ([cturan/tonyukuk](https://huggingface.co/datasets/cturan/tonyukuk)), then next generations trained on Tonyukuk self-play data.

## License

MIT

Syzygy probing is inspired by Ronald de Man's tablebase code. Search and evaluation ideas are inspired by the Stockfish project.
