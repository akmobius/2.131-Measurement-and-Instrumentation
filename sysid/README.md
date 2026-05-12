# sysid — Heart-Pump System Identification Toolkit (MATLAB)

Offline CSV-driven system ID for the soft-robotic ventricle pump rig. Computes
non-parametric FRF (Welch H1 + coherence²), impulse response (SVD-of-Toeplitz),
and a parametric transfer-function fit (Levenberg–Marquardt) with VAF / AIC
scoring and parametric sensitivity sweeps.

## Quick start

```matlab
cd sysid
sysid_gui            % point it at sample_data/sweep_sample.csv and click RUN
```

Or skip the GUI:

```matlab
cd sysid
verify_synthetic     % toolbox self-test on a known 2nd-order plant
run_sysid            % full pipeline; edit the USER CONFIG block first
```

## Layout

```
sysid/
├── sysid_gui.m         ← simple uifigure GUI: pick CSV, map columns, RUN
├── run_sysid.m         ← script driver — edit USER CONFIG, then run
├── verify_synthetic.m  ← end-to-end self-test on a known 2nd-order system
├── make_sample_data.m  ← regenerate the sample CSVs in MATLAB
├── sample_data/        ← test data (already provided)
│   ├── sweep_sample.csv  (sine sweep, 0.2..8 Hz dwells)
│   └── trap_sample.csv   (trapezoidal/broadband)
├── README.md
└── +sysid/             ← package functions
    ├── load_csv.m
    ├── resample_uniform.m
    ├── preprocess.m
    ├── segment_sine_sweep.m
    ├── segment_steps.m
    ├── frf_welch.m
    ├── frf_sine_dwell.m
    ├── impulse_svd.m
    ├── fit_param_tf.m
    ├── score_vaf.m
    ├── score_aic.m
    ├── sensitivity.m
    └── plot_bode.m
```

## Required toolboxes
- Signal Processing Toolbox (`pwelch`, `cpsd`, `butter`, `iirnotch`, `xcorr`, `bilinear`)
- Optimization Toolbox (`lsqnonlin`)

(No Control System Toolbox needed — time-domain sim uses bilinear+`filter`.)

## Expected CSV format

Two layouts supported by `sysid.load_csv`:

**A) One file per channel:** each CSV has two columns `[time, value]`. Time
may be in seconds or milliseconds (auto-detected). Pass parallel cellstrs
for `cfg.csv.files` and `cfg.csv.roles`.

**B) One wide CSV:** all channels in one file. `cfg.csv.roles` is a struct
mapping CSV-column-name → role name, plus `cfg.csv.time_col` for the time
column.

Recommended role names (match `CLAUDE.md` channel list):
`piston_pos`, `inlet_air_p`, `inlet_air_q`, `outlet_water_p`, `outlet_water_q`.

## Importing your own test data

Raw test recordings live as comma-separated `.txt` files in folders named
`Test N <freq> <stroke>` (one folder per run). The header row of each
file looks like:

```
time, pressure1, pressure2, out_flow, in_flow
```

Run the converter once to turn every `.txt` in those folders into a
sysid-ready `.csv` next to it:

```matlab
convert_test_data
```

This drops the (unconnected) pressure columns, converts time from
milliseconds to seconds (rebased to 0), and writes columns named
`time_s`, `inlet_air_flow`, `outlet_water_flow` — names that the GUI's
column-mapping table auto-guesses correctly.

### Per-channel calibration

The flow channels are uncalibrated by default (scale = 1, offset = 0).
**System ID does not require a correct calibration** — a linear gain or
offset on either channel only rescales the reported `K`; the FRF shape,
fitted `fn`, `zeta`, coherence², and VAF are all unchanged. Leave the
defaults unless you want the K column in the comparison table to read in
real units.

When you have actual calibration numbers, pass them as a struct:

```matlab
cal.inlet_air_flow.scale     = 0.045;     % LPM per ADC count, say
cal.inlet_air_flow.offset    = -2.1;
cal.outlet_water_flow.scale  = 1.0e-3;
cal.outlet_water_flow.offset = 0;
convert_test_data(pwd, cal);
```

Calibration is applied as `calibrated = raw * scale + offset` per
channel, independently. Re-run the converter any time you update the
numbers.

## Sample data

`sample_data/sweep_sample.csv` and `sample_data/trap_sample.csv` are pre-built
test files generated from a known 2nd-order plant
(`piston_pos → outlet_water_q`: K=0.85, fn=2.4 Hz, ζ=0.30). A correct fit on
the sweep file should recover those parameters within ~5% with VAF > 95%.

To regenerate them inside MATLAB (e.g. after changing the synthetic plant):

```matlab
make_sample_data
```

## GUI usage

```matlab
sysid_gui
```

1. **Browse...** to a CSV (try `sample_data/sweep_sample.csv`).
2. The mapping table auto-guesses each column's role from its name —
   override any row by clicking its Role cell. Set the **Time column**.
3. Pick **Input role** / **Output role** and set **Excitation**.
4. Step through the four stage buttons in order. Each one:
   - runs that stage of the pipeline,
   - opens a presentation-quality figure (large fonts, clean layout),
   - saves a PNG to `<csv_folder>/results/`:

| Button | Figure saved | What it shows |
|---|---|---|
| Step 1 — Load & plot raw | `step1_raw.png` | Raw input + output time series |
| Step 2 — Resample/filter/trim | `step2_preprocess.png` | Before vs after preprocessing for both channels |
| Step 3 — FRF + parametric fit | `step3_fit.png` | Bode (mag/phase/coh²) + LM fit overlay + dwell points + impulse response + fitted parameters |
| Step 4 — Validate | `step4_validation.png` | Predicted vs measured + residual on the held-out half; also writes `results.mat` |

The four PNGs are designed to drop straight into a slide deck.

## Script usage

1. Open `run_sysid.m` and edit the USER CONFIG block:
   - point `cfg.csv.files` / `cfg.csv.roles` at your data,
   - set `cfg.input_role` and `cfg.output_role` to the I/O pair you want to ID,
   - set `cfg.excitation` to `'sine_sweep'` or `'broadband'` (trapezoid/step),
   - tune `cfg.preprocess.lp_cutoff` and `cfg.fit.order`.
2. Run the script. Results land in `sysid/results/`:
   - `bode.png` — Welch H1 magnitude/phase + coherence² + parametric overlay
   - `impulse.png` — SVD-Toeplitz impulse response
   - `validation.png` — measured vs predicted on the held-out half
   - `sensitivity.png` — SSE vs each parameter, ±20%
   - `results.mat` — struct with everything (`frf`, `ir`, `fit`, `sens`, ...)

## Recommended workflow

1. Run `verify_synthetic.m` once to confirm the toolbox works on your machine
   (fits a known `tf([1],[1 0.4 1])` to within a few percent and VAF > 95%).
2. Capture rig data with the existing pump driver — start with **trapezoidal**
   excitation for a fast broadband first look (`cfg.excitation='broadband'`).
3. Look at the Bode plot. Where coherence² drops below 0.5, the linear model
   isn't trusted — re-excite there with **sine dwells** (PS commands at a
   handful of frequencies) and rerun with `cfg.excitation='sine_sweep'`.
4. Pick `cfg.fit.order` by comparing AIC across orders 1, 2, 3 on the same
   dataset (rerun and inspect `aic_validation` in `results.mat`).
5. Use the sensitivity plot to flag parameters that the data does not pin
   down (broad / flat SSE basin → unidentified parameter).

## Notes

- All filtering is zero-phase (`filtfilt`). Phase preservation is required for
  honest FRF estimation.
- Welch H1 (`Pyu/Puu`) handles non-sinusoidal output naturally — preferred over
  single-tone amplitude division for mildly nonlinear systems like this rig.
- Coherence² is computed and plotted on every Bode; rule of thumb is that
  bands with coh² < 0.5 should not be trusted for parametric fitting.
- The parametric fit weights residuals by √coherence² so unreliable
  frequencies don't dominate the cost.
- The held-out validation half is what you should report — frequency-domain
  fit quality is easy to inflate by overfitting.
