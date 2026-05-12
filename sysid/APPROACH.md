# Heart-Pump System Identification — Approach & Codebase Audit

This document is the team's working plan: what we decided to do, why, what
the code does in support of it, and what's missing. It pairs with
`TECHNICAL.md` (the math reference) and `README.md` (usage instructions).

---

## 1. Strategy summary

### Goal
Build a model of the soft-robotic ventricle pump rig that explains how the
piston input affects the four downstream sensors (inlet air P/Q, outlet
water P/Q), validate it on held-out data, and characterize where the linear
approximation breaks down.

### Decisions we made

| # | Decision | Rationale |
|---|---|---|
| 1 | **Trapezoidal velocity excitation** as the primary excitation | Single broadband record covers many frequencies; firmware already supports it. The velocity profile is trapezoidal; integrated position is a smoothed triangle wave with rich odd-harmonic content. |
| 2 | **Welch H1 estimator** as the primary FRF method | Mathematically valid for any input that has energy at the frequencies of interest — no assumption that the input is sinusoidal. Coherence² flags where it fails. |
| 3 | **Single test at f₀ ≈ 0.1–0.5 Hz, 80 mm stroke** | Trapezoid harmonics at f₀, 3f₀, 5f₀, … cover 0–10 Hz densely. Stroke uses most of the soft limit (±43 mm from home translates to 0–80 mm one-sided motion that the rig actually performs). |
| 4 | **Amplitude staircase** for nonlinearity characterization | The system *will* be nonlinear (air spring `PV^γ`, elastomer hyperelasticity, quadratic flow resistance). Running ~3 amplitudes and watching fitted params drift is the standard "best linear approximation vs. amplitude" deliverable. |
| 5 | **2nd- to 4th-order parametric model**, fit via Levenberg–Marquardt to the FRF | Physical chain (air compliance → tubing → balloon → membrane → water-mass → air-head) implies at least two coupled second-order modes → minimum order 4. AIC chooses between candidate orders. |
| 6 | **Validate on the held-out half** of each record | The validation VAF is the only honest accuracy number; training-half VAF is biased optimistic. |
| 7 | **No new firmware excitations** for v1 (no chirp, no PRBS) | Classroom timeline doesn't justify firmware work. Trapezoidal excitation is sufficient for the FRF estimate. |
| 8 | **No Volterra / NARX black-box nonlinear ID** | Diminishing returns for a class project; the amplitude staircase already quantifies nonlinearity. |

### Test protocol on the rig

For each amplitude level (e.g. 20 mm, 40 mm, 80 mm peak-to-peak):

1. **Home the piston** (`H` over serial).
2. **Set up the trapezoid** using `pump_waveform_calc` — pick a target f₀
   and stroke; the reverse-calc fills in the controller fields (RPM,
   stroke units, accel/decel ms/Krpm).
3. **Start logging all four sensors** ~1 s before issuing `G`.
4. **Run ~10–20 cycles** so the record contains enough signal for Welch
   averaging.
5. **Save each record as a wide CSV** with one time column and five data
   columns (piston pos, inlet air P/Q, outlet water P/Q).
6. **Repeat at the next amplitude**, keeping f₀ constant.

Total bench time is ~15–30 minutes for a complete amplitude staircase.

---

## 2. How the analysis pipeline works (one paragraph each)

### 2.1 Resample
Sensors arrive on different clocks. Linearly interpolate each onto a
common uniform `t = 0:1/fs:T` so every downstream method (FFT, filter,
correlation) sees aligned data.

### 2.2 Preprocess
Subtract the channel mean (prevents DC leakage in spectra). Run a
zero-phase Butterworth low-pass via `filtfilt` (eliminates sensor
hash above the band of interest *without* phase distortion). Trim the
first second to drop the startup transient.

### 2.3 Spectrum check (input/output FFT)
Plot single-sided amplitude spectra of input and output side-by-side.
The input shows the trapezoid's odd-harmonic comb (1.04, 3.11, 5.19 Hz
etc. for a 1 Hz fundamental). The output shows the same comb scaled
by `|H(f)|`, plus any new spectral content the system invented — those
extras are nonlinear distortion. THD = power outside the input's
active bins / total output power.

### 2.4 Non-parametric FRF (Welch H1)
Chop the record into Hann-windowed overlapping segments. Estimate
`Puu(f)`, `Pyy(f)`, `Pyu(f)` by averaging across segments. Compute
`Ĥ(f) = Pyu/Puu` (the H1 estimator) and `γ²(f) = |Pyu|²/(Puu·Pyy)`
(magnitude-squared coherence). Plot all three. Coherence² is the
honesty check — only trust the FRF where γ² > 0.5.

### 2.5 Impulse response (SVD-Toeplitz)
Independent estimate of the same dynamics in the time domain. Solve
the Wiener–Hopf equation `R_uu·h = R_yu` with truncated-SVD
regularization. The static gain `sum(h)·dt` should match the FRF's
DC magnitude — three-way agreement (FRF, IR, parametric K) is the
internal consistency check.

### 2.6 Parametric fit (Levenberg–Marquardt)
Fit a continuous-time `H(s; K, ωn, ζ, …)` to the Welch FRF by
minimizing `Σ √γ²(f) · |H_model(f) − Ĥ(f)|²`. Complex residuals (real
and imaginary parts) so magnitude AND phase fit jointly. Coherence
weighting so unreliable frequencies don't dominate. Initial guess
read off the non-parametric FRF (peak → ωn, peak height → ζ, DC value
→ K).

### 2.7 Validate
Discretize the fitted continuous TF via Tustin/`bilinear`, run on the
held-out half of the input via `filter`. Compare predicted vs.
measured output. Compute VAF and AIC. VAF on held-out data is the
quoted accuracy.

### 2.8 Sensitivity
Sweep each fitted parameter ±20% with the others fixed; plot SSE.
Sharp parabolic minimum = parameter well-identified. Flat basin = the
data doesn't constrain that parameter; report it but flag suspicion.

### 2.9 Nonlinearity sweep (across amplitudes)
After running steps 2.1–2.8 at each amplitude, click "Add to set" with
a label. After 3+ amplitudes, "Plot comparison" overlays all Bodes,
plots fitted (fₙ, ζ) vs. amplitude, plots THD vs. amplitude, and prints
a summary table. **The parameter-vs-amplitude plot is the headline
nonlinearity result.**

---

## 3. Codebase audit

### 3.1 Pipeline functions (in `+sysid/`)

| File | Role | Status | Notes |
|---|---|---|---|
| `load_csv.m` | Read wide or per-channel CSVs | ✅ Implemented | Auto-detects ms vs s timestamps. |
| `resample_uniform.m` | Uniform-grid interpolation | ✅ Implemented | Common time window = intersection of all channels. |
| `preprocess.m` | Detrend + zero-phase LPF + trim | ✅ Implemented | Optional 60 Hz notch present but defaults off. |
| `segment_sine_sweep.m` | Detect dwell windows in a sine sweep | ✅ Implemented | Used only when `Excitation = sine_sweep`. |
| `segment_steps.m` | Detect step edges | ✅ Implemented | Not currently called by the GUI; available for future. |
| `frf_welch.m` | H1 + coherence² via Welch | ✅ Implemented | Auto-caps `nfft` so Welch always has ≥2 segments. |
| `frf_sine_dwell.m` | Per-dwell single-tone DFT | ✅ Implemented | Skipped in `broadband` mode. |
| `impulse_svd.m` | IR via SVD-Toeplitz | ✅ Implemented | Reports static gain `sum(h)·dt`. |
| `fit_param_tf.m` | LM fit of `H(s)` to the FRF | ✅ Implemented | 1st, 2nd, and free-polynomial orders supported. |
| `sim_ct.m` | Discretize + simulate continuous H(s) | ✅ Implemented | Tustin/bilinear; no Control System Toolbox needed. |
| `score_vaf.m` | Variance accounted for | ✅ Implemented | |
| `score_aic.m` | Akaike Information Criterion | ✅ Implemented | |
| `sensitivity.m` | ±20% parameter sweep | ✅ Implemented | |
| `plot_bode.m` | Generic Bode plot helper | ✅ Implemented | The GUI's plots are inline rather than calling this; the function is still available for scripted use. |
| `presentation_style.m` | Slide-friendly figure styling | ✅ Implemented | Skips marker-only plots when bumping line widths. |

### 3.2 Top-level drivers

| File | Role | Status | Notes |
|---|---|---|---|
| `sysid_gui.m` | The 5-step GUI + nonlinearity sweep | ✅ Implemented | Steps 1–5: raw → cleaned → spectrum → FRF+fit → validate. Adds runs to a comparison set; "Plot nonlinearity comparison" generates the headline figure. |
| `pump_waveform_calc.m` | Convert controller params ↔ waveform; reverse-calc from target f₀/stroke/α | ✅ Implemented | Forward and reverse paths. Accel/decel locked together. Position waveform shifted to start at 0 (one-sided motion). |
| `run_sysid.m` | Script-style driver as an alternative to the GUI | ✅ Implemented | Useful for batch processing or if uifigure is unavailable. |
| `verify_synthetic.m` | Self-test on a known 2nd-order plant | ✅ Implemented | Checks fitted params recover within tolerance. |
| `make_sample_data.m` | Regenerate the sample CSVs in MATLAB | ✅ Implemented | (CSVs already present in `sample_data/`.) |

### 3.3 Sample data

| File | Description |
|---|---|
| `sample_data/sweep_sample.csv` | 0.2–8 Hz stepped sine sweep, 48 s |
| `sample_data/trap_sample.csv` | Trapezoidal/broadband, 30 s |

Both generated from the known plant `K=0.85, fₙ=2.4 Hz, ζ=0.30` for the `piston_pos → outlet_water_q` pair. A correct toolkit run on either should recover those within ~5–10%.

### 3.4 Documentation

| File | Purpose |
|---|---|
| `README.md` | Setup, usage, GUI walkthrough |
| `TECHNICAL.md` | Math + technique names + MATLAB function reference + Q&A cheat sheet |
| `APPROACH.md` (this file) | Strategic plan + codebase audit |

---

## 4. End-to-end checklist before the talk

Verify with the team that each of these has been done at least once:

1. ☐ `verify_synthetic` runs and recovers `K=1.5, fn=3 Hz, ζ=0.25` within 5%.
2. ☐ `pump_waveform_calc` produces a reasonable waveform for the planned test (f₀ ~0.2 Hz, 80 mm stroke).
3. ☐ Trapezoidal record on the rig captured at the chosen amplitude — all four sensors logged.
4. ☐ `sysid_gui` Step 1 (raw) — the input + output time traces look qualitatively correct.
5. ☐ `sysid_gui` Step 2 (cleaned) — high-frequency hash gone, signal preserved.
6. ☐ `sysid_gui` Step 3 (spectrum) — input shows clean odd-harmonic comb; output spectrum compared against input.
7. ☐ `sysid_gui` Step 4 (FRF + fit) — Welch curve, parametric overlay, impulse response, fitted parameters all plausible. Coherence² is high at the input's harmonics.
8. ☐ `sysid_gui` Step 5 (validate) — VAF reported on held-out data.
9. ☐ At least 3 amplitude records run, each added to the comparison set with labels (e.g. "20mm", "40mm", "80mm").
10. ☐ "Plot nonlinearity comparison" generated — parameter drift and THD vs. amplitude visible.
11. ☐ THD computed and reported as a single number per amplitude.
12. ☐ Three-way consistency check: FRF DC mag ≈ impulse-response static gain ≈ fitted K.

---

## 5. Known gaps / nice-to-haves (deferred)

These are *not* needed for the class deliverable but are flagged so the team can decide if any are worth a few hours.

| Gap | Difficulty | What it would add |
|---|---|---|
| **Batch mode** for the nonlinearity sweep | ~1 hour | Point at a folder of CSVs, label-from-filename, auto-process all of them. |
| **Hammerstein nonlinearity** (static input distortion + LTI) | ~half day | Closes the VAF gap on strongly nonlinear records by ~10–20 percentage points. |
| **Cross-excitation validation** | ~2 hours | Train on trapezoid record, validate on a sine-dwell record at a key frequency — much stronger generalization claim. |
| **Bode confidence intervals** | ~half day | Per-bin variance of `H(f)` from the Welch averaging would let us put error bars on the Bode and on the fitted parameters. |
| **Operating-point sweep** (mean position) | data-only | Run the same amplitude staircase at three different mean piston positions — would isolate the air-spring nonlinearity from the elastomer one. |

---

## 6. The one-paragraph version (for the slide)

> We excite the pump with a trapezoidal velocity profile (stroke ≈ 80 mm,
> fundamental ≈ 0.2 Hz). The trapezoid's odd-harmonic comb covers 0–10 Hz
> densely, letting Welch's H1 estimator (`Pyu/Puu`) recover the entire
> frequency response from a single record. Coherence² flags which
> frequency bands are trustworthy. We fit a 2nd- to 4th-order
> continuous-time transfer function to the FRF using Levenberg–Marquardt
> with coherence-weighted complex residuals, validate on the held-out
> half via Tustin discretization + filter, and quantify nonlinearity by
> repeating the experiment at multiple amplitudes and reporting fitted
> parameters and total harmonic distortion vs. amplitude.
