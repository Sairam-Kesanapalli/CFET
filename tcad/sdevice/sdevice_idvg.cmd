*==============================================================================
*  sdevice_idvg.cmd -- Sentaurus Device deck: one Id-Vg sweep of the CFET
*
*  Template. The @...@ tokens are filled in by run_idvg.sh (or by Sentaurus
*  Workbench, which uses the same token syntax), one job per sweep:
*      @tag@      nlin | nsat | plin | psat
*      @dev@      n | p          device under test (its drain is ramped)
*      @vd@       drain bias     +0.05 / +0.7 (nFET), -0.05 / -0.7 (pFET)
*      @vg@       gate end bias  +0.7 (nFET), -0.7 (pFET)
*      @threads@  threads for this job
*      @qp@       density-gradient equations: "eQuantumPotential  hQuantumPotential"
*                 (full mode) or empty (quick mode, classical drift-diffusion)
*      @maxstep@  largest gate step as a fraction of |Vg| (0.04 full, 0.1 quick)
*
*  Structure : ../../cfet_msh.tdr from cfet_sde.cmd (MeshLevel 1 for production,
*              MeshLevel 2 once for the mesh-convergence check)
*  Reference : S.-G. Jung et al., IEEE J-EDS 10, 78 (2022)
*              Bias conditions : Fig. 2(c),(d) -- |Vd| = 0.05 V and 0.7 V,
*                                |Vg| swept 0 -> 0.7 V (Vdd = 0.7 V)
*              Gate            : common TiN gate, workfunction 4.54 eV
*              Models          : Sec. II -- density gradient, inversion and
*                                accumulation mobility, doping-dependent and
*                                high-field mobility, band-gap narrowing,
*                                doping-dependent SRH
*              Added here      : Fermi statistics (S/D at 3e20 is degenerate)
*  Outputs   : @tag@_idvg.plt          currents vs bias
*              @tag@_*_idvg.tdr        maps at Vg = 0 and |Vg| = 0.7 V
*  Post      : python extract_idvg.py <mesh folder>
*
*  The device not under test keeps all its terminals at 0 V. The two devices
*  share only the gate; their S/D are isolated by SiO2.
*==============================================================================

File {
    Grid    = "../../cfet_msh.tdr"
    Current = "@tag@_idvg"
    Plot    = "@tag@_idvg"
    Output  = "@tag@_idvg"
}

Electrode {
    { Name = "gate"     Voltage = 0.0  WorkFunction = 4.54 }
    { Name = "n_source" Voltage = 0.0 }
    { Name = "n_drain"  Voltage = 0.0 }
    { Name = "p_source" Voltage = 0.0 }
    { Name = "p_drain"  Voltage = 0.0 }
}

Physics {
    Fermi
    EffectiveIntrinsicDensity ( OldSlotboom )
    Mobility (
        PhuMob
        Enormal ( IALMob )
        HighFieldSaturation
    )
    Recombination ( SRH ( DopingDependence ) )
}

* Density-gradient quantum correction in the silicon sheets and S/D
* (empty in quick mode)
Physics ( Material = "Silicon" ) {
    @qp@
}

Plot {
    Potential  ElectricField/Vector  SpaceCharge
    eDensity  hDensity
    eCurrent/Vector  hCurrent/Vector  TotalCurrent/Vector
    eQuasiFermi  hQuasiFermi
    @qp@
    ConductionBandEnergy  ValenceBandEnergy
    eMobility  hMobility
    eVelocity  hVelocity
    DopingConcentration  DonorConcentration  AcceptorConcentration
}

Math {
    Extrapolate
    Derivatives
    RelErrControl
    Digits = 5
    ErrRef ( Electron ) = 1e8
    ErrRef ( Hole )     = 1e8
    Iterations    = 15
    NotDamped     = 100
    GeometricDistances
    ParameterInheritance = Flatten
    * Shared server: a fixed share of the cores per job
    NumberOfThreads = @threads@
    Method = ILS ( set = 1 )
    ILSrc = "
        set (1) {
            iterative ( gmres(150), tolrel=1e-8, tolunprec=1e-4, tolabs=0, maxit=300 );
            preconditioning ( ilut(0.00001,-1), left );
            ordering ( symmetric=nd, nonsymmetric=mpsilst );
            options ( compact=yes, linscale=0, refineresidual=10, verbose=0 );
        };
    "
    Wallclock
}

Solve {
    *--- Equilibrium ----------------------------------------------------------
    Coupled ( Iterations = 150  LineSearchDamping = 1e-4 ) {
        Poisson  @qp@
    }
    Coupled { Poisson  Electron  Hole  @qp@ }

    *--- Drain ramp at Vg = 0 -------------------------------------------------
    Quasistationary ( InitialStep = 0.05  MinStep = 1e-5  MaxStep = 0.2
                      Increment = 1.5  Decrement = 2
                      Goal { Name = "@dev@_drain" Voltage = @vd@ } ) {
        Coupled { Poisson  Electron  Hole  @qp@ }
    }

    *--- Gate sweep 0 -> @vg@ V ---------------------------------------------
    Quasistationary ( InitialStep = 0.01  MinStep = 1e-5  MaxStep = @maxstep@
                      Increment = 1.4  Decrement = 2
                      Goal { Name = "gate" Voltage = @vg@ } ) {
        Coupled { Poisson  Electron  Hole  @qp@ }
        Plot ( FilePrefix = "@tag@" Time = ( 0.0 ; 1.0 ) NoOverwrite )
    }
}
