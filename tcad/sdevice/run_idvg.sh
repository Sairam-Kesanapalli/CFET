#!/usr/bin/env bash
# Launch the four CFET Id-Vg sweeps as parallel, low-priority sdevice jobs.
#
# Usage: run_idvg.sh [--quick] <mesh_dir> [threads_per_job]
#   --quick           classical drift-diffusion (no density gradient) and
#                     0.07 V gate steps: a fast check of the flow and of the
#                     curve shapes. Not for reported Vth/SS/Ion/Ioff.
#   <mesh_dir>        folder holding cfet_msh.tdr from cfet_sde.cmd
#   threads_per_job   default 4 (4 jobs x 4 = 16 cores in total)
#
# Sweeps run in <mesh_dir>/idvg_full/<tag>/ or <mesh_dir>/idvg_quick/<tag>/,
# generated from the sdevice_idvg.cmd template next to this script. Jobs
# survive logout (nohup) and yield to other users (nice).
set -euo pipefail

mode=full
if [[ ${1:-} == --quick ]]; then mode=quick; shift; fi
mesh_dir=${1:?usage: run_idvg.sh [--quick] <mesh_dir> [threads_per_job]}
threads=${2:-4}
template="$(cd "$(dirname "$0")" && pwd)/sdevice_idvg.cmd"

case $mode in
    full)  qp="eQuantumPotential  hQuantumPotential"; maxstep=0.04 ;;
    quick) qp="";                                     maxstep=0.1  ;;
esac

[[ -f "$mesh_dir/cfet_msh.tdr" ]] || { echo "no cfet_msh.tdr in $mesh_dir" >&2; exit 1; }
[[ -f "$template" ]] || { echo "template not found: $template" >&2; exit 1; }

#        tag   dev  Vd     Vg_end
sweeps=("nlin  n    0.05   0.7"
        "nsat  n    0.7    0.7"
        "plin  p   -0.05  -0.7"
        "psat  p   -0.7   -0.7")

for spec in "${sweeps[@]}"; do
    read -r tag dev vd vg <<< "$spec"
    run="$mesh_dir/idvg_$mode/$tag"
    mkdir -p "$run"
    sed -e "s/@tag@/$tag/g"         -e "s/@dev@/$dev/g"   -e "s/@vd@/$vd/g" \
        -e "s/@vg@/$vg/g"           -e "s/@threads@/$threads/g" \
        -e "s/@qp@/$qp/g"           -e "s/@maxstep@/$maxstep/g" \
        "$template" > "$run/sdevice_idvg.cmd"
    if grep -v '^\*' "$run/sdevice_idvg.cmd" | grep -q '@[a-z]*@'; then
        echo "unfilled token in $run/sdevice_idvg.cmd" >&2; exit 1
    fi
    (cd "$run" && nohup nice -n 10 sdevice sdevice_idvg.cmd > run.out 2>&1 &)
    echo "started $mode/$tag  (Vd = $vd V, Vg -> $vg V, $threads threads)"
done

echo
echo "watch  : tail -f $mesh_dir/idvg_$mode/*/*_idvg_des.log"
echo "stop   : pkill -u \$USER sdevice"
echo "results: python extract_idvg.py $mesh_dir/idvg_$mode"
