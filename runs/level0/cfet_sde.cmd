;; =============================================================================
;;  cfet_sde.cmd -- Sentaurus Structure Editor (SDE) deck
;;
;;  Device    : 3-nm-node Complementary FET (CFET). One p-type nanosheet stacked
;;              on top of one n-type nanosheet, wrapped by a common (shared)
;;              gate, on SiO2. Tungsten vias land on each S/D; the nMOS S/D is
;;              widened in y so its vias can pass beside the pMOS S/D.
;;
;;  Reference : S.-G. Jung, D. Jang, S.-J. Min, E. Park, H.-Y. Yu,
;;              "Performance Analysis on Complementary FET (CFET) Relative to
;;              Standard CMOS With Nanosheet FET," IEEE J. Electron Devices Soc.,
;;              vol. 10, pp. 78-82, 2022. doi:10.1109/JEDS.2021.3136605
;;              Geometry: Fig. 1(a),(b),(d); via pitch: Fig. 6(c).
;;
;;  Usage     : sde -e -l cfet_sde.cmd
;;              Produces <OUT>.sat (geometry) and <OUT>_msh.tdr (mesh + doping).
;;              Under Sentaurus Workbench, replace parameter literals in
;;              Section 1 with @Param@ tokens and set OUT to "n@node@".
;;
;;  Coordinates (all parameters in nm, converted to um at use):
;;      x : transport direction, source (x<0) -> drain (x>0), x = 0 at gate centre
;;      y : sheet-width direction, y = 0 at the cell edge
;;      z : vertical, z = 0 at the top of the buried oxide
;;
;;  Contacts  : gate, n_source, n_drain, p_source, p_drain
;;              Gate     -> boundary of the removed gate-metal body; set
;;                          WorkFunction = 4.54 (TiN) on "gate" in sdevice.
;;              S/D      -> top face of each W via (as in the reference).
;;              Inverter -> tie n_drain/p_drain in the mixed-mode netlist.
;;
;;  Parameter provenance tags:
;;      [P] taken from the reference   [D] derived   [A] assumption (not in ref)
;; =============================================================================

(sde:clear)

;; New bodies only fill empty space ("BAB"), so the build order below is
;; inside-out: silicon -> high-k -> vias -> gate -> spacers -> fill oxides.
(sdegeo:set-default-boolean "BAB")


;; -----------------------------------------------------------------------------
;; 0. Units and helpers
;; -----------------------------------------------------------------------------
(define nm 1.0e-3)                                   ; SDE native unit is um

(define (P x y z) (position (* x nm) (* y nm) (* z nm)))

(define (cuboid! x0 y0 z0 x1 y1 z1 material region)
  (sdegeo:create-cuboid (P x0 y0 z0) (P x1 y1 z1) material region))

(define (refwin! name x0 y0 z0 x1 y1 z1)
  (sdedr:define-refeval-window name "Cuboid" (P x0 y0 z0) (P x1 y1 z1)))

(define (refine-size! name dxmax dymax dzmax dxmin dymin dzmin)
  (sdedr:define-refinement-size name
    (* dxmax nm) (* dymax nm) (* dzmax nm)
    (* dxmin nm) (* dymin nm) (* dzmin nm)))

(define (report label value unit)
  (display (string-append "  " label " = " (number->string value) " " unit))
  (newline))

(define (check ok message)
  (if (not ok)
      (begin (display (string-append "*** GEOMETRY CHECK FAILED: " message))
             (newline))))


;; -----------------------------------------------------------------------------
;; 1. Parameters
;; -----------------------------------------------------------------------------
(define OUT      "cfet")       ; output basename (SWB: "n@node@")

;; Lateral (x)
(define Lg       16.0)         ; [P] physical gate length
(define Leff     12.8)         ; [P] effective gate length (junction-to-junction)
(define Lsp       6.0)         ; [P] gate spacer length
(define Lcell    74.0)         ; [P] cell length along x (Fig. 1(a))

;; Width (y)
(define Wch      30.0)         ; [P] nanosheet width
(define Wpsd     54.0)         ; [P] pMOS S/D width
(define Wnsd     83.0)         ; [P] nMOS S/D width (extended for via landing)
(define ViaPitch 54.0)         ; [P] n-to-p via pitch in y (Fig. 6(c))

;; Vertical (z)
(define Tch       7.0)         ; [P] nanosheet thickness
(define Tox       2.0)         ; [P] HfO2 gate dielectric thickness
(define Dnp      18.0)         ; [P] n/p sheet separation (sweep for coupling)
(define Tbox     10.0)         ; [A] buried oxide below the stack
(define TgBot     5.0)         ; [A] gate metal under the bottom sheet's high-k
(define TgTop    10.0)         ; [A] gate metal over the top sheet's high-k
(define Tild     10.0)         ; [A] passivation oxide above the gate

;; Vias (W)
(define ViaLx    12.0)         ; [A] via length along x
(define ViaWy    15.0)         ; [A] via width along y

;; Doping [cm^-3]
(define Nsd      3.0e20)       ; [P] S/D doping (abrupt, see Section 4)
(define Nsub     1.0e16)       ; [P] channel ("substrate") doping

;; Standard-CMOS reference footprint, for the area comparison only
(define WsdCMOS  54.0)         ; [P] n and p S/D width, standard CMOS
(define SnpCMOS  42.0)         ; [P] n-to-p space, standard CMOS

;; Mesh. The reference reports no mesh settings; these are our own choices.
;;   MeshLevel 0 : smoke test  -- global + channel boxes only, no functions
;;   MeshLevel 1 : standard    -- adds S/D, high-k, spacer, junction and
;;                                Si/HfO2 interface refinement (I-V, C-V)
;;   MeshLevel 2 : fine        -- 0.1 nm at Si/HfO2 both sides, doping-
;;                                gradient refinement (final/convergence runs).
;;                                ~790k vertices before Delaunay; snmesh was
;;                                killed after 75 min on the N-2017.09 VM, so
;;                                run it only on a larger machine.
(define MeshLevel 0)
(define (by-level . choices) (list-ref choices MeshLevel))

;;                       level 0 / 1 / 2:  max dx dy dz  min dx dy dz  [nm]
(define MeshGlobal  (by-level '(5.0  5.0  5.0   1.0  1.0  1.0 )
                              '(4.0  4.0  4.0   1.0  1.0  1.0 )
                              '(4.0  4.0  4.0   1.0  1.0  1.0 )))
(define MeshChannel (by-level '(1.0  2.0  1.0   0.5  0.5  0.5 )
                              '(1.0  2.0  1.0   0.5  0.5  0.25)
                              '(1.0  2.0  0.5   0.25 0.5  0.15)))
(define MeshSD      (by-level '()
                              '(2.0  4.0  2.0   1.0  1.0  0.5 )
                              '(2.0  4.0  1.0   0.5  1.0  0.25)))
;; High-k: coarse box sizes only. Binary-tree cuts span whole cells, so a fine
;; dy/dz here grids the entire sheet cross-section (level-1 run: 168k of 354k
;; vertices sat in the two shells). Normal-direction layering through the
;; 2 nm oxide comes from the Si/HfO2 interface function in 6.3 instead.
(define MeshHighK   (by-level '()
                              '(1.0  2.0  1.0   0.5  0.5  0.25)
                              '(1.0  2.0  0.5   0.25 0.5  0.15)))
(define MeshSpacer  (by-level '()
                              '(2.0  4.0  2.0   1.0  1.0  1.0 )
                              '(1.0  4.0  2.0   0.5  1.0  0.5 )))
(define MeshJunc    (by-level '()
                              '(0.5  2.0  1.0   0.25 0.5  0.25)
                              '(0.25 2.0  0.5   0.1  0.5  0.15)))
(define MeshIntSiHK (by-level 0.0 0.25 0.1))  ; first spacing normal to Si/HfO2
(define MeshIntRatio 1.5)                     ; growth ratio away from Si/HfO2


;; -----------------------------------------------------------------------------
;; 2. Derived dimensions
;; -----------------------------------------------------------------------------
(define Lov   (/ (- Lg Leff) 2.0))                  ; [D] S/D overlap under gate
(define Lsd   (- (/ Lcell 2.0) (/ Lg 2.0) Lsp))     ; [D] S/D length
(define Wcell Wnsd)                                 ; [D] cell width in y

;; x landmarks (positive side; source side is mirrored)
(define xG    (/ Lg 2.0))                           ; gate edge
(define xJ    (/ Leff 2.0))                         ; metallurgical junction
(define xSp   (+ xG Lsp))                           ; spacer outer edge
(define xC    (/ Lcell 2.0))                        ; cell edge
(define xVia  (+ xSp (/ Lsd 2.0)))                  ; via centre

;; y landmarks: both sheets are centred on the pMOS S/D
(define yCh   (/ Wpsd 2.0))
(define yCh0  (- yCh (/ Wch 2.0)))
(define yCh1  (+ yCh (/ Wch 2.0)))
(define yViaN (/ (+ Wpsd Wnsd) 2.0))                ; centre of nMOS S/D extension
(define yViaP (- yViaN ViaPitch))

;; z landmarks
(define zN0   (+ TgBot Tox))                        ; nFET sheet bottom
(define zN1   (+ zN0 Tch))                          ; nFET sheet top
(define zP0   (+ zN1 Dnp))                          ; pFET sheet bottom
(define zP1   (+ zP0 Tch))                          ; pFET sheet top
(define zG1   (+ zP1 Tox TgTop))                    ; gate top
(define zTop  (+ zG1 Tild))                         ; domain top / via top
(define zGap  (/ (+ zN1 zP0) 2.0))                  ; point inside the shared gate

;; Geometry consistency
(check (> Lsd 0.0)                            "spacers exceed the cell length")
(check (>= Lov 0.0)                           "Leff must not exceed Lg")
(check (< ViaLx Lsd)                          "via is longer than the S/D")
(check (<= Wch Wpsd)                          "sheet is wider than the pMOS S/D")
(check (> Dnp (* 2.0 Tox))                    "Dnp leaves no room for gate metal")
(check (>= (- yViaP (/ ViaWy 2.0)) 0.0)       "pMOS via leaves the cell")
(check (<= (+ yViaP (/ ViaWy 2.0)) Wpsd)      "pMOS via overhangs the pMOS S/D")
(check (> (- yViaN (/ ViaWy 2.0)) Wpsd)       "nMOS via touches the pMOS S/D")
(check (<= (+ yViaN (/ ViaWy 2.0)) Wnsd)      "nMOS via overhangs the nMOS S/D")

(display "CFET structure summary") (newline)
(report "Lov (S/D overlap)"        Lov                         "nm")
(report "Lsd (S/D length)"         Lsd                         "nm")
(report "nMOS via height"          (- zTop zN1)                "nm")
(report "pMOS via height"          (- zTop zP1)                "nm")
(report "CFET footprint"           (* Lcell Wcell)             "nm^2")
(report "Std-CMOS footprint"       (* Lcell (+ WsdCMOS SnpCMOS WsdCMOS)) "nm^2")
(report "CFET / Std-CMOS area"
        (/ Wcell (+ WsdCMOS SnpCMOS WsdCMOS))                  "")


;; -----------------------------------------------------------------------------
;; 3. Geometry (inside-out; see the default-boolean note at the top)
;; -----------------------------------------------------------------------------

;; 3.1 Silicon. Each sheet is split at the metallurgical junctions (x = +/-Leff/2)
;;     into a channel and two S/D extensions (Lov under the gate + under the
;;     spacer), so every silicon region carries a single constant doping and
;;     the mesh has a node plane on each junction. S/D pads are wider in y.
(cuboid! (- xJ)  yCh0 zN0    xJ   yCh1 zN1   "Silicon" "R.nCh")
(cuboid! (- xSp) yCh0 zN0 (- xJ)  yCh1 zN1   "Silicon" "R.nExtS")
(cuboid!    xJ   yCh0 zN0    xSp  yCh1 zN1   "Silicon" "R.nExtD")
(cuboid! (- xC)  0.0  zN0 (- xSp) Wnsd zN1   "Silicon" "R.nSrc")
(cuboid!    xSp  0.0  zN0    xC   Wnsd zN1   "Silicon" "R.nDrn")

(cuboid! (- xJ)  yCh0 zP0    xJ   yCh1 zP1   "Silicon" "R.pCh")
(cuboid! (- xSp) yCh0 zP0 (- xJ)  yCh1 zP1   "Silicon" "R.pExtS")
(cuboid!    xJ   yCh0 zP0    xSp  yCh1 zP1   "Silicon" "R.pExtD")
(cuboid! (- xC)  0.0  zP0 (- xSp) Wpsd zP1   "Silicon" "R.pSrc")
(cuboid!    xSp  0.0  zP0    xC   Wpsd zP1   "Silicon" "R.pDrn")

;; 3.2 HfO2 shells around each sheet, within the gate length
(cuboid! (- xG) (- yCh0 Tox) (- zN0 Tox)  xG (+ yCh1 Tox) (+ zN1 Tox) "HfO2" "R.nHK")
(cuboid! (- xG) (- yCh0 Tox) (- zP0 Tox)  xG (+ yCh1 Tox) (+ zP1 Tox) "HfO2" "R.pHK")

;; 3.3 Tungsten vias: nMOS vias land on the S/D extension beside the pMOS S/D
(define (via! xc yc zbot region)
  (cuboid! (- xc (/ ViaLx 2.0)) (- yc (/ ViaWy 2.0)) zbot
           (+ xc (/ ViaLx 2.0)) (+ yc (/ ViaWy 2.0)) zTop
           "Tungsten" region))

(via! (- xVia) yViaN zN1 "R.Via.nS")
(via!    xVia  yViaN zN1 "R.Via.nD")
(via! (- xVia) yViaP zP1 "R.Via.pS")
(via!    xVia  yViaP zP1 "R.Via.pD")

;; 3.4 Shared gate: fills around both high-k shells across the full cell width
(cuboid! (- xG) 0.0 0.0  xG Wcell zG1  "TiN" "R.Gate")

;; 3.5 Gate spacers (also act as inner spacers between the sheets)
(cuboid! (- xSp) 0.0 0.0 (- xG) Wcell zG1  "SiO2" "R.SpcS")
(cuboid!    xG   0.0 0.0    xSp Wcell zG1  "SiO2" "R.SpcD")

;; 3.6 Oxide under the nMOS S/D pads. The pads span the full cell width and
;;     seal this oxide off from the ILD; without its own regions the mesher
;;     splits the ILD into R.ILD_lump_N regions.
(cuboid! (- xC) 0.0 0.0 (- xSp) Wcell zN0  "SiO2" "R.PadOxS")
(cuboid!    xSp 0.0 0.0    xC   Wcell zN0  "SiO2" "R.PadOxD")

;; 3.7 Passivation: n/p S/D isolation (Dnp) and inter-via dielectric
(cuboid! (- xC) 0.0 0.0  xC Wcell zTop  "SiO2" "R.ILD")

;; 3.8 Buried oxide
(cuboid! (- xC) 0.0 (- Tbox)  xC Wcell 0.0  "SiO2" "R.BOX")


;; -----------------------------------------------------------------------------
;; 4. Doping
;;    One constant profile per silicon region; no overlapping placements, so
;;    no node receives two contributions. The S/D doping (pads + extensions)
;;    is abrupt at x = +/-Leff/2, i.e. Lov under each gate edge, as in Fig. 1(b).
;; -----------------------------------------------------------------------------
(sdedr:define-constant-profile "DC.nBody" "BoronActiveConcentration"      Nsub)
(sdedr:define-constant-profile "DC.pBody" "PhosphorusActiveConcentration" Nsub)
(sdedr:define-constant-profile "DC.nSD"   "PhosphorusActiveConcentration" Nsd)
(sdedr:define-constant-profile "DC.pSD"   "BoronActiveConcentration"      Nsd)

(define (dope-region! profile region)
  (sdedr:define-constant-profile-region (string-append "DP." region) profile region))

(dope-region! "DC.nBody" "R.nCh")
(dope-region! "DC.pBody" "R.pCh")
(for-each (lambda (r) (dope-region! "DC.nSD" r))
          '("R.nExtS" "R.nExtD" "R.nSrc" "R.nDrn"))
(for-each (lambda (r) (dope-region! "DC.pSD" r))
          '("R.pExtS" "R.pExtD" "R.pSrc" "R.pDrn"))


;; -----------------------------------------------------------------------------
;; 5. Contacts
;; -----------------------------------------------------------------------------
(sdegeo:define-contact-set "gate"     4.0 (color:rgb 1.0 0.0 0.0) "##")
(sdegeo:define-contact-set "n_source" 4.0 (color:rgb 0.0 0.0 1.0) "##")
(sdegeo:define-contact-set "n_drain"  4.0 (color:rgb 0.0 0.6 1.0) "##")
(sdegeo:define-contact-set "p_source" 4.0 (color:rgb 0.0 0.6 0.0) "##")
(sdegeo:define-contact-set "p_drain"  4.0 (color:rgb 0.6 0.8 0.0) "##")

;; Gate: every face of the gate-metal body becomes "gate"; the metal body is
;; then removed, leaving an ideal equipotential electrode on its boundary.
(sdegeo:set-current-contact-set "gate")
(sdegeo:set-contact-boundary-faces (find-body-id (P 0.0 yCh zGap)))
(sdegeo:delete-region (find-body-id (P 0.0 yCh zGap)))

;; S/D: top face of each via
(define (via-contact! name xc yc)
  (sdegeo:set-current-contact-set name)
  (sdegeo:set-contact-faces (find-face-id (P xc yc zTop))))

(via-contact! "n_source" (- xVia) yViaN)
(via-contact! "n_drain"     xVia  yViaN)
(via-contact! "p_source" (- xVia) yViaP)
(via-contact! "p_drain"     xVia  yViaP)


;; -----------------------------------------------------------------------------
;; 6. Mesh refinement
;; -----------------------------------------------------------------------------
(define (apply-size! name spec) (apply refine-size! (cons name spec)))

;; 4 nm wide refinement window centred on a junction plane at x = xc
(define (junction-window! tag xc z0 z1)
  (refwin! (string-append "RW." tag) (- xc 2.0) yCh0 z0 (+ xc 2.0) yCh1 z1)
  (sdedr:define-refinement-placement (string-append "RP." tag) "RS.Junc"
                                     (string-append "RW." tag)))

(display (string-append "Mesh level " (number->string MeshLevel))) (newline)

;; 6.1 All levels: global background and channel bodies
(apply-size! "RS.Global"  MeshGlobal)
(apply-size! "RS.Channel" MeshChannel)

(refwin! "RW.Global" (- xC) 0.0 (- Tbox) xC Wcell zTop)
(sdedr:define-refinement-placement "RP.Global" "RS.Global" "RW.Global")
(for-each (lambda (r)
            (sdedr:define-refinement-region (string-append "RP." r) "RS.Channel" r))
          '("R.nCh" "R.nExtS" "R.nExtD" "R.pCh" "R.pExtS" "R.pExtD"))

;; 6.2 Level >= 1: S/D, high-k, spacers, junctions, Si/HfO2 interface
(if (>= MeshLevel 1)
  (begin
    (apply-size! "RS.SD"     MeshSD)
    (apply-size! "RS.HighK"  MeshHighK)
    (apply-size! "RS.Spacer" MeshSpacer)
    (apply-size! "RS.Junc"   MeshJunc)

    (for-each (lambda (r)
                (sdedr:define-refinement-region (string-append "RP." r) "RS.SD" r))
              '("R.nSrc" "R.nDrn" "R.pSrc" "R.pDrn"))

    ;; High-k shells and spacers set Cgg and the gate-to-via fringe
    (sdedr:define-refinement-region "RP.nHK"  "RS.HighK"  "R.nHK")
    (sdedr:define-refinement-region "RP.pHK"  "RS.HighK"  "R.pHK")
    (sdedr:define-refinement-region "RP.SpcS" "RS.Spacer" "R.SpcS")
    (sdedr:define-refinement-region "RP.SpcD" "RS.Spacer" "R.SpcD")

    ;; Junctions at x = +/-Leff/2, one window per sheet and side, silicon only
    (junction-window! "nJuncS" (- xJ) zN0 zN1)
    (junction-window! "nJuncD"    xJ  zN0 zN1)
    (junction-window! "pJuncS" (- xJ) zP0 zP1)
    (junction-window! "pJuncD"    xJ  zP0 zP1)))

;; 6.3 Si/HfO2 interface layers (density-gradient quantization and the 2 nm
;;     oxide): refined normal to the interface on both sides, from both the
;;     silicon and the high-k placements so each region covers its own side.
(if (>= MeshLevel 1)
  (begin
    (sdedr:define-refinement-function "RS.Channel" "MaxLenInt" "Silicon" "HfO2"
                                      (* MeshIntSiHK nm) MeshIntRatio "DoubleSide")
    (sdedr:define-refinement-function "RS.HighK" "MaxLenInt" "HfO2" "Silicon"
                                      (* MeshIntSiHK nm) MeshIntRatio "DoubleSide")))

;; 6.4 Level 2: doping-gradient refinement
(if (= MeshLevel 2)
  (sdedr:define-refinement-function "RS.Channel" "DopingConcentration" "MaxTransDiff" 1))


;; -----------------------------------------------------------------------------
;; 7. Save and mesh
;;    This form runs on N-2017.09. If an older release rejects it, use:
;;    (sde:build-mesh "snmesh" "" OUT)
;; -----------------------------------------------------------------------------
(sde:save-model OUT)
(sde:build-mesh "" OUT)
