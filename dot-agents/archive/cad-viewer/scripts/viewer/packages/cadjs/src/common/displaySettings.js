import {
  DEFAULT_STEP_CLIP_SETTINGS,
  normalizeStepClipSettings,
  stepClipSettingsEqual
} from "../lib/viewer/clipPlane.js";
import {
  CAMERA_PROJECTION,
  normalizeCameraProjection
} from "../lib/perspective.js";

export { CAMERA_PROJECTION, normalizeCameraProjection };

export const CAD_DISPLAY_MODE = Object.freeze({
  HIDDEN_EDGES: "hidden_edges",
  HIDDEN_LINES_REMOVED: "hidden_lines_removed",
  RENDERED: "rendered",
  SOLID: "solid",
  TRANSPARENT: "transparent",
  UNSHADED: "unshaded",
  WIREFRAME: "wireframe"
});

export const CAD_DISPLAY_MODE_VALUES = Object.freeze(Object.values(CAD_DISPLAY_MODE));

export const EXPLODED_VIEW_AXES = Object.freeze(["x", "y", "z", "radial"]);
export const EXPLODED_VIEW_DIRECTIONS = Object.freeze(["positive", "negative"]);
export const MAX_EXPLODED_VIEW_DEPTH = 8;
const HEX_COLOR_PATTERN = /^#(?:[0-9a-fA-F]{3}){1,2}$/;

export const CAD_EDGE_COLOR = "#132232";
export const CAD_EDGE_HIGHLIGHT_COLOR = "#8dc5ff";
export const CAD_EDGE_CLASS_IDS = Object.freeze(["feature", "tangent", "seam", "degenerate"]);

export const DEFAULT_DISPLAY_EDGE_CLASS_SETTINGS = Object.freeze({
  feature: Object.freeze({
    color: CAD_EDGE_COLOR,
    opacity: 1,
    thickness: 1.15
  }),
  tangent: Object.freeze({
    color: CAD_EDGE_COLOR,
    opacity: 0.5,
    thickness: 1.15
  }),
  seam: Object.freeze({
    color: CAD_EDGE_COLOR,
    opacity: 0.85,
    thickness: 1.15
  }),
  degenerate: Object.freeze({
    color: CAD_EDGE_COLOR,
    opacity: 1,
    thickness: 0
  })
});

export const DEFAULT_DISPLAY_EDGE_SETTINGS = Object.freeze({
  enabled: true,
  contrastMode: "manual",
  color: CAD_EDGE_COLOR,
  thickness: 1,
  classes: DEFAULT_DISPLAY_EDGE_CLASS_SETTINGS,
  highlightColor: CAD_EDGE_HIGHLIGHT_COLOR,
  highlightOpacity: 1,
  highlightThickness: 3,
  silhouette: false,
  silhouetteScale: 0
});

export const DISABLED_DISPLAY_EDGE_SETTINGS = Object.freeze({
  ...DEFAULT_DISPLAY_EDGE_SETTINGS,
  enabled: false
});

export const DEFAULT_EXPLODED_VIEW_SETTINGS = Object.freeze({
  enabled: false,
  axis: "z",
  direction: "positive",
  spacing: 1.45,
  depth: 1,
  keepBaseGrounded: true,
  mergeCoplanar: false,
  autoFrame: true
});

export const DEFAULT_DISPLAY_SETTINGS = Object.freeze({
  projection: CAMERA_PROJECTION.ORTHOGRAPHIC,
  mode: CAD_DISPLAY_MODE.SOLID,
  clip: DEFAULT_STEP_CLIP_SETTINGS,
  exploded: DEFAULT_EXPLODED_VIEW_SETTINGS,
  edges: DEFAULT_DISPLAY_EDGE_SETTINGS
});

function isObject(value) {
  return Boolean(value) && typeof value === "object" && !Array.isArray(value);
}

function clamp(value, min, max) {
  return Math.min(Math.max(value, min), max);
}

function normalizeNumber(value, fallback, min = -Infinity, max = Infinity) {
  const numericValue = Number(value);
  if (!Number.isFinite(numericValue)) {
    return fallback;
  }
  return clamp(numericValue, min, max);
}

function normalizeColor(value, fallback) {
  const normalized = String(value || "").trim();
  if (!HEX_COLOR_PATTERN.test(normalized)) {
    return fallback;
  }
  return normalized.length === 4
    ? `#${normalized[1]}${normalized[1]}${normalized[2]}${normalized[2]}${normalized[3]}${normalized[3]}`.toLowerCase()
    : normalized.toLowerCase();
}

function normalizeBoolean(value, fallback = false) {
  return typeof value === "boolean" ? value : fallback;
}

function normalizeDisplayEdgeContrastMode(value, fallback = "manual") {
  const normalized = String(value || "").trim().toLowerCase();
  return ["auto", "manual"].includes(normalized)
    ? normalized
    : fallback;
}

export function normalizeDisplayEdgeClassSettings(
  value = {},
  fallback = DEFAULT_DISPLAY_EDGE_CLASS_SETTINGS,
  colorFallback = CAD_EDGE_COLOR
) {
  const source = isObject(value) ? value : {};
  const fallbackColor = normalizeColor(colorFallback, CAD_EDGE_COLOR);
  return Object.fromEntries(CAD_EDGE_CLASS_IDS.map((classId) => {
    const classSource = isObject(source[classId]) ? source[classId] : {};
    const classFallback = fallback?.[classId] || DEFAULT_DISPLAY_EDGE_CLASS_SETTINGS[classId];
    const legacyDisabled = classSource.enabled === false;
    return [classId, {
      color: normalizeColor(classSource.color, fallbackColor),
      opacity: normalizeNumber(classSource.opacity, classFallback.opacity, 0, 1),
      thickness: legacyDisabled
        ? 0
        : normalizeNumber(classSource.thickness, classFallback.thickness, 0, 6)
    }];
  }));
}

export function normalizeDisplayEdgeSettings(value = null, fallback = DEFAULT_DISPLAY_EDGE_SETTINGS) {
  const source = isObject(value) ? value : {};
  const color = normalizeColor(source.color, fallback.color);
  const normalized = {
    enabled: normalizeBoolean(source.enabled, fallback.enabled),
    contrastMode: normalizeDisplayEdgeContrastMode(source.contrastMode, fallback.contrastMode),
    color,
    thickness: normalizeNumber(source.thickness, fallback.thickness, 0.5, 6),
    classes: normalizeDisplayEdgeClassSettings(source.classes, fallback.classes, color),
    highlightColor: normalizeColor(source.highlightColor, fallback.highlightColor || CAD_EDGE_HIGHLIGHT_COLOR),
    highlightOpacity: normalizeNumber(source.highlightOpacity, fallback.highlightOpacity || 1, 0, 1),
    highlightThickness: normalizeNumber(source.highlightThickness, fallback.highlightThickness || 3, 0.5, 6),
    silhouette: normalizeBoolean(source.silhouette, fallback.silhouette || false),
    silhouetteScale: normalizeNumber(source.silhouetteScale, fallback.silhouetteScale || 0, 0, 0.04)
  };
  if (typeof source.depthTest === "boolean") {
    normalized.depthTest = source.depthTest;
  }
  return normalized;
}

function normalizeModeText(value) {
  return String(value || "").trim().toLowerCase().replace(/\s+/g, "_").replace(/-/g, "_");
}

export function normalizeDisplayMode(value) {
  const normalized = normalizeModeText(value);
  if (!normalized) {
    return CAD_DISPLAY_MODE.SOLID;
  }
  if (normalized === "wire" || normalized === "wire_frame") {
    return CAD_DISPLAY_MODE.WIREFRAME;
  }
  if (
    normalized === "edges" ||
    normalized === "edge" ||
    normalized === "shaded_edges" ||
    normalized === "shaded_with_edges" ||
    normalized === "with_edges"
  ) {
    return CAD_DISPLAY_MODE.SOLID;
  }
  if (
    normalized === "shaded" ||
    normalized === "shaded_without_edges" ||
    normalized === "without_edges"
  ) {
    return CAD_DISPLAY_MODE.RENDERED;
  }
  if (
    normalized === "translucent" ||
    normalized === "xray" ||
    normalized === "x_ray" ||
    normalized === "see_through"
  ) {
    return CAD_DISPLAY_MODE.TRANSPARENT;
  }
  if (
    normalized === "hidden_edge" ||
    normalized === "hidden_edges_visible" ||
    normalized === "hidden_edge_display" ||
    normalized === "shaded_hidden_edges"
  ) {
    return CAD_DISPLAY_MODE.HIDDEN_EDGES;
  }
  if (
    normalized === "visible_edges" ||
    normalized === "visible_edges_only" ||
    normalized === "hidden_lines" ||
    normalized === "hidden_line_removed" ||
    normalized === "hidden_lines_removed" ||
    normalized === "hidden_edges_removed"
  ) {
    return CAD_DISPLAY_MODE.HIDDEN_LINES_REMOVED;
  }
  if (normalized === "flat") {
    return CAD_DISPLAY_MODE.UNSHADED;
  }
  if (normalized === "appearance" || normalized === "material" || normalized === "materials") {
    return CAD_DISPLAY_MODE.RENDERED;
  }
  return CAD_DISPLAY_MODE_VALUES.includes(normalized)
    ? normalized
    : CAD_DISPLAY_MODE.SOLID;
}

export function normalizeExplodedViewAxis(value, fallback = DEFAULT_EXPLODED_VIEW_SETTINGS.axis) {
  const normalized = String(value || "").trim().toLowerCase();
  const axis = normalized.startsWith("-") ? normalized.slice(1) : normalized;
  return EXPLODED_VIEW_AXES.includes(axis) ? axis : fallback;
}

export function normalizeExplodedViewDirection(value, fallback = DEFAULT_EXPLODED_VIEW_SETTINGS.direction) {
  const normalized = String(value || "").trim().toLowerCase();
  if (["negative", "reverse", "down", "backward", "-", "-1"].includes(normalized)) {
    return "negative";
  }
  if (["positive", "forward", "up", "+", "+1", "1"].includes(normalized)) {
    return "positive";
  }
  return fallback;
}

export function normalizeExplodedViewDepth(value, fallback = DEFAULT_EXPLODED_VIEW_SETTINGS.depth) {
  const normalized = String(value ?? "").trim().toLowerCase();
  if (["all", "full", "parts", "leaves", "leaf"].includes(normalized)) {
    return MAX_EXPLODED_VIEW_DEPTH;
  }
  const numericValue = Math.round(Number(value));
  return Number.isFinite(numericValue)
    ? clamp(numericValue, 1, MAX_EXPLODED_VIEW_DEPTH)
    : fallback;
}

export function normalizeExplodedViewSettings(value = null, overrides = {}) {
  const source = isObject(value) ? value : {};
  const merged = isObject(overrides) ? { ...source, ...overrides } : source;
  const axisText = String(merged.axis || "").trim().toLowerCase();
  return {
    enabled: normalizeBoolean(merged.enabled, DEFAULT_EXPLODED_VIEW_SETTINGS.enabled),
    axis: normalizeExplodedViewAxis(merged.axis),
    direction: normalizeExplodedViewDirection(merged.direction || (axisText.startsWith("-") ? "negative" : "positive")),
    spacing: normalizeNumber(merged.spacing ?? merged.distance ?? merged.distanceScale, DEFAULT_EXPLODED_VIEW_SETTINGS.spacing, 0.25, 4),
    depth: normalizeExplodedViewDepth(merged.depth ?? merged.levels ?? merged.scopeDepth),
    keepBaseGrounded: normalizeBoolean(merged.keepBaseGrounded ?? merged.groundBase, DEFAULT_EXPLODED_VIEW_SETTINGS.keepBaseGrounded),
    mergeCoplanar: normalizeBoolean(merged.mergeCoplanar ?? merged.mergeLayers ?? merged.coalesceLayers, DEFAULT_EXPLODED_VIEW_SETTINGS.mergeCoplanar),
    autoFrame: normalizeBoolean(merged.autoFrame, DEFAULT_EXPLODED_VIEW_SETTINGS.autoFrame)
  };
}

export function normalizeDisplaySettings(value = null) {
  const source = isObject(value) ? value : {};
  const explodedOverrides = {};
  if (isObject(source.exploded) && source.exploded.enabled !== undefined) {
    explodedOverrides.enabled = source.exploded.enabled;
  }
  return {
    projection: normalizeCameraProjection(source.projection, DEFAULT_DISPLAY_SETTINGS.projection),
    mode: normalizeDisplayMode(source.mode),
    clip: normalizeStepClipSettings(source.clip),
    exploded: normalizeExplodedViewSettings(source.exploded, explodedOverrides),
    edges: normalizeDisplayEdgeSettings(source.edges)
  };
}

export function cloneDisplaySettings(value = DEFAULT_DISPLAY_SETTINGS) {
  return normalizeDisplaySettings(value);
}

export function displaySettingsEqual(left, right) {
  const a = normalizeDisplaySettings(left);
  const b = normalizeDisplaySettings(right);
  return a.projection === b.projection &&
    a.mode === b.mode &&
    stepClipSettingsEqual(a.clip, b.clip) &&
    JSON.stringify(a.exploded) === JSON.stringify(b.exploded) &&
    JSON.stringify(a.edges) === JSON.stringify(b.edges);
}

export function resolveDisplayMode(displaySettings) {
  return normalizeDisplaySettings(displaySettings).mode;
}

export function resolveDisplayEdgeSettings(displaySettings) {
  return normalizeDisplaySettings(displaySettings).edges;
}

export function displayModeIsWireframe(value) {
  return normalizeDisplayMode(value) === CAD_DISPLAY_MODE.WIREFRAME;
}

export function displayModeForcesEdges(value) {
  return [
    CAD_DISPLAY_MODE.SOLID,
    CAD_DISPLAY_MODE.TRANSPARENT,
    CAD_DISPLAY_MODE.HIDDEN_EDGES,
    CAD_DISPLAY_MODE.HIDDEN_LINES_REMOVED
  ].includes(normalizeDisplayMode(value));
}

export function displayModeAllowsEdges(value) {
  return ![
    CAD_DISPLAY_MODE.RENDERED,
    CAD_DISPLAY_MODE.UNSHADED
  ].includes(normalizeDisplayMode(value));
}

export function displayModeShowsEdges(value, edgeSettings = null) {
  const mode = normalizeDisplayMode(value);
  return mode === CAD_DISPLAY_MODE.WIREFRAME ||
    displayModeForcesEdges(mode);
}

export function displayModeShowsThroughEdges(value) {
  return [
    CAD_DISPLAY_MODE.TRANSPARENT,
    CAD_DISPLAY_MODE.HIDDEN_EDGES
  ].includes(normalizeDisplayMode(value));
}

export function displayModeUsesTransparentSurfaces(value) {
  return [
    CAD_DISPLAY_MODE.TRANSPARENT,
    CAD_DISPLAY_MODE.HIDDEN_LINES_REMOVED,
    CAD_DISPLAY_MODE.WIREFRAME
  ].includes(normalizeDisplayMode(value));
}

export function displayModeUsesUnlitSurfaces(value) {
  return [
    CAD_DISPLAY_MODE.UNSHADED,
    CAD_DISPLAY_MODE.HIDDEN_LINES_REMOVED,
    CAD_DISPLAY_MODE.WIREFRAME
  ].includes(normalizeDisplayMode(value));
}

export function displayModeSurfaceOpacity(value, fallback = 1) {
  const mode = normalizeDisplayMode(value);
  if (mode === CAD_DISPLAY_MODE.WIREFRAME) {
    return 0.035;
  }
  if (mode === CAD_DISPLAY_MODE.TRANSPARENT) {
    return 0.22;
  }
  if (mode === CAD_DISPLAY_MODE.HIDDEN_LINES_REMOVED) {
    return 0.045;
  }
  const numericFallback = Number(fallback);
  return Number.isFinite(numericFallback) ? numericFallback : 1;
}
