# Heart-Pump System Identification — How It Works

A reference for the team to understand and defend the analysis. Every step
names the technique, the equation, and the MATLAB function.

---

## 1. The goal

Given an input `u(t)` (e.g. piston position) and an output `y(t)` (e.g.
outlet flow), find a transfer function `H(s)` that predicts `y` from any
future `u`. Default model — 2nd-order standard form:

$$H(s) = \frac{K\,\omega_n^{2}}{s^{2}+2\zeta\,\omega_n s + \omega_n^{2}}$$

- **K** = DC gain (steady output / steady input)
- **ωₙ** = natural frequency (rad/s) — where the system most amplifies
- **ζ** = damping ratio — < 1 oscillatory, > 1 overdamped

---

## 2. Pipeline

```
CSV ─► resample ─► preprocess ─► split 50/50 ─┐
                                              │
                            ┌─────────────────┤
                            ▼                 ▼
                   non-parametric FRF      impulse response
                   (Welch H1 + coh²)       (SVD-Toeplitz)
                            │                 │
                            └────►  parametric fit (LM)  ────► validate (VAF, AIC)
                                                                    │
                                                                    └► sensitivity sweep
```

---

## 3. Steps, techniques, and key MATLAB calls

### 3.1 Resample to a uniform grid — `interp1`

Sensors arrive at different rates and jittered timestamps. Every
downstream method needs one uniform clock. We linearly interpolate every
channel onto a common `t = 0:1/fs:T`. Pick fs ≥ 5–10× the highest
frequency of interest; for the rig (≤10 Hz dynamics) **fs = 100–200 Hz**.

### 3.2 Preprocess — `detrend`, `butter`, `filtfilt`

- **Mean removal** prevents DC leakage in the FFT.
- **Butterworth low-pass** (`butter`) removes sensor noise above the band
  of interest.
- **Zero-phase application via `filtfilt`** runs the filter forward then
  backward so phase is unchanged. **A one-pass `filter` would corrupt
  the FRF phase — `filtfilt` is mandatory for system ID.**

### 3.3 Train / validation split

First half = fit data, second half = held-out test. The validation-half
score is the only honest accuracy number — fitting always looks good on
its own training data.

### 3.4 Non-parametric FRF — Welch's H1 estimator (`pwelch`, `cpsd`)

The conceptual heart of the analysis. For a linear system
`Y(f) = H(f)·U(f)`. Multiply by `U*(f)` and average:

$$\boxed{\;\hat H(f) = \frac{P_{yu}(f)}{P_{uu}(f)}\;}$$

This is the **H1 estimator**, unbiased when noise is on the output (the
usual case). H2 (`Pyy/Puy`) is biased the other way.

`Puu` and `Pyy` come from `pwelch`; `Pyu` from `cpsd`. Welch's method
chops the signal into overlapping Hann-windowed segments, FFTs each,
and averages — much lower variance than a single FFT.

**Crucially, the derivation makes no assumption about `u`'s shape.**
Sine, trapezoid, chirp, PRBS — any input works as long as it has energy
where you want to estimate. A trapezoid contains the fundamental plus
many harmonics, so it probes many frequencies at once.

### 3.5 Coherence² — the honesty check

$$\gamma^{2}(f) = \frac{|P_{yu}|^{2}}{P_{uu}\,P_{yy}} \in [0,1]$$

- **γ² ≈ 1**: linear input→output relationship at this frequency. Trust it.
- **γ² ≪ 1**: low input energy, output noise, *or* nonlinearity. Ignore it.

The bottom row of every Bode plot. **The single most important sanity
check in the analysis.**

### 3.6 Single-tone DFT (sine-sweep mode only)

When the input dwells at one frequency `f₀`, demodulate against
`cos(2πf₀t)` and `sin(2πf₀t)` to read off complex amplitude directly.
This is a 1-bin DFT computed as inner products — gives one
(magnitude, phase, γ²) point per dwell, overlaid on the Welch curve as
a cross-check. Disagreement between the two = nonlinearity at that
amplitude.

### 3.7 Impulse response — Wiener–Hopf + SVD (`xcorr`, `toeplitz`, `svd`)

Solve `R_uu·h = R_yu` (the Wiener–Hopf equation), where `R_uu` is the
Toeplitz autocorrelation matrix and `R_yu` the cross-correlation
vector. Direct inversion is ill-conditioned, so we take the SVD and
truncate small singular values — this is **Tikhonov regularization**.

A second, independent estimate. If FRF and impulse-response disagree on
DC gain (`sum(h)·dt`), something is wrong.

### 3.8 Parametric fit — Levenberg–Marquardt (`lsqnonlin`)

Fit `H(s; K, ωn, ζ)` to the Welch FRF by minimizing

$$\text{cost} = \sum_f \sqrt{\gamma^{2}(f)}\;\bigl|H_\text{model}(f) - \hat H(f)\bigr|^{2}$$

Two design choices to defend:

1. **Complex residuals** (`[real(e); imag(e)]` returned to `lsqnonlin`)
   fit magnitude *and* phase jointly. Magnitude-only fitting is a common
   bug that lets the model invent the wrong order.
2. **Coherence-weighted** residuals so unreliable frequencies don't drag
   the fit.

Initialized from the non-parametric FRF (peak → ωn, peak height → ζ,
DC value → K) — LM converges reliably from a good initial guess.

### 3.9 Validate on held-out half — `bilinear` + `filter`

We discretize the fitted continuous-time `H(s)` using **Tustin's
bilinear transform** (`bilinear`) and run the digital filter (`filter`)
on the held-out input. Tustin is the standard exact mapping —
preserves stability, minor warping near Nyquist (negligible for our
≤10 Hz / 200 Hz fs).

Two scores:

- **VAF** (Variance Accounted For):
  `100·(1 − var(error)/var(measured)) %`. Sample data → >95%; real rig
  data → 70–90% is normal and good.
- **AIC** = `N·log(SSE/N) + 2k`. Lower is better. Use it to pick model
  order — penalizes complexity.

### 3.10 Parametric sensitivity

Sweep each parameter ±20% holding others fixed; plot SSE vs. parameter.

- Sharp parabolic minimum → well-identified.
- Flat basin → data doesn't constrain that parameter; reported value
  suspect.
- Minimum offset from fitted value → optimizer didn't converge.

---

## 4. Three-way verification

The analysis is correct when these three independent estimates agree:

| Check | Where it comes from |
|---|---|
| FRF DC magnitude | `\|H(0)\|` from Welch |
| Impulse-response DC gain | `sum(h)·dt` from SVD-Toeplitz |
| Parametric K | from LM fit |

Disagreement = problem. Agreement = three different algorithms reaching
the same answer.

---

## 5. Sample data — expected results

Both CSVs in `sample_data/` were generated from a known plant for
`piston_pos → outlet_water_q`: **K = 0.85, fₙ = 2.4 Hz, ζ = 0.30**.

| Quantity | Expected (sweep_sample.csv) |
|---|---|
| Fitted K | 0.85 ± 5% |
| Fitted fₙ | 2.4 Hz ± 5% |
| Fitted ζ | 0.30 ± 10% |
| Static gain from impulse response | ≈ 0.85 |
| VAF on validation | > 95% |
| Coherence² at dwell freqs | > 0.95 |
| Coherence² between dwells | low (no input energy) |

---

## 6. Q&A cheat sheet

| Question | Answer |
|---|---|
| What FRF estimator? | Welch-averaged **H1**: `Pyu/Puu` via `pwelch` and `cpsd` |
| Why H1 not H2? | H1 is unbiased when noise is on the output — that's where sensor noise lives |
| How do non-sinusoidal inputs work? | H1 makes no assumption about `u`'s shape; only need `Puu(f) > 0`. Coherence² flags where it isn't |
| How is phase preserved? | `filtfilt` (zero-phase) for preprocessing; complex residuals inside `lsqnonlin` for fitting |
| Why Hann window? | Standard low-leakage taper for Welch segments |
| How avoid overfitting? | 50/50 split, AIC for order, coherence-weighted residuals |
| Why Levenberg–Marquardt? | Gauss–Newton near the optimum, gradient-descent far from it; initialized from the non-parametric FRF |
| Role of SVD in impulse response? | Tikhonov regularization — truncating small singular values stabilizes the `R_uu` inversion |
| Why continuous-time fit but digital simulation? | Physical parameters (K, ωn, ζ) live in s-domain; we discretize via Tustin (`bilinear`) only at sim time |
| Final accuracy number? | VAF on the **validation** half (training VAF is biased optimistic) |
| What if it's nonlinear? | Coherence² drops. Our toolkit doesn't fit Volterra kernels — that would be the next step |

---

## 7. Limits to acknowledge

- **SISO**: each run picks one input/output pair. No multi-input
  separation.
- **Time-invariant**: assumes the plant doesn't drift within a record.
- **Linear**: coherence² flags where this fails; nonlinear methods
  (Volterra, Hammerstein/Wiener) are out of scope.
- **No formal confidence intervals**: the sensitivity sweep is a
  qualitative substitute.
