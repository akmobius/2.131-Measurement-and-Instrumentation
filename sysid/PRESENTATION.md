# System Identification — Presentation Outline (Slides 11+)

The team's existing deck (slides 1–10) covers:

| Slide | Content |
|---|---|
| 1 | Title — "System Identification of a 3D-Printed Metamaterial-Based Soft Robotic Ventricle" |
| 2 | Recap block diagram — electro-pneumatics → actuator → mock circulatory flow loop, with pressure (P) and flow (F) measurement points |
| 3 | Metamaterial actuator cross-section — actuator cavity (porous metamaterial) vs. ventricle cavity (inner water chamber), Formlabs Elastic 50A |
| 4 | Photo of physical setup with sensors and pump labeled |
| 5 | DAQ for pressure sensors — PendoTECH → NAU7802 ADC → I²C mux → Arduino Nano Every, 320 sps |
| 6 | DAQ extension for flow sensors — Transonic T402 perivascular flow modules with separate ADCs |
| 7 | Why hydraulic-piston input replaced the old vacuum-chamber input — incompressible 1:1 displacement control, higher flow rate, continuous operation |
| 8 | Hydraulic pump assembly — NEMA 23 servo + SFU1605 ballscrew + SC80 piston on a 2020 T-slot frame |
| 9 | (blank — natural section break, possibly transition to "Part 2: System Identification") |
| 10 | PendoTECH pressure-sensor specs — accuracy, range, output coefficient |

This document covers the **system identification half**, starting at slide 11.
The arc is:

```
predicted physics      method choice + assumptions      test design
        │                          │                          │
        └────────┬─────────────────┴──────────────────────────┘
                 ▼
         execute the test (broadband)
                 │
                 ▼
   discover the system is nonlinear  ←─── inflection point
                 │
                 ▼
   diagnose WHY broadband approach fails
                 │
                 ▼
   adapt the methodology (describing-function approach)
                 │
                 ▼
   plan + future work
```

---

# SECTION 1 — Setting Up the System ID (Slides 11–14)

## Slide 11 — Flow sensor specs (mirrors slide 10)

**Goal**: complete the sensor characterization picture from slide 10
before pivoting to system ID.

**Bullets**:
- **Transonic T402** Perivascular Flow Module
- ±12 V analog output, scaled by 1/3 voltage divider to ADC range
- 16-bit ADS1115 ADC for the flow channels (separate from pressure
  ADC chain)
- For our test: outlet flow channel was active; uncalibrated raw counts
  (unknown scale/offset)
- Calibration would be a per-sensor lab procedure; not needed for FRF
  analysis since it removes only DC offset and a scaling constant —
  neither affects the *shape* of the Bode plot

**Plot**: Transonic spec sheet excerpt + the wiring schematic from
slide 6.

**Speaker notes**:
> "Flow sensing is a Transonic T402 with a 16-bit ADC. We didn't
> calibrate the output to absolute units for this experiment — the
> raw counts capture the time-domain shape and frequency content,
> which is everything system ID needs. The DC offset and scale factor
> would just be constants applied to the magnitude of the Bode plot."

---

## Slide 12 — Goal of the system ID effort

**Goal**: pivot from "here's the rig" to "here's what we want to extract."

**Bullets**:
- Build a quantitative model that maps **piston input → mock-loop output**
- Two deliverables:
  - **Non-parametric** model: Bode plot — magnitude/phase at every
    measurable frequency
  - **Parametric** model: a transfer function `H(s)` with named
    parameters (gain, natural frequency, damping)
- Quantification of **where the model is valid** — what amplitudes,
  what frequency band — and how nonlinear the system is
- **Subsystem isolation** by testing multiple input/output configurations
  (air-in vs water-in, water-out vs pressure-out) — each combination
  isolates a different part of the dynamic chain
- Long-term value: predictive control design, comparison across
  metamaterial geometries, sanity check for future physics models

**Plot**: simple block diagram `u(t) → [box] → y(t)` with the box
being the rig from slide 2; arrows labeled with the candidate I/O
channels (piston_pos via air or water, inlet_air_p, inlet_air_q,
outlet_water_p, outlet_water_q).

**Speaker notes**:
> "Two deliverables — Bode plot and parametric model — plus a
> characterization of where the model is valid. A unique advantage
> of our setup: we can swap the input fluid between air and water.
> By comparing system behavior under each configuration, we can
> identify which nonlinearities live in which subsystem — air-side
> compliance vs. metamaterial deformation vs. fluid-side dynamics."

---

## Slide 13 — What the physics predicts before we measure

**Goal**: ground the experiment in first-principles expectations so
the data either confirms or contradicts them. Sets up every later
finding as a falsifiable hypothesis.

**Bullets**:

**System architecture as a dynamic chain** (current configuration:
*air input, water output*):

| Element | Dynamic role | Frequency contribution |
|---|---|---|
| Piston (air) | input — *compressible*, displacement → pressure rise | all frequencies |
| Air column → actuator cavity | gas spring (`PV^γ` compliance) | low–mid |
| Metamaterial actuator structure | nonlinear spring (hyperelastic Formlabs Elastic 50A) | mid |
| Ventricle cavity walls | additional spring (elastomer) | mid |
| Water in ventricle + tubing | mass (hydraulic inertia: `M = ρL/A`) | low–mid |
| Output flow sensor + tubing | inertance + viscous loss | mid–high |
| Mock-loop output load | compliance + flow resistance | low |

**Key consequence of the air-input choice**:
- The piston-to-actuator interface is **mediated by an air spring**
  (the air column between piston and actuator cavity)
- Under vacuum / under pressure, the air spring's stiffness depends
  on operating pressure (`dP/dV ∝ γP/V`) — already a nonlinear element
  *before* we get to the metamaterial
- This is why we're also investigating **hydraulic input** (slide 7):
  swapping water for air at the input lets us *separately* identify
  the air-spring contribution by comparing the two configurations

**Predicted minimum order**: 4 (two coupled second-order modes; could
be higher if the air spring decouples enough to add its own mode)

**Predicted resonances**:
- **Low-frequency mode** combining air-side compliance + water mass +
  output-loop compliance → likely **0.3–1 Hz**
- **Higher mode** from inflow/outflow tubing inertance + actuator
  cavity compliance → likely **3–15 Hz**, depending on tube geometry

**Predicted Bode shape**:
- Flat at very low frequency (DC gain set by geometric efficiency —
  but small, because air compressibility absorbs much of the piston
  motion before any water moves)
- Resonant peak around the low-frequency mode
- −40 dB/decade roll-off after first peak; possibly a second peak
  followed by −80 dB/decade

**Predicted nonlinearities**:
- **Air-spring rectification** (`PV^γ`): stiffer at compression, softer
  at vacuum → asymmetric response → generates *even harmonics* in the
  output. Operating-point dependent.
- **Hyperelastic stiffening of the metamaterial** at large strain:
  natural frequency *rises* with amplitude
- **Asymmetric metamaterial deformation** in expansion vs compression
  (the porous geometry isn't symmetric under inversion): also
  contributes even harmonics
- **Quadratic flow resistance** (`Δp ∝ ρv²`) in tubing at higher
  flows: damping ratio *rises* with amplitude

**Predicted in coherence²**: γ² > 0.85 *if* the rig is operating
linearly at our drive amplitude. Substantially lower means we're
already nonlinear — and we'd predict this to happen at large strokes
where (a) the air spring is far from its mid-pressure linearization,
(b) the metamaterial enters its hyperelastic regime.

**Plot**: hand-sketched expected Bode plot with the predicted features
labeled (low-frequency peak around 0.5 Hz, secondary peak around 5 Hz,
roll-off slopes), alongside the actuator cross-section from slide 3
with each compliant element circled and the air spring shown as a
springy element between piston and actuator.

**Speaker notes**:
> "Before we ID, we predict. With air input the piston-to-actuator
> coupling goes through an air spring, which adds compliance — and
> nonlinearity — on the input side. We expect at least 4th-order
> behavior. *Four* nonlinearities we'd predict: air-spring
> rectification, hyperelastic stiffening, asymmetric metamaterial
> deformation, and quadratic flow resistance. Each has a distinct
> experimental signature we can look for. And by later swapping the
> input to hydraulic, we can quantitatively separate the air-spring
> contribution from the rest."

---

## Slide 14 — Choosing the system ID method

**Goal**: explicitly justify the methodology before showing results.
The class will care about this.

**Bullets**:

**Two big choices in the SysID design space**:
1. Non-parametric vs. parametric (`Bode plot` vs `H(s)`)
2. Broadband vs. single-frequency excitation (one fast test vs. many
   slow tests)

**Our initial choice**: broadband + non-parametric (Welch's H1
estimator), then a parametric LTI fit on top.

**Rationale**:
- **Efficiency**: a single excitation record gives a Bode estimate at
  every frequency the input contains energy
- **Industry standard for plant ID with output-side noise**: H1 is
  the unbiased estimator under that noise model
- **Built-in diagnostic**: coherence² tells us *where* to trust the
  result without needing additional tests
- **Existing firmware support**: trapezoidal velocity command is
  natively in the servo firmware — no new firmware needed
- **Fits our DAQ rate**: 320 sps for pressure / higher for flow easily
  resolves up to ~100 Hz

**The compromise we accepted up front**:
- The result is only meaningful if the system is approximately
  linear — flagged as the key risk before the test, *to be verified
  from the data via coherence²*

**Plot**: 2×2 matrix showing the four method quadrants
(parametric/non-parametric × broadband/single-frequency), with our
initial choice marked and the alternative quadrants labeled
"backup options."

**Speaker notes**:
> "There are four quadrants in the SysID design space. We picked the
> most efficient one — broadband non-parametric — knowing that its
> validity rests on the linearity assumption. We made that choice
> deliberately, with the explicit understanding that we'd verify the
> assumption from the data itself."

---

# SECTION 2 — Test Design and Pipeline (Slides 15–18)

## Slide 15 — Assumptions and limitations

**Goal**: explicit list. Rigorous SysID requires this.

**Bullets**:

**Assumptions made by the H1 estimator**:
1. **Linearity** — output is a linear function of input; superposition
   holds. Test: coherence² > 0.85 at frequencies of interest.
2. **Time invariance** — plant doesn't drift during the record.
   Test: parameter consistency across consecutive runs.
3. **Causality** — output doesn't precede input. Test: phase ≤ 0°
   for all f (positive phase = non-physical).
4. **Stationarity** of the input — input statistics don't change
   across the record. The trapezoidal excitation satisfies this by
   construction.
5. **Output-side noise** — random disturbances are on the output, not
   the input. Reasonable for our setup (DAQ noise is on the sensor
   side; controller is deterministic).
6. **Sufficient excitation** — the input has energy at every frequency
   we want to estimate. Test: input PSD vs. frequency.

**Limitations going in**:
- **Single-test result is amplitude-dependent** if the system is
  nonlinear — broadband test conflates response across all amplitudes
  the trapezoid covers
- **Welch averaging** trades frequency resolution for variance —
  short records limit how low in frequency we can resolve
- **DAQ timing**: the input controller and the output flow ADC ran on
  separate clocks. Up to ~150 ms alignment uncertainty between them.
  Manual cropping in the analysis tool is the workaround.
- **Pressure sensors not connected during this session** → we could
  only examine the {piston_pos, outlet_water_q} pair, not the
  intermediate pressure stages

**Plot**: list with red/yellow/green dots indicating which limitations
were mitigatable, accepted, or future work.

**Speaker notes**:
> "Six assumptions, four mitigatable limitations, two we couldn't avoid
> in this session. The most important assumption is linearity, and the
> most important diagnostic — coherence² — directly tests it."

---

## Slide 16 — Test design: the waveform calculator

**Goal**: walk through how we designed the test before running it.

**Bullets**:
- Custom MATLAB tool (`pump_waveform_calc.m`) converts servo controller
  parameters (RPM, stroke in 0.1-rev units, accel/decel in ms/Krpm)
  into physical units (mm, mm/s, mm/s²) and predicts the spectrum
- Reverse mode: input target f₀ + stroke + accel fraction → tool
  outputs RPM/stroke/accel for the controller GUI
- Predicts the harmonic comb the trapezoid will deliver before any
  rig time is spent

**Test parameters chosen for first run**:
- f₀ = 0.5 Hz fundamental (cycle period 2 s)
- 80 mm peak-to-peak stroke (max safe travel on the SFU1605 stage)
- 10 cycles per record (~20 s usable data)
- Sharp accel/decel for richer high-frequency harmonic content

**Plot**: screenshot of the calculator GUI populated with these values,
showing the predicted position waveform (smoothed triangle) and the
predicted FFT comb at 0.5, 1.5, 2.5, 3.5, 4.5 Hz.

**Speaker notes**:
> "The calculator forces us to commit on paper to what we expect to
> see, before running. With f₀ = 0.5 Hz and 80 mm stroke, the
> trapezoid puts five clean odd-harmonic spikes in the 0.5–5 Hz
> band — exactly the range our predicted dynamics live in."

---

## Slide 17 — The experimental matrix: input/output configurations

**Goal**: highlight the multi-configuration experimental design as a
deliberate strategy for **isolating which subsystem each nonlinearity
lives in**.

**Bullets**:

**The rig is configurable along two axes**:
- **Input fluid**: pneumatic (air) or hydraulic (water)
- **Output side**: water flow (primary) and water pressure
- → at least **4 distinct test configurations**, each probing the
  system differently

**Configuration matrix and what each isolates**:

| Input | Output | What it probes | Status |
|---|---|---|---|
| **Air** | water flow | full chain: air spring → metamaterial → fluid loop | **today's test** |
| Air | water pressure | full chain, with pressure-side dynamics | future |
| Water | water flow | metamaterial + fluid loop *without* air spring | future |
| Water | water pressure | metamaterial + fluid loop, pressure response | future |

**Why this matters scientifically**:
- Comparing **air-input vs. water-input** at the same output isolates
  the *air-spring contribution* — a direct experimental separation
  of one specific nonlinearity from the others
- Comparing **flow-output vs. pressure-output** under the same input
  reveals the impedance characteristics of the output fluid loop

**For today's test (air-in / water-flow-out)**:
- Input: piston position (commanded, encoder-fed) — the most
  directly known signal in the chain
- Output: outlet water flow (Transonic) — the rig's primary
  functional output
- This pair captures the **entire dynamic chain**, but conflates all
  the nonlinearities; later tests will separate them

**Why piston position over piston velocity**: equivalent up to a
derivative, but position is the directly commanded signal. Fewer
numerical-derivative artifacts than computing velocity from position.

**Why measured flow over computed (theoretical) flow**: theoretical
inlet flow = `velocity × piston area`, but with air at the input
this *isn't* what physically happens (compressibility) — it's a
calculated idealization, not a measurement.

**Plot**: the actuator diagram from slide 3 + slide 4 set-up photo,
with the four configurations labeled by colored arrows; today's
configuration highlighted; other configurations dimmed and labeled
"future work."

**Speaker notes**:
> "We have a deliberate experimental design here, not just one test.
> The rig is configurable in two ways — input fluid and output
> side — giving us at least four distinct test configurations.
> Today's data is air-in / water-flow-out, which captures the
> whole chain but doesn't separate where the nonlinearities live.
> The plan, once we have a clean characterization in this
> configuration, is to swap the input to water and rerun: the
> *difference* between the two configurations is exactly the
> air-spring contribution. That's a quantitatively meaningful
> subsystem isolation."

---

## Slide 18 — The 6-stage analysis pipeline

**Goal**: show the workflow at a glance. Each stage is one button in
the GUI.

**Bullets**:
1. **Raw data** — confirm both signals look reasonable
2. **Cleaned data** — resample to common clock, mean-remove, low-pass,
   crop+align (manual to handle the DAQ timing offset)
3. **Spectrum (FFT)** — where does the input put energy? where does
   the output have content?
4. **FRF + parametric fit** — Welch H1 + Levenberg–Marquardt fit of
   `H(s)`
5. **Validation** — predict the held-out half, compute VAF + AIC
6. **Nonlinear (Hammerstein-Wiener) fit** — used as a fall-back when
   the linear model doesn't fit well

**Plot**: screenshot of the GUI showing the 6 stage buttons; brief
caption indicating each stage saves a presentation-quality PNG to disk.

**Speaker notes**:
> "Six stages. Each one has a specific question it answers, and each
> stage's plot is saved at presentation quality so it can drop
> straight into a slide. Skipping any stage means losing a diagnostic."

---

# SECTION 3 — Results: the Linear Approach (Slides 19–23)

## Slide 19 — Stage 1+2: data quality is fine

**Bullets**:
- Input: clean smoothed-triangle position waveform, ±40 mm AC swing
  around the home position
- Output: oscillates at the input fundamental, ±~4 LPM peak (raw
  uncalibrated counts)
- Output qualitatively tracks the input but with sharp transitions
  and visible mid-cycle ringing — first hint of nonlinearity
- Preprocessing applied: 1000 Hz uniform resample, 25 Hz zero-phase
  Butterworth low-pass, mean removal, manual crop to the test window

**Plot**: `step1_raw.png` and `step2_preprocess.png` side-by-side.

**Speaker notes**:
> "Data is good — no sensor saturation, no dropouts, output amplitude
> consistent across cycles. The fine structure inside each output
> cycle is the first hint that the relationship isn't simply linear,
> but we'll quantify that."

---

## Slide 20 — Stage 3: the spectrum is where the story breaks open  ★

**Goal**: the headline figure of the talk.

**Bullets**:
- **Input spectrum**: clean odd-harmonic comb — peaks at 0.5, 1.5, 2.5,
  3.5 Hz, gaps at 1, 2, 3 Hz with energy ~10⁵× lower (this is exactly
  the spectrum of a symmetric triangle wave)
- **Output spectrum**: peaks at *every integer multiple of 0.5 Hz* —
  at 1, 2, 3 Hz too, where the input is essentially silent
- **Quantitative**: ~15–25% of output power lives at frequencies
  the input does not excite — quantitative THD measurement
- **This confirms the prediction from slide 13**: even harmonics in
  the output are exactly the signature of asymmetric metamaterial
  response we predicted from physics

**Plot**: `step3_spectrum.png` — large, prominent. **Annotate or circle
the even-harmonic peaks** at 1, 2, 3 Hz in the output spectrum.

**Speaker notes**:
> "This is the single most important plot in the talk. The input has
> only odd harmonics — that's a property of the symmetric trapezoid.
> A linear system would respond *only* at those frequencies. Our
> output has peaks at every integer multiple of 0.5 Hz — at 1 Hz,
> 2 Hz, 3 Hz — at frequencies the input never contained. The
> system is *generating* those harmonics. That's the definition of
> nonlinearity, demonstrated quantitatively, and it confirms what we
> predicted from physics on slide 13."

---

## Slide 21 — Stage 4: the Bode plot reflects the same problem

**Bullets**:
- Welch H1 magnitude is noisy; no clear roll-off pattern
- Phase wraps unpredictably — `unwrap` artifacts when the phase data
  is noisy
- **Coherence² < 0.5 across nearly the entire band** — only a single
  peak at ~3 Hz reaches γ² ≈ 0.65 (one trustworthy point)
- 4th-order linear LM fit doesn't track the data — there's no
  coherent linear structure to fit
- This isn't a code bug. Welch and the LM optimizer are mathematically
  correct — we're applying them to data that violates their
  underlying assumption

**Plot**: `step4_fit.png` — your most representative Bode plot.

**Speaker notes**:
> "Coherence² below 0.5 means less than half of the output's energy
> at each frequency is linearly related to the input. The other half
> is the harmonic distortion we just saw on slide 20. The linear fit
> can't track because the data doesn't actually have a single linear
> response to fit to."

---

## Slide 22 — Stage 5: validation confirms it

**Bullets**:
- Linear model on held-out validation half: VAF ≈ −50% (worse than
  predicting the mean)
- 4th-order H(s) fit; sensitivity sweep showed parameters were not
  uniquely identifiable
- Validation prediction completely fails to track the measured output
- The "best linear approximation" exists but doesn't generalize

**Plot**: `step5_validation.png`

**Speaker notes**:
> "Validation VAF is negative — the model is worse than just
> predicting the mean. The numbers are consistent with what we'd
> expect from coherence² < 0.5: there's no linear model that fits."

---

## Slide 23 — Stage 6: structured nonlinear modeling didn't fix it either

**Bullets**:
- Tried a **Hammerstein-Wiener** model (MATLAB `nlhw`): static input
  nonlinearity → LTI block → static output nonlinearity
- VAF ≈ -10000% on validation — model became unstable, prediction
  diverged exponentially
- **Why it failed**: broadband data doesn't constrain a structured
  nonlinear model. The optimizer found a degenerate local minimum
  (input nonlinearity collapsed to zero, linear block ended up with
  unstable poles)
- **Throwing more model complexity at the problem made it worse, not
  better**

**Plot**: `step6_nlhw.png` showing the divergence.

**Speaker notes**:
> "We tried a structured nonlinear model — Hammerstein-Wiener,
> standard for control identification — and it failed worse than
> the linear model. The reason: broadband data simply doesn't
> distinguish linear from nonlinear contributions cleanly. With a
> more flexible model and the same data, the optimizer just finds
> degenerate solutions. Model complexity has to match the
> information content in the data."

---

# SECTION 4 — Diagnosis: Why the Linear Approach Fails (Slides 24–25)

## Slide 24 — BLA vs transfer function (the rigorous answer)

**Goal**: rigorous explanation of *why* the linear fit was unreliable.

**Bullets**:
- For an LTI system: `Pyu(f)/Puu(f) = H(f)` — a fixed property of the
  system, valid regardless of input shape or amplitude
- For a nonlinear system: `Pyu(f)/Puu(f) = G_BLA(f)` — the
  **Best Linear Approximation**, which:
  - Depends on the input *amplitude*
  - Depends on the input *spectrum*
  - Doesn't generalize to other inputs
- Welch's H1 is mechanically computable for any data, but its
  *interpretation* as a transfer function is only valid in the LTI
  regime
- **Coherence² is the test that distinguishes the two regimes**
- For our rig: γ² < 0.5 → operating well outside the LTI regime →
  the BLA we computed isn't a transfer function in any useful sense

**Plot**: conceptual diagram showing two BLA curves at different
amplitudes for the same nonlinear system, vs. a single H(f) for an
LTI system. Optionally include the analytic relationship
`G_BLA = E[Y·U*]/E[|U|²]` for the audience that wants math.

**Speaker notes**:
> "A foundational point. We were never going to get a clean Bode
> plot from broadband data on a nonlinear system, because the
> underlying object isn't a single transfer function. It's a
> family of best linear approximations, one per amplitude. The
> coherence² metric tells us which regime we're in — and we're
> firmly in the nonlinear regime."

---

## Slide 25 — Why the system generates even harmonics (back to physics)

**Goal**: connect the FFT finding to physical mechanisms. Brings
the talk back to the first-principles narrative from slide 13. The
plurality of mechanisms is exactly *why* a single comparison
(today's data alone) can't separate them — and *why* the
multi-configuration experimental design from slide 17 matters.

**Bullets**:
- **Symmetric input → only odd harmonics** is a mathematical property
  of the input
- **Asymmetric system response → all integer harmonics** in the output

**Plausible physical sources, all consistent with the rig** (in
roughly decreasing expected magnitude for the air-input config):

1. **Air-spring rectification**: stiffness `dP/dV ∝ γP/V` depends on
   operating pressure → softer at vacuum, stiffer at compression →
   directly generates even harmonics. Operating-point dependent.
   **The air-input configuration makes this the leading suspect.**
2. **Metamaterial structural asymmetry**: the porous structure
   deforms differently in expansion vs compression — the geometry
   isn't symmetric under inversion
3. **Hyperelastic stiffening**: stretch beyond the linear regime
   introduces higher-order strain energy terms (Mooney-Rivlin,
   neo-Hookean) → directly generates harmonics
4. **Quadratic flow resistance** (`Δp ∝ ρv²`): non-symmetric in
   velocity → directly generates harmonics in the output flow

**How the experimental matrix from slide 17 will separate these**:
- Repeat the same test with **water input instead of air**: removes
  source #1 entirely
- The *difference* in even-harmonic content between air-in and
  water-in is the air-spring contribution, quantitatively
- Sources #2–4 remain in both configurations; their amplitude
  dependence (from the staircase test on slide 28) separates them
  further

**Plot**: small annotated schematic showing each mechanism mapped
onto the actuator cross-section from slide 3 + the air column
between piston and actuator labeled as the "air spring."

**Speaker notes**:
> "The data confirms what we predicted from physics on slide 13.
> The air-input configuration adds an air-spring nonlinearity at
> the input, on top of the metamaterial nonlinearities. Today's
> single test can't separate these contributions — multiple
> mechanisms can each generate similar even-harmonic content. That
> motivates our planned multi-configuration sweep: by swapping
> input fluid and varying amplitude, we get experimental leverage
> on each nonlinearity independently."

---

# SECTION 5 — Adapting the Approach (Slides 26–27)

## Slide 26 — The describing-function approach

**Goal**: explain the *correct* methodology for a nonlinear system,
conceptually.

**Bullets**:
- For a nonlinear system, the Bode plot is **amplitude-dependent**
- A single broadband test conflates frequency-mixed effects across
  all amplitudes the input covers
- **Describing function** (textbook nonlinear-system analysis):
  - Drive at one frequency `f₀` with one amplitude `A`
  - Wait for steady state
  - Read out only the output's content **at the input frequency**
    `f₀` (ignore harmonics)
  - That gives one Bode point — `(magnitude, phase)` — at `(f₀, A)`
- Repeat across frequencies → one Bode plot at amplitude `A`
- Repeat at multiple amplitudes → a **family of Bode plots**, one
  per amplitude
- The amplitude-dependence is the nonlinear characterization

**Plot**: contrasting diagrams — (a) trapezoid → broadband spectrum
approach we used vs. (b) stepped sine → describing function approach
we should have used. Include side-by-side example FRFs (notional).

**Speaker notes**:
> "The textbook approach for nonlinear-system frequency-domain
> characterization. One frequency at a time, one amplitude at a
> time, read out only the input frequency from the output. The
> family of Bode plots versus amplitude is the proper
> characterization."

---

## Slide 27 — Why this fits our existing toolkit and rig

**Bullets**:
- Servo firmware **already supports** stepped sine via the `PS
  amp_mm freq_hz cycles` command — already used on the old vacuum
  rig
- Our toolkit's `frf_sine_dwell` function **already implements** the
  per-dwell single-tone DFT step (it's been there since v1)
- The GUI's **nonlinearity-sweep panel** already accumulates Bode
  results across multiple records and plots the comparison
- We just need to **swap the excitation**: trapezoidal → stepped
  sine, and run at multiple amplitudes
- **No new code needed**

**Plot**: flow diagram showing existing toolkit components highlighted
in green; the only new requirement is "collect stepped-sine data at
multiple amplitudes."

**Speaker notes**:
> "We're set up for this. None of the analysis code changes — only
> the test does. That's a deliberate design property of the
> toolkit: it handles broadband and stepped-sine identically, just
> through a dropdown."

---

# SECTION 6 — Path Forward and Conclusions (Slides 28–30)

## Slide 28 — Plan for the next data collection

**Bullets**:

**Two sweeps, two purposes**:

**1. Frequency × amplitude sweep** (in current config: air-in / water-flow-out)
- Stepped sine at frequencies: 0.2, 0.4, 0.7, 1.0, 1.5, 2.0, 3.0, 5.0,
  7.0, 10.0 Hz
- ~10–20 cycles per dwell for clean averaging
- Repeat the entire sweep at **three amplitudes**: 20, 40, 80 mm
- For each amplitude → one Bode plot (BLA at that amplitude) → fitted
  `(K, fₙ, ζ)`
- Headline plot: fitted parameters vs. amplitude → quantifies the
  amplitude-dependence and amplitude-axis nonlinearity

**2. Input-fluid sweep** (per slide 17 experimental matrix)
- Repeat the *same* sweep with hydraulic input instead of pneumatic
- Compare side-by-side: the difference in BLA between air-input and
  water-input is the **air-spring contribution**, isolated
- Headline plot: overlaid Bode plots (air-in vs water-in) at the same
  amplitude → quantifies the air-spring as a separate effect

**Concurrent rig improvements**:
- Connect inlet flow + inlet pressure sensors to enable
  per-stage characterization (intermediate signals available for
  cascaded model identification)
- Time-sync the input controller and output DAQ to eliminate the
  ~150 ms alignment uncertainty

**Plot**: mock-up of two eventual headline figures:
(a) three overlaid Bode curves at different amplitudes (single config),
(b) two overlaid Bode curves at different input fluids (air vs water).
**Mark both clearly as illustrative.**

**Speaker notes**:
> "Two sweeps. The first — amplitude staircase in the current
> config — quantifies how nonlinear the system is along the
> amplitude axis. From physics, we predict fₙ rises with
> amplitude (hyperelastic stiffening) and ζ rises with amplitude
> (quadratic flow). The second sweep — input fluid swap —
> separates the air-spring contribution from the rest. Together,
> these two experiments give us experimental leverage on each
> predicted nonlinearity independently."

---

## Slide 29 — Longer-term: gray-box physics modeling

**Bullets**:
- Beyond empirical describing function: write the differential
  equations from first principles
- **Hyperelastic metamaterial**: Mooney-Rivlin or neo-Hookean strain
  energy → nonlinear stiffness as function of strain
- **Hydraulic inertia**: water mass in inflow/outflow tubes
- **Output load compliance**: lumped capacitor model
- **Tubing flow**: linear + quadratic resistance (Reynolds-dependent)
- Result: state-space model with a handful of unknown parameters,
  fittable to data using the same MATLAB optimization machinery
- **Advantage**: predicts behavior at conditions we haven't tested
- **Disadvantage**: weeks of effort; out of scope for this project

**Plot**: notional state-space block diagram with named physical
parameters.

**Speaker notes**:
> "Empirical models tell you what the system did at conditions you
> tested. Physics models tell you what it will do at conditions
> you didn't. The natural next step beyond this project."

---

## Slide 30 — Conclusions

**What we did**:
- Designed and built a complete system-ID toolkit for the rig
- Ran a broadband identification at 80 mm stroke, 0.5 Hz
- Analyzed the result with a 6-stage pipeline + nonlinear modeling

**What we found**:
- **The rig is demonstrably nonlinear** at 80 mm stroke: ~15–25% THD
  measured; coherence² < 0.5 across the band
- **A linear LTI model is not the right description at this
  amplitude**: validation VAF is negative, even-harmonic content in
  the output that isn't in the input
- **Structured nonlinear models (Hammerstein-Wiener) also fail** on
  broadband data — the data doesn't constrain them

**What we learned about methodology**:
- Welch's H1 is mathematically correct but *interprets* as a transfer
  function only for LTI systems; for nonlinear systems it returns the
  amplitude-dependent BLA
- Coherence² is the diagnostic that catches this
- The right tool is **stepped sine at multiple amplitudes** — already
  supported by firmware and toolkit; data collection is the gating factor

**What's next**:
- Stepped-sine sweep at three amplitudes
- Full sensor suite (inlet pressure + flow) for per-subsystem
  characterization
- DAQ time synchronization
- Long-term: gray-box physics model

**Plot**: re-show the FFT spectrum from slide 20 as the closing image
— it's the clearest single piece of evidence.

**Speaker notes**:
> "We didn't end up with a fitted transfer function for the heart
> pump. What we ended up with is something more useful: quantitative
> evidence that the rig is nonlinear at this drive amplitude, a
> physical mechanism that explains the nonlinearity, and a clear
> plan for the right test to characterize it. That's a complete
> scientific arc — predict, test, falsify, revise the methodology."

---

## Slide 31 — Q&A / Acknowledgments

Standard.

---

# Anticipated questions & one-line answers

| Question | Answer |
|---|---|
| Why H1 estimator and not H2? | H1 is unbiased when noise is on the output, which is where sensor noise lives. H2 would be biased the other direction. |
| What does coherence² represent physically? | The fraction of output power at each frequency that's a linear function of the input. γ² ≈ 1 = linear; γ² < 0.5 = noise or nonlinear. |
| Why didn't you fit a higher-order linear model? | More parameters can't extract information that isn't in the data. The data lacks coherent linear structure to fit. |
| Why did the Hammerstein-Wiener model fail? | Broadband data doesn't constrain the structure — too many parameter combinations give similar training error. Optimizer collapsed to a degenerate solution. |
| What's the BLA conceptually? | The linear system that minimizes mean-squared prediction error against this specific input/amplitude. Useful but amplitude-dependent. |
| Why is the phase plot so noisy? | `unwrap` is sensitive when phase is uncertain. With low coherence, every phase sample is borderline noise; unwrap accumulates spurious 360° jumps. |
| How does stepped-sine help? | Each Bode point comes from one frequency, one amplitude — no harmonic mixing, no spectral leakage, clean phase. The amplitude-dependence quantifies the nonlinearity. |
| What gives you confidence in the toolkit? | The synthetic verifier (`verify_synthetic.m`) recovers a known 2nd-order plant within 5% on simulated data. Sanity check ran cleanly before any rig data. |
| Could the issue be timing misalignment, not nonlinearity? | Possibly contributes (~150 ms uncertainty). But misalignment alone wouldn't generate even harmonics in the output spectrum that aren't in the input. The harmonic content is the dominant evidence. |
| Why didn't air-spring nonlinearity matter? | Because we switched to a hydraulic input (slide 7). Water is incompressible, so there's no air spring at the input. The remaining nonlinearity is in the metamaterial structure and flow resistance. |
| What's the static gain of the system? | We didn't quote a value because the BLA's K parameter wasn't reliable at this amplitude. Stepped-sine data at low amplitude (where coherence² is highest) is the right way to extract it. |
| Why is THD 15–25% the threshold? | Below ~10% a single linear model captures most of the response (some applications accept up to 20%). 15–25% means the linear model is incomplete; you need either a nonlinear model or amplitude-stratified linear models. |
| What's next experimentally? | Stepped sine at three amplitudes (slide 28). Connect remaining sensors. Sync the DAQs. Then optionally a gray-box physics fit. |

---

# Visual / production notes

- All plots are saved to `<csv_folder>/results/` from the GUI runs
- Use the GUI's **"Edit plot titles..."** button to put each test
  description into the plot title (e.g., "80 mm @ 0.5 Hz, Test 3")
- Color convention across slides: **blue = input**, **orange = output**,
  **red dashed = linear LM fit**, **green = NLHW fit / sine dwell**,
  **black = measured/reference**
- For sections 4 and 5 (the diagnosis), favor *conceptual* diagrams
  over data plots — the audience needs to understand the *why*
  before they can appreciate the data
- Slide 20 (the FFT) and slide 30 (conclusions, re-showing the FFT)
  bracket the talk; it's the strongest single visual

---

# What you can build tonight before tomorrow's data

1. Open `sysid_gui.m` on your existing 80 mm trapezoid record. Re-run
   all 6 steps. Use **"Edit plot titles..."** to label each plot with
   the test description.
2. Build slides 11–25 from this outline — that's a complete narrative
   even without any new data, ending at "we identified the system is
   nonlinear and diagnosed why."
3. Slide 28's path-forward plot is illustrative for now; tomorrow's
   stepped-sine results, if collected, become a real comparison plot.
   Slide 30's conclusions get one bullet added: "and here's the
   quantitative amplitude-dependence."

You have a complete, defensible 31-slide talk **without** new data. The
amplitude-staircase result, when collected, slots in as an addendum and
strengthens the conclusion — but doesn't replace anything.
