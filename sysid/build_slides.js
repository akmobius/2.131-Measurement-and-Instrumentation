// build_slides.js — generates slides 11-31 for the system ID presentation
// Output: SystemID_Slides_11-31.pptx
// Upload to Google Slides: File > Import slides > select this file

const pptxgen = require("pptxgenjs");
const pres = new pptxgen();
pres.layout = "LAYOUT_16x9";  // 10" × 5.625"
pres.author = "Team Roche and Roll";
pres.title = "System Identification — slides 11–31";

// --- Style constants ---
const FONT_HEADER = "Calibri";
const FONT_BODY   = "Calibri";

const COL_BLACK   = "1F1F1F";
const COL_DKGRAY  = "404040";
const COL_GRAY    = "5F5F5F";
const COL_LTGRAY  = "888888";
const COL_BGGRAY  = "F2F2F2";
const COL_BLUE    = "1F4E79";   // accent for headings
const COL_RED     = "C00000";   // attention / problem markers
const COL_GREEN   = "548235";   // confirms / good
const COL_LIGHTBLUE = "DEEBF7"; // light fill
const COL_LIGHTRED  = "FBE4D5";
const COL_LIGHTGREEN= "E2EFDA";

// --- Layout helpers ---
function addHeader(slide, title, subtitle, slideNum) {
  slide.addText(title, {
    x: 0.4, y: 0.25, w: 9.2, h: 0.6,
    fontSize: 32, bold: true, color: COL_BLACK,
    fontFace: FONT_HEADER, margin: 0
  });
  if (subtitle) {
    slide.addText(subtitle, {
      x: 0.4, y: 0.83, w: 9.2, h: 0.35,
      fontSize: 15, italic: true, color: COL_GRAY,
      fontFace: FONT_BODY, margin: 0
    });
  }
  if (slideNum !== undefined) {
    slide.addText(String(slideNum), {
      x: 9.45, y: 5.3, w: 0.4, h: 0.25,
      fontSize: 10, color: COL_LTGRAY, align: "right",
      fontFace: FONT_BODY, margin: 0
    });
  }
}

function placeholderBox(slide, x, y, w, h, label, sublabel) {
  slide.addShape(pres.shapes.RECTANGLE, {
    x, y, w, h,
    fill: { color: COL_BGGRAY },
    line: { color: COL_LTGRAY, width: 1, dashType: "dash" }
  });
  const lines = [{
    text: label,
    options: { fontSize: 14, bold: true, color: COL_DKGRAY,
               breakLine: !!sublabel }
  }];
  if (sublabel) {
    lines.push({
      text: sublabel,
      options: { fontSize: 11, italic: true, color: COL_GRAY }
    });
  }
  slide.addText(lines, {
    x, y, w, h, align: "center", valign: "middle",
    fontFace: FONT_BODY, margin: 0
  });
}

function bullets(items, opts) {
  // items: each entry is either
  //   - "plain string"  → simple bulleted line
  //   - [part, part, ...]  → bullet line with multiple text runs (mixed bold/plain)
  //                        each part is either a string OR {text, options}
  opts = opts || {};
  const base = Object.assign(
    { fontSize: 14, color: COL_BLACK, fontFace: FONT_BODY, paraSpaceAfter: 6 },
    opts
  );
  const out = [];
  items.forEach((item, i) => {
    const isLastBullet = i === items.length - 1;
    if (typeof item === "string") {
      out.push({
        text: item,
        options: Object.assign({}, base, { bullet: true, breakLine: !isLastBullet })
      });
    } else if (Array.isArray(item)) {
      item.forEach((part, j) => {
        const isFirstRun = j === 0;
        const isLastRun = j === item.length - 1;
        const partText = typeof part === "string" ? part : part.text;
        const partOpts = typeof part === "string" ? {} : (part.options || {});
        out.push({
          text: partText,
          options: Object.assign({}, base, partOpts,
            isFirstRun ? { bullet: true } : { bullet: false },
            { breakLine: isLastRun && !isLastBullet })
        });
      });
    } else {
      // {text, options} → single bullet with formatting
      out.push({
        text: item.text,
        options: Object.assign({}, base, item.options || {},
          { bullet: true, breakLine: !isLastBullet })
      });
    }
  });
  return out;
}

// =============================================================
//  SLIDE 11 — Flow sensor info (mirrors slide 10 pressure specs)
// =============================================================
{
  const s = pres.addSlide();
  addHeader(s, "Flow Sensor Info", "Transonic T402 Perivascular Flow Module", 11);

  // Spec table on the left
  const tbl = [
    [
      { text: "Detail", options: { bold: true, fill: { color: COL_LIGHTBLUE }, color: COL_BLACK } },
      { text: "Specification", options: { bold: true, fill: { color: COL_LIGHTBLUE }, color: COL_BLACK } }
    ],
    ["Module", "Transonic T402 perivascular flow module"],
    ["Output", "±12 V analog, scaled 1/3 to ADC range"],
    ["ADC", "ADS1115 16-bit (separate from pressure ADC chain)"],
    ["Sensors used", "Outlet flow (water) — uncalibrated raw counts"],
    ["Sample rate", "320 sps (matched to pressure DAQ)"]
  ];
  s.addTable(tbl, {
    x: 0.4, y: 1.4, w: 5.5, colW: [1.6, 3.9],
    fontSize: 12, fontFace: FONT_BODY, color: COL_BLACK,
    border: { pt: 0.5, color: COL_LTGRAY }
  });

  // Right side: rationale
  s.addText("Why uncalibrated is fine for SysID:", {
    x: 6.1, y: 1.4, w: 3.5, h: 0.4,
    fontSize: 14, bold: true, color: COL_BLUE, fontFace: FONT_BODY
  });
  s.addText(bullets([
    "Calibration removes a DC offset and a scaling constant",
    "Neither affects the *shape* of the Bode plot",
    "Frequency content (the input to FRF analysis) is preserved exactly",
    "Absolute units only matter for static gain — addressed in future calibrated tests"
  ]), {
    x: 6.1, y: 1.85, w: 3.5, h: 3.2, fontFace: FONT_BODY
  });

  s.addNotes("Flow sensing is a Transonic T402 with a 16-bit ADC. We did not " +
    "calibrate the output to absolute units for this experiment — the raw counts " +
    "capture the time-domain shape and frequency content, which is everything " +
    "system identification needs. The DC offset and scale factor would just be " +
    "constants applied to the magnitude of the Bode plot.");
}

// =============================================================
//  SLIDE 12 — Goal of the system ID effort
// =============================================================
{
  const s = pres.addSlide();
  addHeader(s, "Goal of the System ID Effort",
    "What we're trying to extract from the rig", 12);

  s.addText("Build a quantitative model: piston input → mock-loop output", {
    x: 0.4, y: 1.3, w: 9.2, h: 0.4,
    fontSize: 16, bold: true, color: COL_BLUE, fontFace: FONT_BODY
  });

  // Two columns
  s.addText("Two model deliverables:", {
    x: 0.4, y: 1.85, w: 4.3, h: 0.35,
    fontSize: 14, bold: true, color: COL_BLACK, fontFace: FONT_BODY
  });
  s.addText(bullets([
    [{ text: "Non-parametric:", options: { bold: true } }, " Bode plot — magnitude & phase at every measurable frequency"],
    [{ text: "Parametric:", options: { bold: true } }, " H(s) with named parameters — gain K, natural freq ωn, damping ζ"]
  ]), { x: 0.4, y: 2.2, w: 4.3, h: 1.7, fontFace: FONT_BODY });

  s.addText("Beyond the model itself:", {
    x: 5.0, y: 1.85, w: 4.6, h: 0.35,
    fontSize: 14, bold: true, color: COL_BLACK, fontFace: FONT_BODY
  });
  s.addText(bullets([
    "Where the model is valid — what amplitudes, what frequency band",
    "How nonlinear the system is when it isn't exactly linear",
    [{ text: "Subsystem isolation:", options: { bold: true } }],
    "Test multiple I/O configurations (air-in vs water-in) → separate the contributions"
  ]), { x: 5.0, y: 2.2, w: 4.6, h: 2.5, fontFace: FONT_BODY });

  s.addNotes("Two deliverables — Bode plot and parametric model — plus a " +
    "characterization of where the model is valid. A unique advantage of our " +
    "setup: we can swap the input fluid between air and water. By comparing " +
    "system behavior under each configuration, we can identify which " +
    "nonlinearities live in which subsystem — air-side compliance vs " +
    "metamaterial deformation vs fluid-side dynamics.");
}

// =============================================================
//  SLIDE 13 — Physics predictions
// =============================================================
{
  const s = pres.addSlide();
  addHeader(s, "What the Physics Predicts",
    "Air-input / water-output configuration · before any data", 13);

  // Dynamic chain table
  const dynTbl = [
    [
      { text: "Element", options: { bold: true, fill: { color: COL_LIGHTBLUE }, color: COL_BLACK } },
      { text: "Dynamic role", options: { bold: true, fill: { color: COL_LIGHTBLUE }, color: COL_BLACK } },
      { text: "Freq band", options: { bold: true, fill: { color: COL_LIGHTBLUE }, color: COL_BLACK } }
    ],
    ["Piston (air)", "compressible input → pressure rise", "all"],
    ["Air column / actuator cavity", "gas spring (PV^γ compliance)", "low–mid"],
    ["Metamaterial structure", "nonlinear spring (hyperelastic)", "mid"],
    ["Water in ventricle + tubing", "hydraulic mass (M = ρL/A)", "low–mid"],
    ["Output flow tubing", "inertance + viscous loss", "mid–high"],
    ["Mock-loop output load", "compliance + flow resistance", "low"]
  ];
  s.addTable(dynTbl, {
    x: 0.4, y: 1.25, w: 5.6, colW: [1.7, 2.7, 1.2],
    fontSize: 11, fontFace: FONT_BODY, color: COL_BLACK,
    border: { pt: 0.5, color: COL_LTGRAY }
  });

  // Predicted features on the right
  s.addText("Predicted minimum order: 4", {
    x: 6.2, y: 1.25, w: 3.6, h: 0.3,
    fontSize: 13, bold: true, color: COL_BLUE, fontFace: FONT_BODY
  });
  s.addText("Predicted resonances:", {
    x: 6.2, y: 1.55, w: 3.6, h: 0.3,
    fontSize: 12, bold: true, color: COL_BLACK, fontFace: FONT_BODY
  });
  s.addText(bullets([
    "Low mode (water mass + air spring + load): 0.3–1 Hz",
    "High mode (tubing inertance + cavity): 3–15 Hz"
  ], { fontSize: 11 }), { x: 6.2, y: 1.85, w: 3.6, h: 0.9, fontFace: FONT_BODY });

  s.addText("Predicted nonlinearities (4):", {
    x: 6.2, y: 2.85, w: 3.6, h: 0.3,
    fontSize: 12, bold: true, color: COL_RED, fontFace: FONT_BODY
  });
  s.addText([
    { text: "1. Air-spring rectification → even harmonics", options: { fontSize: 11, color: COL_BLACK, breakLine: true, paraSpaceAfter: 3 } },
    { text: "2. Hyperelastic stiffening → fn rises with amp", options: { fontSize: 11, color: COL_BLACK, breakLine: true, paraSpaceAfter: 3 } },
    { text: "3. Asymmetric metamaterial deformation → even harmonics", options: { fontSize: 11, color: COL_BLACK, breakLine: true, paraSpaceAfter: 3 } },
    { text: "4. Quadratic flow resistance → ζ rises with amp", options: { fontSize: 11, color: COL_BLACK } }
  ], { x: 6.2, y: 3.15, w: 3.6, h: 1.7, fontFace: FONT_BODY, margin: 0 });

  // Coherence² test note at bottom
  s.addShape(pres.shapes.RECTANGLE, {
    x: 0.4, y: 4.85, w: 9.2, h: 0.45,
    fill: { color: COL_LIGHTGREEN }, line: { color: COL_GREEN, width: 1 }
  });
  s.addText("Test for linearity: γ² > 0.85 if linear · substantially lower means we're already nonlinear", {
    x: 0.4, y: 4.85, w: 9.2, h: 0.45,
    fontSize: 12, italic: true, color: COL_GREEN, align: "center", valign: "middle",
    fontFace: FONT_BODY, margin: 0
  });

  s.addNotes("Before we ID, we predict. With air input the piston-to-actuator " +
    "coupling goes through an air spring, which adds compliance and " +
    "nonlinearity on the input side. We expect at least 4th-order behavior. " +
    "Four nonlinearities we'd predict: air-spring rectification, hyperelastic " +
    "stiffening, asymmetric metamaterial deformation, and quadratic flow " +
    "resistance. Each has a distinct experimental signature we can look for. " +
    "By later swapping the input to hydraulic, we can quantitatively separate " +
    "the air-spring contribution from the rest.");
}

// =============================================================
//  SLIDE 14 — Method choice
// =============================================================
{
  const s = pres.addSlide();
  addHeader(s, "Choosing the System ID Method",
    "Why broadband + Welch's H1 estimator first", 14);

  // 2x2 matrix
  const cellW = 1.9, cellH = 1.0, gridX = 0.5, gridY = 1.4;
  // Headers
  s.addText("Broadband", {
    x: gridX + 1.0, y: gridY, w: cellW, h: 0.4, align: "center",
    fontSize: 12, bold: true, color: COL_BLACK, fontFace: FONT_BODY, margin: 0
  });
  s.addText("Single-frequency", {
    x: gridX + 1.0 + cellW, y: gridY, w: cellW, h: 0.4, align: "center",
    fontSize: 12, bold: true, color: COL_BLACK, fontFace: FONT_BODY, margin: 0
  });
  s.addText("Non-parametric", {
    x: gridX, y: gridY + 0.5, w: 1.0, h: cellH, align: "right", valign: "middle",
    fontSize: 12, bold: true, color: COL_BLACK, fontFace: FONT_BODY, margin: 0
  });
  s.addText("Parametric", {
    x: gridX, y: gridY + 0.5 + cellH, w: 1.0, h: cellH, align: "right", valign: "middle",
    fontSize: 12, bold: true, color: COL_BLACK, fontFace: FONT_BODY, margin: 0
  });
  // Cells
  s.addShape(pres.shapes.RECTANGLE, {
    x: gridX + 1.0, y: gridY + 0.5, w: cellW, h: cellH,
    fill: { color: COL_LIGHTGREEN }, line: { color: COL_GREEN, width: 2 }
  });
  s.addText("Welch H1\n(our choice)", {
    x: gridX + 1.0, y: gridY + 0.5, w: cellW, h: cellH, align: "center", valign: "middle",
    fontSize: 11, bold: true, color: COL_GREEN, fontFace: FONT_BODY, margin: 0
  });
  s.addShape(pres.shapes.RECTANGLE, {
    x: gridX + 1.0 + cellW, y: gridY + 0.5, w: cellW, h: cellH,
    fill: { color: COL_BGGRAY }, line: { color: COL_LTGRAY, width: 1 }
  });
  s.addText("Stepped sine\nDFT per dwell", {
    x: gridX + 1.0 + cellW, y: gridY + 0.5, w: cellW, h: cellH, align: "center", valign: "middle",
    fontSize: 11, color: COL_DKGRAY, fontFace: FONT_BODY, margin: 0
  });
  s.addShape(pres.shapes.RECTANGLE, {
    x: gridX + 1.0, y: gridY + 0.5 + cellH, w: cellW, h: cellH,
    fill: { color: COL_BGGRAY }, line: { color: COL_LTGRAY, width: 1 }
  });
  s.addText("tfest, n4sid\n(LM fit on FRF)", {
    x: gridX + 1.0, y: gridY + 0.5 + cellH, w: cellW, h: cellH, align: "center", valign: "middle",
    fontSize: 11, color: COL_DKGRAY, fontFace: FONT_BODY, margin: 0
  });
  s.addShape(pres.shapes.RECTANGLE, {
    x: gridX + 1.0 + cellW, y: gridY + 0.5 + cellH, w: cellW, h: cellH,
    fill: { color: COL_BGGRAY }, line: { color: COL_LTGRAY, width: 1 }
  });
  s.addText("Sine fit + tfest\n(amplitude/phase)", {
    x: gridX + 1.0 + cellW, y: gridY + 0.5 + cellH, w: cellW, h: cellH, align: "center", valign: "middle",
    fontSize: 11, color: COL_DKGRAY, fontFace: FONT_BODY, margin: 0
  });

  // Right side rationale
  s.addText("Why we chose this quadrant:", {
    x: 5.6, y: 1.4, w: 4.0, h: 0.35,
    fontSize: 13, bold: true, color: COL_BLUE, fontFace: FONT_BODY
  });
  s.addText(bullets([
    [{ text: "Efficient: ", options: { bold: true } }, "single record → Bode at every freq the input excites"],
    [{ text: "Industry standard: ", options: { bold: true } }, "H1 unbiased under output-side noise"],
    [{ text: "Built-in diagnostic: ", options: { bold: true } }, "coherence² flags trustworthy bands"],
    [{ text: "No firmware change: ", options: { bold: true } }, "trapezoidal command already supported"]
  ], { fontSize: 12 }), { x: 5.6, y: 1.75, w: 4.0, h: 2.5, fontFace: FONT_BODY });

  // Compromise note
  s.addShape(pres.shapes.RECTANGLE, {
    x: 0.4, y: 4.7, w: 9.2, h: 0.6,
    fill: { color: COL_LIGHTRED }, line: { color: COL_RED, width: 1 }
  });
  s.addText([
    { text: "Compromise we accepted: ", options: { bold: true, fontSize: 13, color: COL_RED } },
    { text: "valid only if the system is approximately linear — explicitly to be verified from data via coherence²", options: { fontSize: 13, color: COL_BLACK } }
  ], { x: 0.4, y: 4.7, w: 9.2, h: 0.6, align: "center", valign: "middle",
       fontFace: FONT_BODY, margin: 0 });

  s.addNotes("Four quadrants in the SysID design space. We picked the most " +
    "efficient one — broadband non-parametric — knowing that its validity rests " +
    "on the linearity assumption. We made that choice deliberately, with the " +
    "explicit understanding that we'd verify the assumption from the data itself.");
}

// =============================================================
//  SLIDE 15 — Assumptions and limitations
// =============================================================
{
  const s = pres.addSlide();
  addHeader(s, "Assumptions & Limitations", "Explicit list, with how each is tested", 15);

  // Two columns: assumptions / limitations
  s.addText("H1 estimator assumes:", {
    x: 0.4, y: 1.2, w: 4.6, h: 0.35,
    fontSize: 14, bold: true, color: COL_GREEN, fontFace: FONT_BODY
  });
  const asmTbl = [
    [
      { text: "Assumption", options: { bold: true, fill: { color: COL_LIGHTGREEN } } },
      { text: "How tested", options: { bold: true, fill: { color: COL_LIGHTGREEN } } }
    ],
    ["Linearity", "coherence² at active freqs"],
    ["Time invariance", "consistency across runs"],
    ["Causality", "phase ≤ 0°"],
    ["Stationarity (input)", "trapezoid satisfies by construction"],
    ["Output-side noise", "DAQ noise model"],
    ["Sufficient excitation", "input PSD vs frequency"]
  ];
  s.addTable(asmTbl, {
    x: 0.4, y: 1.55, w: 4.6, colW: [1.9, 2.7],
    fontSize: 11, fontFace: FONT_BODY, color: COL_BLACK,
    border: { pt: 0.5, color: COL_LTGRAY }
  });

  s.addText("Limitations going in:", {
    x: 5.2, y: 1.2, w: 4.4, h: 0.35,
    fontSize: 14, bold: true, color: COL_RED, fontFace: FONT_BODY
  });
  s.addText(bullets([
    [{ text: "BLA is amplitude-dependent: ", options: { bold: true, color: COL_RED } }, "if nonlinear, single test conflates amplitudes"],
    [{ text: "Welch trade-off: ", options: { bold: true, color: COL_RED } }, "freq resolution vs. variance"],
    [{ text: "DAQ timing: ", options: { bold: true, color: COL_RED } }, "input/output ADCs not synced (~150 ms)"],
    [{ text: "Sensors: ", options: { bold: true, color: COL_RED } }, "pressure not connected this session"]
  ], { fontSize: 11 }), { x: 5.2, y: 1.55, w: 4.4, h: 3.5, fontFace: FONT_BODY });

  s.addNotes("Six assumptions, four limitations. The most important assumption " +
    "is linearity, and the most important diagnostic — coherence² — directly " +
    "tests it. Two limitations were unavoidable in this session: DAQ sync and " +
    "pressure sensors.");
}

// =============================================================
//  SLIDE 16 — Test design (waveform calculator)
// =============================================================
{
  const s = pres.addSlide();
  addHeader(s, "Test Design: Waveform Calculator", "Predicting the spectrum before running", 16);

  placeholderBox(s, 0.4, 1.25, 5.5, 4.0,
    "[Screenshot: pump_waveform_calc.m]",
    "calculator GUI with target params + position waveform + predicted FFT comb");

  s.addText("Test parameters (first run):", {
    x: 6.1, y: 1.25, w: 3.5, h: 0.4,
    fontSize: 14, bold: true, color: COL_BLUE, fontFace: FONT_BODY
  });
  s.addText(bullets([
    [{ text: "f₀ = 0.5 Hz ", options: { bold: true } }, "— cycle period 2 s"],
    [{ text: "80 mm peak-to-peak ", options: { bold: true } }, "(max safe travel)"],
    [{ text: "10 cycles ", options: { bold: true } }, "(~20 s usable data)"],
    "Sharp accel/decel → richer high-f harmonics"
  ], { fontSize: 12 }), { x: 6.1, y: 1.7, w: 3.5, h: 2.0, fontFace: FONT_BODY });

  s.addText("Predicted harmonic comb:", {
    x: 6.1, y: 3.85, w: 3.5, h: 0.35,
    fontSize: 13, bold: true, color: COL_BLACK, fontFace: FONT_BODY
  });
  s.addText("0.5, 1.5, 2.5, 3.5, 4.5 Hz", {
    x: 6.1, y: 4.2, w: 3.5, h: 0.3,
    fontSize: 14, bold: true, color: COL_GREEN,
    fontFace: "Consolas"
  });
  s.addText("(odd-harmonic comb, falling 1/f²)", {
    x: 6.1, y: 4.5, w: 3.5, h: 0.3,
    fontSize: 11, italic: true, color: COL_GRAY, fontFace: FONT_BODY
  });

  s.addNotes("The calculator forces us to commit on paper to what we expect to " +
    "see, before running. With f₀ = 0.5 Hz and 80 mm stroke, the trapezoid puts " +
    "five clean odd-harmonic spikes in the 0.5–5 Hz band — exactly the range " +
    "our predicted dynamics live in.");
}

// =============================================================
//  SLIDE 17 — Experimental matrix (I/O configurations)
// =============================================================
{
  const s = pres.addSlide();
  addHeader(s, "The Experimental Matrix",
    "Multiple I/O configurations isolate which subsystem each nonlinearity lives in", 17);

  const matTbl = [
    [
      { text: "Input", options: { bold: true, fill: { color: COL_LIGHTBLUE }, color: COL_BLACK } },
      { text: "Output", options: { bold: true, fill: { color: COL_LIGHTBLUE }, color: COL_BLACK } },
      { text: "What it isolates", options: { bold: true, fill: { color: COL_LIGHTBLUE }, color: COL_BLACK } },
      { text: "Status", options: { bold: true, fill: { color: COL_LIGHTBLUE }, color: COL_BLACK } }
    ],
    [
      { text: "Air", options: { bold: true, color: COL_GREEN } },
      { text: "Water flow", options: { bold: true, color: COL_GREEN } },
      { text: "Full chain: air spring + metamaterial + fluid loop", options: { color: COL_GREEN } },
      { text: "today's test", options: { bold: true, color: COL_GREEN } }
    ],
    ["Air", "Water pressure", "Full chain w/ pressure-side dynamics", "future"],
    ["Water", "Water flow", "Metamaterial + fluid loop without air spring", "future"],
    ["Water", "Water pressure", "Metamaterial + fluid loop, pressure response", "future"]
  ];
  s.addTable(matTbl, {
    x: 0.4, y: 1.3, w: 9.2, colW: [1.0, 1.6, 5.0, 1.6],
    fontSize: 12, fontFace: FONT_BODY, color: COL_BLACK,
    border: { pt: 0.5, color: COL_LTGRAY },
    rowH: 0.45
  });

  // Why this matters scientifically
  s.addShape(pres.shapes.RECTANGLE, {
    x: 0.4, y: 4.0, w: 9.2, h: 1.25,
    fill: { color: COL_LIGHTBLUE }, line: { color: COL_BLUE, width: 1 }
  });
  s.addText([
    { text: "Why this matters: ", options: { bold: true, fontSize: 13, color: COL_BLUE, breakLine: true } },
    { text: "Air-input vs water-input at the same output isolates the air-spring contribution — a direct experimental separation of one nonlinearity from the rest.", options: { fontSize: 12, color: COL_BLACK, breakLine: true, paraSpaceAfter: 4 } },
    { text: "Flow-output vs pressure-output under the same input reveals the impedance characteristics of the output fluid loop.", options: { fontSize: 12, color: COL_BLACK } }
  ], { x: 0.6, y: 4.05, w: 8.9, h: 1.15, valign: "top", fontFace: FONT_BODY, margin: 0 });

  s.addNotes("We have a deliberate experimental design here, not just one test. " +
    "The rig is configurable in two ways — input fluid and output side — giving " +
    "us at least four distinct test configurations. Today's data is air-in / " +
    "water-flow-out, which captures the whole chain but doesn't separate where " +
    "the nonlinearities live. Once we have a clean characterization in this " +
    "config, the plan is to swap the input to water and rerun: the difference " +
    "between the two configurations is exactly the air-spring contribution. " +
    "That's a quantitatively meaningful subsystem isolation.");
}

// =============================================================
//  SLIDE 18 — Analysis pipeline overview
// =============================================================
{
  const s = pres.addSlide();
  addHeader(s, "Analysis Pipeline", "Six stages, each one button in the GUI", 18);

  const stages = [
    ["1", "Raw data", "confirm both signals look reasonable"],
    ["2", "Cleaned data", "resample · detrend · LPF · crop+align"],
    ["3", "Spectrum (FFT)", "input PSD vs output PSD"],
    ["4", "FRF + parametric fit", "Welch H1 + LM fit of H(s)"],
    ["5", "Validation", "predict held-out half · VAF + AIC"],
    ["6", "Nonlinear fit", "Hammerstein-Wiener fall-back"]
  ];
  const sx = 0.4, sy = 1.35;
  stages.forEach(([n, title, desc], i) => {
    const y = sy + i * 0.6;
    // Number circle
    s.addShape(pres.shapes.OVAL, {
      x: sx, y, w: 0.45, h: 0.45,
      fill: { color: COL_BLUE }, line: { color: COL_BLUE, width: 0 }
    });
    s.addText(n, {
      x: sx, y, w: 0.45, h: 0.45, align: "center", valign: "middle",
      fontSize: 16, bold: true, color: "FFFFFF", fontFace: FONT_BODY, margin: 0
    });
    // Title and desc
    s.addText(title, {
      x: sx + 0.6, y, w: 2.4, h: 0.45,
      fontSize: 14, bold: true, color: COL_BLACK, valign: "middle",
      fontFace: FONT_BODY, margin: 0
    });
    s.addText(desc, {
      x: sx + 3.0, y, w: 2.5, h: 0.45,
      fontSize: 11, italic: true, color: COL_GRAY, valign: "middle",
      fontFace: FONT_BODY, margin: 0
    });
  });

  // Right side: GUI screenshot placeholder
  placeholderBox(s, 6.0, 1.35, 3.6, 3.6,
    "[Screenshot: sysid_gui.m]", "showing the 6 stage buttons");

  s.addNotes("Six stages, one button each in the GUI. Each one has a specific " +
    "question it answers, and each saves a presentation-quality PNG to disk. " +
    "Skipping any stage means losing a diagnostic.");
}

// =============================================================
//  SLIDE 19 — Stage 1 + 2 results
// =============================================================
{
  const s = pres.addSlide();
  addHeader(s, "Stages 1 + 2: Data Quality is Fine",
    "Raw data → preprocessed (mean removed, LPF, crop/aligned)", 19);

  placeholderBox(s, 0.4, 1.2, 4.5, 3.8,
    "[step1_raw.png]", "raw input + raw output time series");
  placeholderBox(s, 5.1, 1.2, 4.5, 3.8,
    "[step2_preprocess.png]", "cleaned input + cleaned output");

  s.addText([
    { text: "Output ±~4 LPM at the input fundamental (raw counts). ", options: { fontSize: 12, color: COL_BLACK } },
    { text: "Cycle-by-cycle consistency, no saturation, no dropouts.", options: { fontSize: 12, color: COL_BLACK } }
  ], { x: 0.4, y: 5.05, w: 9.2, h: 0.3,
      align: "center", fontFace: FONT_BODY, margin: 0 });

  s.addNotes("Data is good — no sensor saturation, no dropouts, output amplitude " +
    "consistent across cycles. The fine structure inside each output cycle is the " +
    "first hint that the relationship isn't simply linear, but we'll quantify that.");
}

// =============================================================
//  SLIDE 20 — Stage 3: spectrum (HEADLINE)
// =============================================================
{
  const s = pres.addSlide();
  addHeader(s, "★ Stage 3: The Spectrum Tells the Story",
    "Input has odd harmonics · Output has ALL integer multiples (the smoking gun)", 20);

  placeholderBox(s, 0.4, 1.15, 6.8, 4.0,
    "[step3_spectrum.png]",
    "log-log: input |U(f)| (top, blue) + output |Y(f)| (bottom, orange)\nCircle/annotate the even-harmonic peaks at 1, 2, 3 Hz");

  // Findings panel
  s.addShape(pres.shapes.RECTANGLE, {
    x: 7.4, y: 1.15, w: 2.2, h: 4.0,
    fill: { color: COL_LIGHTRED }, line: { color: COL_RED, width: 1.5 }
  });
  s.addText("Findings", {
    x: 7.4, y: 1.2, w: 2.2, h: 0.4,
    fontSize: 14, bold: true, color: COL_RED, align: "center",
    fontFace: FONT_BODY, margin: 0
  });
  s.addText([
    { text: "Input: ", options: { bold: true, fontSize: 11, color: COL_BLACK, breakLine: true } },
    { text: "  odd harmonics only: 0.5, 1.5, 2.5 Hz...", options: { fontSize: 10, color: COL_BLACK, breakLine: true, paraSpaceAfter: 6 } },
    { text: "Output: ", options: { bold: true, fontSize: 11, color: COL_BLACK, breakLine: true } },
    { text: "  ALL integer multiples (1, 2, 3 Hz too)", options: { fontSize: 10, color: COL_BLACK, breakLine: true, paraSpaceAfter: 6 } },
    { text: "THD: ", options: { bold: true, fontSize: 11, color: COL_BLACK, breakLine: true } },
    { text: "  ~15-25% of output power at frequencies the input does NOT excite", options: { fontSize: 10, color: COL_BLACK, breakLine: true, paraSpaceAfter: 8 } },
    { text: "Confirms slide 13 prediction: ", options: { bold: true, fontSize: 11, color: COL_GREEN, breakLine: true } },
    { text: "  even harmonics = signature of asymmetric / air-spring response", options: { fontSize: 10, italic: true, color: COL_GREEN } }
  ], { x: 7.5, y: 1.55, w: 2.0, h: 3.55, valign: "top", fontFace: FONT_BODY, margin: 0 });

  s.addNotes("This is the single most important plot in the talk. The input has " +
    "only odd harmonics — that's a property of the symmetric trapezoid. A linear " +
    "system would respond ONLY at those frequencies. Our output has peaks at " +
    "every integer multiple of 0.5 Hz — at 1 Hz, 2 Hz, 3 Hz — at frequencies the " +
    "input never contained. The system is generating those harmonics. That's the " +
    "definition of nonlinearity, demonstrated quantitatively, and it confirms " +
    "what we predicted from physics on slide 13.");
}

// =============================================================
//  SLIDE 21 — Stage 4: Bode plot
// =============================================================
{
  const s = pres.addSlide();
  addHeader(s, "Stage 4: The Bode Plot Reflects the Same Problem",
    "Welch H1 + LM fit · low coherence² is the diagnostic", 21);

  placeholderBox(s, 0.4, 1.2, 5.5, 3.9,
    "[step4_fit.png]",
    "Bode magnitude + phase + coherence²\nLM fit overlaid as red dashed");

  s.addText("What we see:", {
    x: 6.1, y: 1.2, w: 3.5, h: 0.35,
    fontSize: 14, bold: true, color: COL_RED, fontFace: FONT_BODY
  });
  s.addText(bullets([
    "Magnitude noisy, no clear roll-off",
    "Phase wraps unpredictably (artifact)",
    [{ text: "γ² < 0.5 across nearly the entire band", options: { bold: true, color: COL_RED } }],
    "One coherent peak at ~3 Hz only",
    "4th-order LM fit doesn't track the data"
  ], { fontSize: 12 }), { x: 6.1, y: 1.55, w: 3.5, h: 2.6, fontFace: FONT_BODY });

  s.addShape(pres.shapes.RECTANGLE, {
    x: 6.1, y: 4.2, w: 3.5, h: 0.95,
    fill: { color: COL_LIGHTRED }, line: { color: COL_RED, width: 1 }
  });
  s.addText([
    { text: "Not a code bug. ", options: { bold: true, fontSize: 11, color: COL_RED, breakLine: true } },
    { text: "Welch + LM are mathematically correct — we're applying them to data that violates the linearity assumption.", options: { fontSize: 11, italic: true, color: COL_BLACK } }
  ], { x: 6.2, y: 4.25, w: 3.3, h: 0.85, valign: "top", fontFace: FONT_BODY, margin: 0 });

  s.addNotes("Coherence² below 0.5 means less than half of the output's energy at " +
    "each frequency is linearly related to the input. The other half is the " +
    "harmonic distortion we just saw on slide 20. The linear fit can't track " +
    "because the data doesn't actually have a single linear response to fit to.");
}

// =============================================================
//  SLIDE 22 — Stage 5: validation
// =============================================================
{
  const s = pres.addSlide();
  addHeader(s, "Stage 5: Validation Confirms It",
    "Linear model can't predict the held-out data", 22);

  placeholderBox(s, 0.4, 1.2, 6.0, 3.9,
    "[step5_validation.png]",
    "measured (dots) + linear prediction (dashed)\n+ residual underneath");

  // Big stat callout for VAF
  s.addText("VAF on validation:", {
    x: 6.7, y: 1.4, w: 3.0, h: 0.3,
    fontSize: 12, color: COL_GRAY, align: "center", fontFace: FONT_BODY, margin: 0
  });
  s.addText("≈ −50%", {
    x: 6.7, y: 1.7, w: 3.0, h: 0.9,
    fontSize: 56, bold: true, color: COL_RED, align: "center", valign: "middle",
    fontFace: FONT_BODY, margin: 0
  });
  s.addText("worse than predicting the mean", {
    x: 6.7, y: 2.65, w: 3.0, h: 0.4,
    fontSize: 12, italic: true, color: COL_RED, align: "center",
    fontFace: FONT_BODY, margin: 0
  });

  s.addText("Consistent with γ² < 0.5", {
    x: 6.7, y: 3.4, w: 3.0, h: 0.35,
    fontSize: 13, bold: true, color: COL_BLACK, align: "center", fontFace: FONT_BODY
  });
  s.addText([
    { text: "Sensitivity sweep: ", options: { bold: true, fontSize: 11, color: COL_BLACK, breakLine: true } },
    { text: "parameters not uniquely identifiable", options: { fontSize: 11, italic: true, color: COL_GRAY, breakLine: true, paraSpaceAfter: 8 } },
    { text: "The 'best linear approximation' exists but doesn't generalize.", options: { fontSize: 11, color: COL_BLACK } }
  ], { x: 6.7, y: 3.8, w: 3.0, h: 1.4, fontFace: FONT_BODY, valign: "top" });

  s.addNotes("Validation VAF is negative — the model is worse than just " +
    "predicting the mean. The numbers are consistent with what we'd expect from " +
    "coherence² < 0.5: there's no linear model that fits.");
}

// =============================================================
//  SLIDE 23 — Stage 6: NLHW didn't help
// =============================================================
{
  const s = pres.addSlide();
  addHeader(s, "Stage 6: Structured Nonlinear Modeling Didn't Fix It Either",
    "Hammerstein-Wiener fit also fails — and tells us why", 23);

  placeholderBox(s, 0.4, 1.2, 5.5, 3.9,
    "[step6_nlhw.png]",
    "validation: NLHW prediction diverges (green)\nlinear (red) better but still wrong");

  s.addText("Hammerstein-Wiener:", {
    x: 6.1, y: 1.2, w: 3.5, h: 0.35,
    fontSize: 14, bold: true, color: COL_RED, fontFace: FONT_BODY
  });
  s.addText("f(u) → LTI → g(z)", {
    x: 6.1, y: 1.55, w: 3.5, h: 0.3,
    fontSize: 12, italic: true, color: COL_GRAY, fontFace: "Consolas", margin: 0
  });
  s.addText(bullets([
    "VAF: -10000% — model unstable, prediction diverged",
    "Optimizer collapsed f(u) ≈ 0 (degenerate local min)",
    "Linear block ended with unstable poles",
    [{ text: "Why: ", options: { bold: true } }, "broadband data doesn't constrain a structured nonlinear model"]
  ], { fontSize: 11 }), { x: 6.1, y: 1.95, w: 3.5, h: 2.2, fontFace: FONT_BODY });

  s.addShape(pres.shapes.RECTANGLE, {
    x: 6.1, y: 4.2, w: 3.5, h: 0.95,
    fill: { color: COL_LIGHTBLUE }, line: { color: COL_BLUE, width: 1 }
  });
  s.addText([
    { text: "Lesson: ", options: { bold: true, fontSize: 11, color: COL_BLUE, breakLine: true } },
    { text: "Model complexity must match the information content of the data. Throwing more model at the problem made it worse.", options: { fontSize: 11, italic: true, color: COL_BLACK } }
  ], { x: 6.2, y: 4.25, w: 3.3, h: 0.85, valign: "top", fontFace: FONT_BODY, margin: 0 });

  s.addNotes("We tried a structured nonlinear model — Hammerstein-Wiener, " +
    "standard for control identification — and it failed worse than the linear " +
    "model. The reason: broadband data simply doesn't distinguish linear from " +
    "nonlinear contributions cleanly. With a more flexible model and the same " +
    "data, the optimizer just finds degenerate solutions. Model complexity has " +
    "to match the information content in the data.");
}

// =============================================================
//  SLIDE 24 — BLA vs transfer function
// =============================================================
{
  const s = pres.addSlide();
  addHeader(s, "Diagnosis: BLA vs Transfer Function",
    "Why Welch's H1 gave us unreliable results", 24);

  // Two-column layout: LTI vs nonlinear
  s.addShape(pres.shapes.RECTANGLE, {
    x: 0.4, y: 1.25, w: 4.5, h: 3.9,
    fill: { color: COL_LIGHTGREEN }, line: { color: COL_GREEN, width: 1.5 }
  });
  s.addText("LTI System", {
    x: 0.4, y: 1.3, w: 4.5, h: 0.4,
    fontSize: 16, bold: true, color: COL_GREEN, align: "center",
    fontFace: FONT_BODY, margin: 0
  });
  s.addText("Pyu/Puu = H(f)", {
    x: 0.4, y: 1.7, w: 4.5, h: 0.4,
    fontSize: 18, bold: true, color: COL_BLACK, align: "center",
    fontFace: "Consolas", margin: 0
  });
  s.addText(bullets([
    "Fixed property of the system",
    "Same H(f) regardless of amplitude",
    "Same H(f) regardless of input shape",
    "Generalizes to other inputs",
    "γ² ≈ 1 at frequencies of interest"
  ], { fontSize: 12, color: COL_BLACK }), { x: 0.7, y: 2.2, w: 4.0, h: 2.9, fontFace: FONT_BODY });

  s.addShape(pres.shapes.RECTANGLE, {
    x: 5.1, y: 1.25, w: 4.5, h: 3.9,
    fill: { color: COL_LIGHTRED }, line: { color: COL_RED, width: 1.5 }
  });
  s.addText("Nonlinear System (our case)", {
    x: 5.1, y: 1.3, w: 4.5, h: 0.4,
    fontSize: 16, bold: true, color: COL_RED, align: "center",
    fontFace: FONT_BODY, margin: 0
  });
  s.addText("Pyu/Puu = G_BLA(f)", {
    x: 5.1, y: 1.7, w: 4.5, h: 0.4,
    fontSize: 18, bold: true, color: COL_BLACK, align: "center",
    fontFace: "Consolas", margin: 0
  });
  s.addText(bullets([
    [{ text: "Best Linear Approximation", options: { bold: true } }],
    "Depends on input amplitude",
    "Depends on input spectrum",
    "Doesn't generalize to other inputs",
    "γ² < 1 — the diagnostic of nonlinearity"
  ], { fontSize: 12, color: COL_BLACK }), { x: 5.4, y: 2.2, w: 4.0, h: 2.9, fontFace: FONT_BODY });

  s.addText([
    { text: "Coherence² is the test that distinguishes the two regimes — and ours is firmly nonlinear.",
      options: { fontSize: 13, italic: true, color: COL_BLACK } }
  ], { x: 0.4, y: 5.0, w: 9.2, h: 0.3,
      align: "center", fontFace: FONT_BODY, margin: 0 });

  s.addNotes("A foundational point. We were never going to get a clean Bode plot " +
    "from broadband data on a nonlinear system, because the underlying object " +
    "isn't a single transfer function. It's a family of best linear " +
    "approximations, one per amplitude. The coherence² metric tells us which " +
    "regime we're in — and we're firmly in the nonlinear regime.");
}

// =============================================================
//  SLIDE 25 — Why even harmonics (back to physics)
// =============================================================
{
  const s = pres.addSlide();
  addHeader(s, "Why the System Generates Even Harmonics",
    "Four mechanisms — and why we need multiple test configurations to separate them", 25);

  s.addText("Four candidate mechanisms (decreasing expected magnitude):", {
    x: 0.4, y: 1.25, w: 9.2, h: 0.4,
    fontSize: 14, bold: true, color: COL_BLUE, fontFace: FONT_BODY
  });

  const mechs = [
    ["1", "Air-spring rectification", "PV^γ → softer at vacuum, stiffer at compression. Operating-point dependent.", COL_RED],
    ["2", "Metamaterial structural asymmetry", "porous geometry deforms differently in expansion vs compression", COL_DKGRAY],
    ["3", "Hyperelastic stiffening", "higher-order strain energy terms (Mooney-Rivlin / neo-Hookean)", COL_DKGRAY],
    ["4", "Quadratic flow resistance", "Δp ∝ ρv² → non-symmetric in velocity", COL_DKGRAY]
  ];
  mechs.forEach(([n, title, desc, color], i) => {
    const y = 1.75 + i * 0.55;
    s.addShape(pres.shapes.OVAL, {
      x: 0.5, y: y + 0.05, w: 0.4, h: 0.4,
      fill: { color: i === 0 ? COL_RED : COL_LTGRAY }
    });
    s.addText(n, {
      x: 0.5, y: y + 0.05, w: 0.4, h: 0.4, align: "center", valign: "middle",
      fontSize: 14, bold: true, color: "FFFFFF", fontFace: FONT_BODY, margin: 0
    });
    s.addText([
      { text: title, options: { bold: true, fontSize: 13, color: color, breakLine: true } },
      { text: desc, options: { fontSize: 11, italic: true, color: COL_GRAY } }
    ], { x: 1.05, y, w: 8.4, h: 0.5, valign: "top", fontFace: FONT_BODY, margin: 0 });
  });

  // Banner: how the matrix separates them
  s.addShape(pres.shapes.RECTANGLE, {
    x: 0.4, y: 4.75, w: 9.2, h: 0.55,
    fill: { color: COL_LIGHTBLUE }, line: { color: COL_BLUE, width: 1 }
  });
  s.addText([
    { text: "Air vs water input ", options: { bold: true, fontSize: 12, color: COL_BLUE } },
    { text: "removes mechanism #1.  ", options: { fontSize: 12, color: COL_BLACK } },
    { text: "Amplitude staircase ", options: { bold: true, fontSize: 12, color: COL_BLUE } },
    { text: "separates #2–#4 by their amplitude signatures.", options: { fontSize: 12, color: COL_BLACK } }
  ], { x: 0.5, y: 4.78, w: 9.0, h: 0.5, align: "center", valign: "middle",
      fontFace: FONT_BODY, margin: 0 });

  s.addNotes("The data confirms what we predicted from physics on slide 13. " +
    "Symmetric input producing asymmetric output means the system itself has a " +
    "direction-dependent response. Today's single test can't separate these " +
    "contributions — multiple mechanisms can each generate similar even-harmonic " +
    "content. That motivates our planned multi-configuration sweep.");
}

// =============================================================
//  SLIDE 26 — Describing function (the right tool)
// =============================================================
{
  const s = pres.addSlide();
  addHeader(s, "The Describing Function Approach",
    "Textbook tool for nonlinear-system frequency-domain characterization", 26);

  // Process flow
  const steps = [
    "Pure sine\nat f₀, A",
    "Wait for\nsteady state",
    "Read output\ncontent at f₀\n(ignore harmonics)",
    "→ ONE Bode\npoint at\n(f₀, A)"
  ];
  const stepW = 1.9, stepH = 1.2, stepY = 1.4, gapX = 0.3;
  const totalW = steps.length * stepW + (steps.length - 1) * gapX;
  const startX = (10 - totalW) / 2;
  steps.forEach((t, i) => {
    const x = startX + i * (stepW + gapX);
    s.addShape(pres.shapes.RECTANGLE, {
      x, y: stepY, w: stepW, h: stepH,
      fill: { color: COL_LIGHTBLUE }, line: { color: COL_BLUE, width: 1.5 }
    });
    s.addText(t, {
      x, y: stepY, w: stepW, h: stepH, align: "center", valign: "middle",
      fontSize: 12, color: COL_BLACK, fontFace: FONT_BODY, margin: 0
    });
    if (i < steps.length - 1) {
      s.addShape(pres.shapes.LINE, {
        x: x + stepW, y: stepY + stepH/2, w: gapX, h: 0,
        line: { color: COL_BLUE, width: 2, endArrowType: "triangle" }
      });
    }
  });

  // Repeat blocks
  s.addText("Repeat across:", {
    x: 0.4, y: 3.0, w: 9.2, h: 0.35,
    fontSize: 14, bold: true, color: COL_BLUE, align: "center", fontFace: FONT_BODY
  });
  s.addShape(pres.shapes.RECTANGLE, {
    x: 1.5, y: 3.5, w: 3.0, h: 0.7,
    fill: { color: COL_LIGHTGREEN }, line: { color: COL_GREEN, width: 1 }
  });
  s.addText("Frequencies → one Bode plot", {
    x: 1.5, y: 3.5, w: 3.0, h: 0.7, align: "center", valign: "middle",
    fontSize: 12, color: COL_BLACK, fontFace: FONT_BODY, margin: 0
  });
  s.addShape(pres.shapes.RECTANGLE, {
    x: 5.5, y: 3.5, w: 3.0, h: 0.7,
    fill: { color: COL_LIGHTRED }, line: { color: COL_RED, width: 1 }
  });
  s.addText("Amplitudes → family of Bode plots", {
    x: 5.5, y: 3.5, w: 3.0, h: 0.7, align: "center", valign: "middle",
    fontSize: 12, color: COL_BLACK, fontFace: FONT_BODY, margin: 0
  });

  // Closing line
  s.addText("The slope of (parameters vs amplitude) IS the nonlinearity.", {
    x: 0.4, y: 4.6, w: 9.2, h: 0.5,
    fontSize: 14, italic: true, bold: true, color: COL_BLUE, align: "center",
    fontFace: FONT_BODY
  });

  s.addNotes("Textbook approach for nonlinear-system frequency-domain " +
    "characterization. One frequency at a time, one amplitude at a time, read " +
    "out only the input frequency from the output. The family of Bode plots " +
    "versus amplitude is the proper characterization.");
}

// =============================================================
//  SLIDE 27 — Toolkit fits this approach
// =============================================================
{
  const s = pres.addSlide();
  addHeader(s, "This Fits Our Existing Toolkit and Rig",
    "No new code needed — only the test changes", 27);

  const items = [
    ["Servo firmware", "PS amp_mm freq_hz cycles command", "already supported"],
    ["Toolkit function", "frf_sine_dwell.m — per-dwell DFT", "already implemented"],
    ["GUI panel", "Nonlinearity sweep — accumulates BLAs", "already in v1"],
    ["Pipeline", "Identical analysis for stepped sine vs broadband", "already integrated"]
  ];
  items.forEach(([what, how, status], i) => {
    const y = 1.4 + i * 0.7;
    // Green checkmark circle
    s.addShape(pres.shapes.OVAL, {
      x: 0.6, y: y + 0.1, w: 0.45, h: 0.45,
      fill: { color: COL_GREEN }
    });
    s.addText("✓", {
      x: 0.6, y: y + 0.1, w: 0.45, h: 0.45, align: "center", valign: "middle",
      fontSize: 18, bold: true, color: "FFFFFF", fontFace: FONT_BODY, margin: 0
    });
    s.addText(what, {
      x: 1.2, y, w: 2.5, h: 0.3,
      fontSize: 14, bold: true, color: COL_BLACK, fontFace: FONT_BODY, margin: 0
    });
    s.addText(how, {
      x: 1.2, y: y + 0.3, w: 5.5, h: 0.3,
      fontSize: 11, italic: true, color: COL_GRAY, fontFace: FONT_BODY, margin: 0
    });
    s.addText(status, {
      x: 6.8, y: y + 0.05, w: 2.8, h: 0.5,
      fontSize: 12, bold: true, color: COL_GREEN, align: "right", valign: "middle",
      fontFace: FONT_BODY, margin: 0
    });
  });

  // Bottom callout
  s.addShape(pres.shapes.RECTANGLE, {
    x: 0.6, y: 4.6, w: 8.8, h: 0.6,
    fill: { color: COL_LIGHTGREEN }, line: { color: COL_GREEN, width: 1 }
  });
  s.addText([
    { text: "Required change: ", options: { bold: true, fontSize: 13, color: COL_GREEN } },
    { text: "swap the excitation from trapezoidal to stepped sine, run at multiple amplitudes", options: { fontSize: 13, color: COL_BLACK } }
  ], { x: 0.7, y: 4.65, w: 8.6, h: 0.5,
      align: "center", valign: "middle", fontFace: FONT_BODY, margin: 0 });

  s.addNotes("We're set up for this. None of the analysis code changes — only " +
    "the test does. That's a deliberate design property of the toolkit: it " +
    "handles broadband and stepped-sine identically, just through a dropdown.");
}

// =============================================================
//  SLIDE 28 — Path forward (next data session)
// =============================================================
{
  const s = pres.addSlide();
  addHeader(s, "Plan for the Next Data Collection",
    "Two sweeps — each one separates a different nonlinearity", 28);

  // Sweep 1
  s.addShape(pres.shapes.RECTANGLE, {
    x: 0.4, y: 1.25, w: 4.5, h: 3.7,
    fill: { color: COL_LIGHTBLUE }, line: { color: COL_BLUE, width: 1.5 }
  });
  s.addText("1. Frequency × Amplitude", {
    x: 0.4, y: 1.3, w: 4.5, h: 0.4,
    fontSize: 14, bold: true, color: COL_BLUE, align: "center",
    fontFace: FONT_BODY, margin: 0
  });
  s.addText("(in current air-in / water-out config)", {
    x: 0.4, y: 1.7, w: 4.5, h: 0.3,
    fontSize: 11, italic: true, color: COL_GRAY, align: "center",
    fontFace: FONT_BODY, margin: 0
  });
  s.addText(bullets([
    "Stepped sine: 0.2 to 10 Hz",
    "10 frequencies, 10–20 cycles each",
    [{ text: "3 amplitudes: ", options: { bold: true } }, "20, 40, 80 mm"],
    "→ headline: parameters vs amplitude"
  ], { fontSize: 12, color: COL_BLACK }), { x: 0.7, y: 2.05, w: 4.0, h: 2.8, fontFace: FONT_BODY });

  // Sweep 2
  s.addShape(pres.shapes.RECTANGLE, {
    x: 5.1, y: 1.25, w: 4.5, h: 3.7,
    fill: { color: COL_LIGHTRED }, line: { color: COL_RED, width: 1.5 }
  });
  s.addText("2. Input-Fluid Sweep", {
    x: 5.1, y: 1.3, w: 4.5, h: 0.4,
    fontSize: 14, bold: true, color: COL_RED, align: "center",
    fontFace: FONT_BODY, margin: 0
  });
  s.addText("(swap air ↔ water at the input)", {
    x: 5.1, y: 1.7, w: 4.5, h: 0.3,
    fontSize: 11, italic: true, color: COL_GRAY, align: "center",
    fontFace: FONT_BODY, margin: 0
  });
  s.addText(bullets([
    "Repeat sweep #1 with hydraulic input",
    [{ text: "Difference = air-spring contribution", options: { bold: true } }],
    "Same fix amplitude across both",
    "→ headline: air-in vs water-in BLAs"
  ], { fontSize: 12, color: COL_BLACK }), { x: 5.4, y: 2.05, w: 4.0, h: 2.8, fontFace: FONT_BODY });

  // Concurrent improvements
  s.addText([
    { text: "Concurrent: ", options: { bold: true, fontSize: 12, color: COL_BLUE } },
    { text: "connect inlet pressure/flow sensors · time-sync the input + output ADCs", options: { fontSize: 12, italic: true, color: COL_BLACK } }
  ], { x: 0.4, y: 5.05, w: 9.2, h: 0.3,
      align: "center", fontFace: FONT_BODY, margin: 0 });

  s.addNotes("Two sweeps. The first — amplitude staircase in current config — " +
    "quantifies how nonlinear the system is along the amplitude axis. From " +
    "physics, we predict fn rises with amplitude (hyperelastic stiffening) and " +
    "ζ rises with amplitude (quadratic flow). The second sweep — input fluid " +
    "swap — separates the air-spring contribution from the rest. Together, " +
    "these two experiments give us experimental leverage on each predicted " +
    "nonlinearity independently.");
}

// =============================================================
//  SLIDE 29 — Long-term: gray-box physics
// =============================================================
{
  const s = pres.addSlide();
  addHeader(s, "Longer-Term: Gray-Box Physics Model",
    "Beyond empirical describing function — first-principles ODEs with fitted parameters", 29);

  // Two-column: empirical vs gray-box
  s.addText("Empirical (today)", {
    x: 0.4, y: 1.3, w: 4.5, h: 0.4,
    fontSize: 14, bold: true, color: COL_BLUE, align: "center", fontFace: FONT_BODY
  });
  s.addShape(pres.shapes.RECTANGLE, {
    x: 0.4, y: 1.7, w: 4.5, h: 3.0,
    fill: { color: COL_BGGRAY }, line: { color: COL_LTGRAY, width: 1 }
  });
  s.addText(bullets([
    "Tells us what the system did at conditions we tested",
    "Empirically robust",
    "Doesn't extrapolate to untested conditions",
    "No physical interpretation of fitted parameters"
  ], { fontSize: 12 }), { x: 0.6, y: 1.85, w: 4.1, h: 2.7, fontFace: FONT_BODY });

  s.addText("Gray-box (future)", {
    x: 5.1, y: 1.3, w: 4.5, h: 0.4,
    fontSize: 14, bold: true, color: COL_GREEN, align: "center", fontFace: FONT_BODY
  });
  s.addShape(pres.shapes.RECTANGLE, {
    x: 5.1, y: 1.7, w: 4.5, h: 3.0,
    fill: { color: COL_LIGHTGREEN }, line: { color: COL_GREEN, width: 1 }
  });
  s.addText(bullets([
    [{ text: "Hyperelastic metamaterial: ", options: { bold: true } }, "Mooney-Rivlin or neo-Hookean strain energy"],
    [{ text: "Hydraulic inertia: ", options: { bold: true } }, "ρL/A in tubing"],
    [{ text: "Output load: ", options: { bold: true } }, "lumped capacitor"],
    [{ text: "Tubing flow: ", options: { bold: true } }, "linear + quadratic resistance"],
    "→ State-space with fitted parameters",
    "Predicts behavior at untested conditions"
  ], { fontSize: 11 }), { x: 5.3, y: 1.85, w: 4.1, h: 2.7, fontFace: FONT_BODY });

  s.addText([
    { text: "Out of scope for this project — but the natural next direction.", options: { fontSize: 13, italic: true, color: COL_GRAY } }
  ], { x: 0.4, y: 5.0, w: 9.2, h: 0.3,
      align: "center", fontFace: FONT_BODY, margin: 0 });

  s.addNotes("Empirical models tell you what the system did at conditions you " +
    "tested. Physics models tell you what it will do at conditions you didn't. " +
    "The natural next step beyond this project.");
}

// =============================================================
//  SLIDE 30 — Conclusions
// =============================================================
{
  const s = pres.addSlide();
  addHeader(s, "Conclusions", "What we did, found, and what's next", 30);

  // 4-column conclusion summary
  const cols = [
    { title: "What we did",      color: COL_BLUE,  bg: COL_LIGHTBLUE,
      items: ["Built complete SysID toolkit", "Ran broadband ID at 80 mm, 0.5 Hz", "Analyzed via 6-stage pipeline + nonlinear modeling"] },
    { title: "What we found",    color: COL_RED,   bg: COL_LIGHTRED,
      items: ["Rig is demonstrably NONLINEAR", "15-25% THD measured", "γ² < 0.5 across band", "Validation VAF negative", "HW model fails too"] },
    { title: "Methodology",      color: COL_DKGRAY, bg: COL_BGGRAY,
      items: ["Welch H1 = BLA, not H(s) for nonlinear", "γ² is the diagnostic", "Need stepped sine + multi-amp"] },
    { title: "What's next",      color: COL_GREEN, bg: COL_LIGHTGREEN,
      items: ["Stepped sine at 3 amplitudes", "Air vs water input sweep", "Connect remaining sensors", "Long-term: gray-box model"] }
  ];
  const colW = 2.25, colH = 3.4, gapX = 0.1, startX = 0.4;
  cols.forEach((col, i) => {
    const x = startX + i * (colW + gapX);
    s.addShape(pres.shapes.RECTANGLE, {
      x, y: 1.3, w: colW, h: colH,
      fill: { color: col.bg }, line: { color: col.color, width: 1.5 }
    });
    s.addText(col.title, {
      x, y: 1.35, w: colW, h: 0.4,
      fontSize: 13, bold: true, color: col.color, align: "center",
      fontFace: FONT_BODY, margin: 0
    });
    s.addText(bullets(col.items, { fontSize: 10, color: COL_BLACK }),
      { x: x + 0.12, y: 1.78, w: colW - 0.2, h: colH - 0.5, fontFace: FONT_BODY });
  });

  // Headline takeaway
  s.addShape(pres.shapes.RECTANGLE, {
    x: 0.4, y: 4.85, w: 9.2, h: 0.5,
    fill: { color: COL_BLACK }, line: { color: COL_BLACK, width: 0 }
  });
  s.addText("Predict → test → falsify → revise the methodology. A complete scientific arc.", {
    x: 0.4, y: 4.85, w: 9.2, h: 0.5,
    fontSize: 13, bold: true, italic: true, color: "FFFFFF", align: "center", valign: "middle",
    fontFace: FONT_BODY, margin: 0
  });

  s.addNotes("We didn't end up with a fitted transfer function for the heart " +
    "pump. What we ended up with is something more useful: quantitative evidence " +
    "that the rig is nonlinear at this drive amplitude, a physical mechanism " +
    "that explains the nonlinearity, and a clear plan for the right test to " +
    "characterize it. That's a complete scientific arc — predict, test, " +
    "falsify, revise the methodology.");
}

// =============================================================
//  SLIDE 31 — Q&A / Acknowledgments
// =============================================================
{
  const s = pres.addSlide();
  // Centered title (no header bar — clean closing)
  s.addText("Questions?", {
    x: 0.4, y: 1.7, w: 9.2, h: 1.2,
    fontSize: 72, bold: true, color: COL_BLACK, align: "center", valign: "middle",
    fontFace: FONT_HEADER, margin: 0
  });
  s.addText("Team Roche and Roll", {
    x: 0.4, y: 3.2, w: 9.2, h: 0.4,
    fontSize: 18, color: COL_GRAY, align: "center", valign: "middle",
    fontFace: FONT_BODY, margin: 0
  });
  s.addText("Ariel Mobius · Isabel Sperandio · Sam Kirschner · Diego Quevedo", {
    x: 0.4, y: 3.65, w: 9.2, h: 0.4,
    fontSize: 14, color: COL_GRAY, align: "center", valign: "middle",
    fontFace: FONT_BODY, margin: 0
  });
  s.addText("31", {
    x: 9.45, y: 5.3, w: 0.4, h: 0.25,
    fontSize: 10, color: COL_LTGRAY, align: "right",
    fontFace: FONT_BODY, margin: 0
  });
  s.addNotes("Open the floor for questions.");
}

// =============================================================
//  Write the file
// =============================================================
const outputPath = __dirname + "/SystemID_Slides_11-31.pptx";
pres.writeFile({ fileName: outputPath }).then(filename => {
  console.log("Wrote:", filename);
});
