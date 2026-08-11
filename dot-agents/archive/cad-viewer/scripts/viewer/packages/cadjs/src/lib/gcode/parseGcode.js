const GCODE_RENDER_SCHEMA_VERSION = 1;
const POSITION_EPSILON = 1e-7;
const EXTRUSION_EPSILON = 1e-7;
const ARC_CHORD_MM = 0.8;
const MIN_ARC_SEGMENTS = 6;
const MAX_ARC_SEGMENTS = 160;
const UNCLASSIFIED_FEATURE = Object.freeze({
  id: "unclassified",
  label: "Unclassified",
  category: "other",
  rawLabel: ""
});
const FEATURE_CATEGORY_ORDER = Object.freeze({
  support: 0,
  wall: 1,
  surface: 2,
  infill: 3,
  adhesion: 4,
  calibration: 5,
  other: 6
});
const FEATURE_DEFINITIONS = Object.freeze([
  {
    id: "support-interface",
    label: "Support interface",
    category: "support",
    patterns: [
      /\bsupport\b.*\b(interface|roof|floor)\b/,
      /\binterface\b.*\bsupport\b/
    ]
  },
  {
    id: "support",
    label: "Support",
    category: "support",
    patterns: [/\bsupport(?:s| material)?\b/]
  },
  {
    id: "overhang-wall",
    label: "Overhang wall",
    category: "wall",
    patterns: [/\boverhang\b.*\b(wall|perimeter)\b/]
  },
  {
    id: "outer-wall",
    label: "Outer wall",
    category: "wall",
    patterns: [
      /\bouter\b.*\b(wall|perimeter|shell)\b/,
      /\bexternal\b.*\b(perimeter|wall|shell)\b/,
      /\bwall outer\b/
    ]
  },
  {
    id: "inner-wall",
    label: "Inner wall",
    category: "wall",
    patterns: [
      /\binner\b.*\b(wall|perimeter|shell)\b/,
      /\binternal\b.*\bperimeter\b/,
      /\bwall inner\b/
    ]
  },
  {
    id: "wall",
    label: "Wall",
    category: "wall",
    patterns: [/\b(wall|perimeter|shell)\b/]
  },
  {
    id: "bridge",
    label: "Bridge",
    category: "surface",
    patterns: [/\bbridge\b/]
  },
  {
    id: "top-surface",
    label: "Top surface",
    category: "surface",
    patterns: [/\btop\b.*\b(surface|skin|shell|solid infill|infill)\b/]
  },
  {
    id: "bottom-surface",
    label: "Bottom surface",
    category: "surface",
    patterns: [/\bbottom\b.*\b(surface|skin|shell|solid infill|infill)\b/]
  },
  {
    id: "surface",
    label: "Surface",
    category: "surface",
    patterns: [/\b(skin|surface)\b/]
  },
  {
    id: "gap-fill",
    label: "Gap fill",
    category: "infill",
    patterns: [/\bgap\b.*\bfill\b/]
  },
  {
    id: "internal-solid-infill",
    label: "Internal solid infill",
    category: "infill",
    patterns: [
      /\binternal\b.*\bsolid\b.*\binfill\b/,
      /\bsolid\b.*\binfill\b/
    ]
  },
  {
    id: "sparse-infill",
    label: "Sparse infill",
    category: "infill",
    patterns: [
      /\bsparse\b.*\binfill\b/,
      /\binternal\b.*\binfill\b/,
      /\bfill\b/
    ]
  },
  {
    id: "infill",
    label: "Infill",
    category: "infill",
    patterns: [/\binfill\b/]
  },
  {
    id: "skirt",
    label: "Skirt",
    category: "adhesion",
    patterns: [/\bskirt\b/]
  },
  {
    id: "brim",
    label: "Brim",
    category: "adhesion",
    patterns: [/\bbrim\b/]
  },
  {
    id: "raft",
    label: "Raft",
    category: "adhesion",
    patterns: [/\braft\b/]
  },
  {
    id: "prime-tower",
    label: "Prime tower",
    category: "calibration",
    patterns: [/\b(prime|wipe)\b.*\btower\b/]
  },
  {
    id: "ironing",
    label: "Ironing",
    category: "surface",
    patterns: [/\bironing\b/]
  },
  {
    id: "flush",
    label: "Flush",
    category: "calibration",
    patterns: [/\bflush\b/]
  },
  {
    id: "wipe",
    label: "Wipe",
    category: "calibration",
    patterns: [/\bwipe\b/]
  },
  {
    id: "custom",
    label: "Custom",
    category: "other",
    patterns: [/\bcustom\b/]
  }
]);
const SUPPORTED_COMMANDS = new Set([
  "G0",
  "G1",
  "G2",
  "G3",
  "G20",
  "G21",
  "G28",
  "G90",
  "G91",
  "G92",
  "M82",
  "M83",
  "M84",
  "M104",
  "M106",
  "M107",
  "M109",
  "M140",
  "M190"
]);

function toFiniteNumber(value, fallback = 0) {
  const numericValue = Number(value);
  return Number.isFinite(numericValue) ? numericValue : fallback;
}

function clonePoint(point) {
  return [
    toFiniteNumber(point?.[0]),
    toFiniteNumber(point?.[1]),
    toFiniteNumber(point?.[2])
  ];
}

function stripComment(line) {
  return String(line || "").split(";", 1)[0].trim();
}

function parseCommand(line) {
  const stripped = stripComment(line).toUpperCase();
  if (!stripped) {
    return "";
  }
  const first = stripped.split(/\s+/, 1)[0];
  if (/^[GMT]\d+(?:\.\d+)?$/.test(first)) {
    return first.split(".", 1)[0];
  }
  return first;
}

function parseTokens(line) {
  const stripped = stripComment(line).toUpperCase();
  const tokens = {};
  for (const match of stripped.matchAll(/([A-Z])([-+]?(?:\d+(?:\.\d*)?|\.\d+))/g)) {
    tokens[match[1]] = Number(match[2]);
  }
  return tokens;
}

function commentText(line) {
  const source = String(line || "");
  const commentIndex = source.indexOf(";");
  return commentIndex >= 0 ? source.slice(commentIndex + 1).trim() : "";
}

function normalizeFeatureText(value) {
  return String(value || "")
    .replace(/^["']+|["']+$/g, "")
    .replace(/[_-]+/g, " ")
    .replace(/\s+/g, " ")
    .trim();
}

function featureSlug(value) {
  return normalizeFeatureText(value)
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, "-")
    .replace(/^-+|-+$/g, "")
    .slice(0, 80);
}

function titleCaseFeatureLabel(value) {
  const normalized = normalizeFeatureText(value);
  if (!normalized) {
    return "Other";
  }
  return normalized
    .toLowerCase()
    .split(" ")
    .map((word) => word ? `${word[0].toUpperCase()}${word.slice(1)}` : "")
    .join(" ");
}

function featureFromLabel(rawLabel) {
  const normalized = normalizeFeatureText(rawLabel);
  const matchText = normalized.toLowerCase();
  for (const definition of FEATURE_DEFINITIONS) {
    if (definition.patterns.some((pattern) => pattern.test(matchText))) {
      return {
        id: definition.id,
        label: definition.label,
        category: definition.category,
        rawLabel: normalized
      };
    }
  }
  const slug = featureSlug(normalized);
  return {
    id: slug ? `other:${slug}` : UNCLASSIFIED_FEATURE.id,
    label: slug ? titleCaseFeatureLabel(normalized) : UNCLASSIFIED_FEATURE.label,
    category: "other",
    rawLabel: normalized
  };
}

function parseFeatureMarker(line) {
  const comment = commentText(line);
  if (!comment) {
    return null;
  }
  const match = comment.match(/^(?:FEATURE|TYPE|PRINT_FEATURE|TOOLPATH(?:_TYPE)?|PATH_TYPE)\s*[:=]\s*(.+)$/i);
  if (!match?.[1]) {
    return null;
  }
  return featureFromLabel(match[1]);
}

function distance3(a, b) {
  const dx = toFiniteNumber(b?.[0]) - toFiniteNumber(a?.[0]);
  const dy = toFiniteNumber(b?.[1]) - toFiniteNumber(a?.[1]);
  const dz = toFiniteNumber(b?.[2]) - toFiniteNumber(a?.[2]);
  return Math.hypot(dx, dy, dz);
}

function roundedZ(value) {
  return Math.round(toFiniteNumber(value) * 1000000) / 1000000;
}

function updateBounds(bounds, point) {
  const next = clonePoint(point);
  for (let axis = 0; axis < 3; axis += 1) {
    bounds.min[axis] = Math.min(bounds.min[axis], next[axis]);
    bounds.max[axis] = Math.max(bounds.max[axis], next[axis]);
  }
}

function layerKey(z) {
  return roundedZ(z).toFixed(6);
}

function layerIndexForZ(layers, z) {
  if (!layers.length) {
    return 0;
  }
  const target = roundedZ(z);
  let bestIndex = 0;
  let bestDistance = Infinity;
  for (let index = 0; index < layers.length; index += 1) {
    const distance = Math.abs(toFiniteNumber(layers[index]?.z) - target);
    if (distance < bestDistance) {
      bestIndex = index;
      bestDistance = distance;
    }
  }
  return bestIndex;
}

function endpointForMove(position, tokens, absolutePositioning) {
  return [
    Object.hasOwn(tokens, "X")
      ? (absolutePositioning ? tokens.X : position.x + tokens.X)
      : position.x,
    Object.hasOwn(tokens, "Y")
      ? (absolutePositioning ? tokens.Y : position.y + tokens.Y)
      : position.y,
    Object.hasOwn(tokens, "Z")
      ? (absolutePositioning ? tokens.Z : position.z + tokens.Z)
      : position.z
  ];
}

function nextExtruder(position, tokens, absoluteExtrusion) {
  if (!Object.hasOwn(tokens, "E")) {
    return position.e;
  }
  return absoluteExtrusion ? tokens.E : position.e + tokens.E;
}

function addSegment(segments, bounds, stats, {
  lineNumber,
  command,
  start,
  end,
  extrusionDelta = 0,
  feedRate = null,
  arc = false,
  feature = null
}) {
  const lengthMm = distance3(start, end);
  if (lengthMm <= POSITION_EPSILON) {
    if (extrusionDelta < -EXTRUSION_EPSILON) {
      stats.retractMoves += 1;
    } else if (extrusionDelta > EXTRUSION_EPSILON) {
      stats.primeMoves += 1;
    }
    return;
  }

  const kind = extrusionDelta > EXTRUSION_EPSILON ? "extrusion" : "travel";
  if (kind === "extrusion") {
    stats.extrusionMoves += 1;
    stats.extrusionMm += extrusionDelta;
  } else {
    stats.travelMoves += 1;
  }
  stats.movementCommands += 1;
  stats.pathMm += lengthMm;
  updateBounds(bounds, start);
  updateBounds(bounds, end);
  segments.push({
    lineNumber,
    command,
    kind,
    start: clonePoint(start),
    end: clonePoint(end),
    z: roundedZ(end[2]),
    extrusionDelta,
    feedRate: Number.isFinite(feedRate) ? feedRate : null,
    lengthMm,
    arc: Boolean(arc),
    featureId: feature?.id || UNCLASSIFIED_FEATURE.id,
    featureLabel: feature?.label || UNCLASSIFIED_FEATURE.label,
    featureCategory: feature?.category || UNCLASSIFIED_FEATURE.category,
    featureRaw: feature?.rawLabel || ""
  });
}

function arcSegments({ start, end, tokens, clockwise }) {
  if (!Object.hasOwn(tokens, "I") || !Object.hasOwn(tokens, "J")) {
    return null;
  }
  const centerX = start[0] + tokens.I;
  const centerY = start[1] + tokens.J;
  const radius = Math.hypot(start[0] - centerX, start[1] - centerY);
  if (!(radius > POSITION_EPSILON)) {
    return null;
  }
  const startAngle = Math.atan2(start[1] - centerY, start[0] - centerX);
  const endAngle = Math.atan2(end[1] - centerY, end[0] - centerX);
  let sweep = endAngle - startAngle;
  if (clockwise && sweep >= 0) {
    sweep -= Math.PI * 2;
  } else if (!clockwise && sweep <= 0) {
    sweep += Math.PI * 2;
  }
  const chordSegments = Math.ceil(Math.abs(sweep * radius) / ARC_CHORD_MM);
  const segmentCount = Math.max(MIN_ARC_SEGMENTS, Math.min(MAX_ARC_SEGMENTS, chordSegments));
  const points = [clonePoint(start)];
  for (let index = 1; index <= segmentCount; index += 1) {
    const t = index / segmentCount;
    const angle = startAngle + sweep * t;
    points.push([
      centerX + radius * Math.cos(angle),
      centerY + radius * Math.sin(angle),
      start[2] + (end[2] - start[2]) * t
    ]);
  }
  return points;
}

function compactBounds(bounds) {
  if (!bounds.min.every(Number.isFinite) || !bounds.max.every(Number.isFinite)) {
    return {
      min: [0, 0, 0],
      max: [1, 1, 1]
    };
  }
  return {
    min: bounds.min.map((value) => roundedZ(value)),
    max: bounds.max.map((value) => roundedZ(value))
  };
}

function finalizeLayers(segments) {
  const zValues = new Map();
  for (const segment of segments) {
    if (segment.kind !== "extrusion") {
      continue;
    }
    const key = layerKey(segment.z);
    if (!zValues.has(key)) {
      zValues.set(key, roundedZ(segment.z));
    }
  }
  if (!zValues.size) {
    for (const segment of segments) {
      const key = layerKey(segment.z);
      if (!zValues.has(key)) {
        zValues.set(key, roundedZ(segment.z));
      }
    }
  }
  const layers = [...zValues.values()]
    .sort((left, right) => left - right)
    .map((z, index) => ({
      index,
      z,
      segmentCount: 0,
      extrusionMoves: 0,
      travelMoves: 0
    }));
  for (const segment of segments) {
    const index = layerIndexForZ(layers, segment.z);
    segment.layerIndex = index;
    if (layers[index]) {
      layers[index].segmentCount += 1;
      if (segment.kind === "extrusion") {
        layers[index].extrusionMoves += 1;
      } else {
        layers[index].travelMoves += 1;
      }
    }
  }
  return layers;
}

function ensureFeatureRecord(records, feature) {
  const resolvedFeature = feature?.id ? feature : UNCLASSIFIED_FEATURE;
  if (!records.has(resolvedFeature.id)) {
    records.set(resolvedFeature.id, {
      id: resolvedFeature.id,
      label: resolvedFeature.label || UNCLASSIFIED_FEATURE.label,
      category: resolvedFeature.category || UNCLASSIFIED_FEATURE.category,
      rawLabels: new Set(),
      markerCount: 0,
      firstLine: null,
      lastLine: null,
      firstLayerIndex: null,
      lastLayerIndex: null,
      segmentCount: 0,
      extrusionMoves: 0,
      travelMoves: 0,
      extrusionMm: 0,
      pathMm: 0
    });
  }
  const record = records.get(resolvedFeature.id);
  if (resolvedFeature.rawLabel) {
    record.rawLabels.add(resolvedFeature.rawLabel);
  }
  return record;
}

function layerRangeText(record) {
  if (!Number.isInteger(record.firstLayerIndex) || !Number.isInteger(record.lastLayerIndex)) {
    return "";
  }
  return record.firstLayerIndex === record.lastLayerIndex
    ? `Layer ${record.firstLayerIndex + 1}`
    : `Layers ${record.firstLayerIndex + 1}-${record.lastLayerIndex + 1}`;
}

function finalizeFeatures(segments, markers) {
  const records = new Map();
  for (const marker of markers) {
    const record = ensureFeatureRecord(records, marker.feature);
    record.markerCount += 1;
    record.firstLine = record.firstLine == null ? marker.lineNumber : Math.min(record.firstLine, marker.lineNumber);
    record.lastLine = record.lastLine == null ? marker.lineNumber : Math.max(record.lastLine, marker.lineNumber);
  }

  for (const segment of segments) {
    const record = ensureFeatureRecord(records, {
      id: segment.featureId,
      label: segment.featureLabel,
      category: segment.featureCategory,
      rawLabel: segment.featureRaw
    });
    record.segmentCount += 1;
    record.pathMm += toFiniteNumber(segment.lengthMm);
    if (Number.isInteger(segment.layerIndex)) {
      record.firstLayerIndex = record.firstLayerIndex == null
        ? segment.layerIndex
        : Math.min(record.firstLayerIndex, segment.layerIndex);
      record.lastLayerIndex = record.lastLayerIndex == null
        ? segment.layerIndex
        : Math.max(record.lastLayerIndex, segment.layerIndex);
    }
    if (segment.kind === "extrusion") {
      record.extrusionMoves += 1;
      record.extrusionMm += toFiniteNumber(segment.extrusionDelta);
    } else if (segment.kind === "travel") {
      record.travelMoves += 1;
    }
  }

  return [...records.values()]
    .map((record) => ({
      ...record,
      rawLabels: [...record.rawLabels].sort((left, right) => left.localeCompare(right)),
      layerRangeText: layerRangeText(record),
      pathMm: roundedZ(record.pathMm),
      extrusionMm: roundedZ(record.extrusionMm)
    }))
    .sort((left, right) => {
      const categoryDelta = (FEATURE_CATEGORY_ORDER[left.category] ?? 99) - (FEATURE_CATEGORY_ORDER[right.category] ?? 99);
      if (categoryDelta !== 0) {
        return categoryDelta;
      }
      const extrusionDelta = right.extrusionMoves - left.extrusionMoves;
      if (extrusionDelta !== 0) {
        return extrusionDelta;
      }
      return left.label.localeCompare(right.label);
    });
}

function warningList(warnings, unsupportedCommands) {
  const result = [...warnings];
  const unsupported = [...unsupportedCommands.entries()]
    .sort((left, right) => left[0].localeCompare(right[0]))
    .slice(0, 12)
    .map(([command, line]) => `${command} line ${line}`);
  if (unsupported.length) {
    result.push(`Unsupported or ignored commands were left out of the preview: ${unsupported.join(", ")}.`);
  }
  return result;
}

export function parseGcode(text, { sourceUrl = "", fileRef = "" } = {}) {
  const lines = String(text || "").split(/\r?\n/);
  const segments = [];
  const unsupportedCommands = new Map();
  const warnings = [];
  const bounds = {
    min: [Infinity, Infinity, Infinity],
    max: [-Infinity, -Infinity, -Infinity]
  };
  const stats = {
    lines: lines.length,
    nonCommentLines: 0,
    movementCommands: 0,
    extrusionMoves: 0,
    travelMoves: 0,
    retractMoves: 0,
    primeMoves: 0,
    temperatureCommands: 0,
    extrusionMm: 0,
    pathMm: 0
  };
  const position = {
    x: 0,
    y: 0,
    z: 0,
    e: 0
  };
  let absolutePositioning = true;
  let absoluteExtrusion = true;
  let units = "mm";
  let relativeWarningAdded = false;
  let inchWarningAdded = false;
  let currentFeature = null;
  const featureMarkers = [];

  for (let lineIndex = 0; lineIndex < lines.length; lineIndex += 1) {
    const lineNumber = lineIndex + 1;
    const rawLine = lines[lineIndex];
    const featureMarker = parseFeatureMarker(rawLine);
    if (featureMarker) {
      currentFeature = featureMarker;
      featureMarkers.push({
        lineNumber,
        feature: featureMarker
      });
    }
    const command = parseCommand(rawLine);
    if (!command) {
      continue;
    }
    stats.nonCommentLines += 1;
    const tokens = parseTokens(rawLine);

    if (!SUPPORTED_COMMANDS.has(command) && !/^T\d+$/.test(command)) {
      unsupportedCommands.set(command, unsupportedCommands.get(command) || lineNumber);
    }

    if (command === "G20") {
      units = "inch";
      if (!inchWarningAdded) {
        warnings.push("G20 inch units found; preview geometry assumes millimeters.");
        inchWarningAdded = true;
      }
      continue;
    }
    if (command === "G21") {
      units = "mm";
      continue;
    }
    if (command === "G90") {
      absolutePositioning = true;
      continue;
    }
    if (command === "G91") {
      absolutePositioning = false;
      if (!relativeWarningAdded) {
        warnings.push("Relative XYZ positioning found; preview follows relative moves after G91.");
        relativeWarningAdded = true;
      }
      continue;
    }
    if (command === "M82") {
      absoluteExtrusion = true;
      continue;
    }
    if (command === "M83") {
      absoluteExtrusion = false;
      continue;
    }
    if (command === "G92") {
      if (Object.hasOwn(tokens, "X")) {
        position.x = tokens.X;
      }
      if (Object.hasOwn(tokens, "Y")) {
        position.y = tokens.Y;
      }
      if (Object.hasOwn(tokens, "Z")) {
        position.z = tokens.Z;
      }
      if (Object.hasOwn(tokens, "E")) {
        position.e = tokens.E;
      }
      continue;
    }
    if (["M104", "M109", "M140", "M190"].includes(command)) {
      stats.temperatureCommands += 1;
      continue;
    }
    if (!["G0", "G1", "G2", "G3"].includes(command)) {
      continue;
    }

    const start = [position.x, position.y, position.z];
    const end = endpointForMove(position, tokens, absolutePositioning);
    const nextE = nextExtruder(position, tokens, absoluteExtrusion);
    const extrusionDelta = nextE - position.e;
    const feedRate = Object.hasOwn(tokens, "F") ? tokens.F : null;

    if (command === "G2" || command === "G3") {
      const points = arcSegments({
        start,
        end,
        tokens,
        clockwise: command === "G2"
      });
      if (points) {
        for (let index = 0; index < points.length - 1; index += 1) {
          addSegment(segments, bounds, stats, {
            lineNumber,
            command,
            start: points[index],
            end: points[index + 1],
            extrusionDelta: extrusionDelta / Math.max(points.length - 1, 1),
            feedRate,
            arc: true,
            feature: currentFeature
          });
        }
      } else {
        warnings.push(`Line ${lineNumber}: ${command} arc is missing I/J center offsets; previewed as a straight move.`);
        addSegment(segments, bounds, stats, {
          lineNumber,
          command,
          start,
          end,
          extrusionDelta,
          feedRate,
          arc: false,
          feature: currentFeature
        });
      }
    } else {
      addSegment(segments, bounds, stats, {
        lineNumber,
        command,
        start,
        end,
        extrusionDelta,
        feedRate,
        feature: currentFeature
      });
    }

    position.x = end[0];
    position.y = end[1];
    position.z = end[2];
    position.e = nextE;
  }

  const layers = finalizeLayers(segments);
  const features = finalizeFeatures(segments, featureMarkers);
  return {
    schemaVersion: GCODE_RENDER_SCHEMA_VERSION,
    sourceUrl,
    fileRef,
    units,
    bounds: compactBounds(bounds),
    layers,
    features,
    segments,
    stats,
    warnings: warningList(warnings, unsupportedCommands)
  };
}
