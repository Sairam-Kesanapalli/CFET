# CFET 3D TCAD (Project 34)

Stacked n/p nanosheet CFET (3-nm node) in Sentaurus, following
Jung et al., IEEE J-EDS 10, 78 (2022) — `docs/papers/`.

## Layout

```
CFET/
├── tcad/                     source scripts (edit these)
│   ├── sde/cfet_sde.cmd          structure + doping + mesh; MeshLevel on line 117 (= 1)
│   ├── sde/cfet_sde.scm          same deck, MeshLevel 0 (the one used for current runs)
│   ├── sdevice/sdevice_idvg.cmd  Id-Vg template (@tag@ tokens)
│   ├── sdevice/run_idvg.sh       launches the 4 sweeps in parallel
│   └── svisual/svisual_verify.tcl  cut-plane pictures of a mesh
├── runs/                     simulation outputs (one folder per mesh level)
│   ├── level0/                   71k points  · quick checks
│   │   └── idvg_quick/           first Id-Vg (classical, preliminary)
│   ├── level1/                   186k points · production mesh
│   └── level2/                   417k points · mesh-convergence check
├── results/figures/          plots for slides and the report
└── docs/papers/              reference papers
```

Each `runs/levelN/` keeps the deck that made it (`cfet_sde.cmd`); Id-Vg runs
keep their decks and `.plt` curves. Meshes, field files and logs are not in
the repository: rebuild them by running the decks (a level-1 mesh takes about
2 minutes on the server).

Papers in `docs/papers/` are © their authors, licensed CC BY 4.0
(https://creativecommons.org/licenses/by/4.0/). Sentaurus is a Synopsys tool;
no Synopsys software, documentation or parameter files are included here.

## Running

```bash
# 1. structure and mesh (set MeshLevel 0/1/2 on line 117 first)
cd runs/level1 && sde -e -l ../../tcad/sde/cfet_sde.cmd

# 2. Id-Vg, four sweeps in parallel (--quick = classical, coarse steps)
bash tcad/sdevice/run_idvg.sh [--quick] runs/level1 4

# 3. Id-Vg graphs: open runs/level1/idvg_full/*/*_idvg_des.plt in Sentaurus Visual
#    x: gate OuterVoltage, y: n_drain / p_drain TotalCurrent, log scale
```
