# =============================================================================
#  svisual_verify.tcl -- structural checks of the CFET mesh from cfet_sde.cmd
#
#  Usage : svisual -b svisual_verify.tcl        (batch; writes PNGs)
#          or from the Sentaurus Visual GUI: File > Run Tcl Script...
#  Input : cfet_msh.tdr in the working directory
#  Output: verify_png/cfet_<cut>_doping.png and cfet_<cut>_mesh.png, plus the
#          region list printed to the terminal
#
#  Cut positions are in um and follow the coordinates in cfet_sde.cmd
#  (x transport, y sheet width, z vertical; z = 0 at the top of the BOX).
# =============================================================================

set TDR    "cfet_msh.tdr"
set OUTDIR "verify_png"
file mkdir $OUTDIR

set ds  [load_file $TDR]
set p3d [create_plot -dataset $ds]

#   name             axis  at [um]   expected content
set cuts {
    {x_gate_centre   x   0.0     "both sheets wrapped by HfO2, empty gate cavity around them"}
    {x_source_vias   x  -0.0255  "n pad y=0-83 nm, p pad y=0-54 nm, n via passes beside p pad"}
    {y_sheet_centre  y   0.027   "junctions at x=+/-6.4 nm, spacers 8-14 nm, pads beyond 14 nm"}
    {y_n_vias        y   0.0685  "n vias land on the n pad at z=14 nm and rise to z=61 nm"}
    {z_n_sheet       z   0.0105  "30 nm nFET channel joining 83 nm wide n pads"}
    {z_p_sheet       z   0.0355  "30 nm pFET channel joining 54 nm wide p pads"}
}

foreach cut $cuts {
    lassign $cut name axis pos expect
    set cds [create_cutplane -plot $p3d -type $axis -at $pos]
    set p2d [create_plot -dataset $cds]

    set_field_prop -plot $p2d -geom $cds DopingConcentration -show_bands
    export_view [file join $OUTDIR cfet_${name}_doping.png] \
        -plots $p2d -format png -overwrite

    set_mesh_prop -plot $p2d -geom $cds -show
    export_view [file join $OUTDIR cfet_${name}_mesh.png] \
        -plots $p2d -format png -overwrite

    puts "cut $name ($axis = $pos um): expect $expect"
}

puts "Regions in $TDR:"
foreach region [list_regions -plot $p3d] {
    puts "  $region"
}

exit
