const DEFAULT_EXTRUSION_WIDTH_MM = 0.42;
const DEFAULT_TRAVEL_WIDTH_MM = 0.08;
const DEFAULT_EXTRUSION_HEIGHT_MM = 0.18;
const DEFAULT_TRAVEL_HEIGHT_MM = 0.04;
export const DEFAULT_GCODE_PREVIEW_SEGMENT_BUDGET = 60000;
export const GCODE_PREVIEW_DETAIL_MIN = 1;
export const GCODE_PREVIEW_DETAIL_MAX = 7;
export const DEFAULT_GCODE_PREVIEW_DETAIL_LEVEL = 3;
const GCODE_PREVIEW_DETAIL_SEGMENT_BUDGETS = Object.freeze({
  1: 25000,
  2: 40000,
  3: DEFAULT_GCODE_PREVIEW_SEGMENT_BUDGET,
  4: 90000,
  5: 140000,
  6: 220000,
  7: 320000
});
const MIN_GCODE_PREVIEW_SEGMENT_BUDGET = 1;
const MIN_SEGMENT_LENGTH_MM = 1e-5;
const GCODE_PREVIEW_Z_LIFT_MM = 0.035;
const DEFAULT_LAYER_COLORS = Object.freeze([
  "#2563eb",
  "#16a34a",
  "#0891b2",
  "#ca8a04",
  "#7c3aed",
  "#0f766e",
  "#4f46e5",
  "#65a30d"
]);
const SUPPORT_COLOR = "#94a3b8";
const TRAVEL_COLOR = "#64748b";
const FEATURE_CATEGORY_Z_BIAS_MM = Object.freeze({
  support: 0.001,
  adhesion: 0.002,
  infill: 0.003,
  calibration: 0.004,
  other: 0.004,
  surface: 0.005,
  wall: 0.006
});
const TRAVEL_Z_BIAS_MM = 0.008;
const RIBBON_VERTICES_PER_SEGMENT = 4;
const RIBBON_INDICES_PER_SEGMENT = 6;
const RIBBON_NORMAL = Object.freeze([0, 0, 1]);

function toFiniteNumber(value, fallback = 0) {
  const numericValue = Number(value);
  return Number.isFinite(numericValue) ? numericValue : fallback;
}

function clamp(value, min, max) {
  return Math.min(Math.max(value, min), max);
}

function normalizeBoolean(value, fallback = false) {
  return typeof value === "boolean" ? value : fallback;
}

function normalizeDetailMode(value) {
  return String(value || "").trim().toLowerCase() === "full" ? "full" : "adaptive";
}

function normalizePreviewDetailLevel(value) {
  return clamp(
    Math.round(toFiniteNumber(value, DEFAULT_GCODE_PREVIEW_DETAIL_LEVEL)),
    GCODE_PREVIEW_DETAIL_MIN,
    GCODE_PREVIEW_DETAIL_MAX
  );
}

function segmentBudgetForPreviewDetailLevel(value) {
  const detailLevel = normalizePreviewDetailLevel(value);
  return GCODE_PREVIEW_DETAIL_SEGMENT_BUDGETS[detailLevel] || DEFAULT_GCODE_PREVIEW_SEGMENT_BUDGET;
}

function coordinate(value, index) {
  return toFiniteNumber(value?.[index]);
}

function emptyBounds() {
  return {
    min: [Infinity, Infinity, Infinity],
    max: [-Infinity, -Infinity, -Infinity]
  };
}

function finalizeBounds(bounds) {
  if (!bounds.min.every(Number.isFinite) || !bounds.max.every(Number.isFinite)) {
    return {
      min: [0, 0, 0],
      max: [1, 1, 1]
    };
  }
  return {
    min: bounds.min,
    max: bounds.max
  };
}

function segmentLength(segment) {
  const start = segment?.start;
  const end = segment?.end;
  return Math.hypot(
    coordinate(end, 0) - coordinate(start, 0),
    coordinate(end, 1) - coordinate(start, 1),
    coordinate(end, 2) - coordinate(start, 2)
  );
}

function normalizeLayerRange(value, layerCount) {
  const maxLayer = Math.max(0, Math.trunc(toFiniteNumber(layerCount, 0)) - 1);
  if (!Array.isArray(value) || value.length < 2) {
    return [0, maxLayer];
  }
  const start = clamp(Math.trunc(toFiniteNumber(value[0], 0)), 0, maxLayer);
  const end = clamp(Math.trunc(toFiniteNumber(value[1], maxLayer)), 0, maxLayer);
  return start <= end ? [start, end] : [end, start];
}

export function normalizeGcodePreviewOptions(options = {}, layerCount = 0) {
  const source = options && typeof options === "object" ? options : {};
  const detailMode = normalizeDetailMode(source.detailMode);
  const detailLevel = normalizePreviewDetailLevel(source.detailLevel);
  const defaultSegmentBudget = segmentBudgetForPreviewDetailLevel(detailLevel);
  const explicitRange = Array.isArray(source.layerRange)
    ? source.layerRange
    : Number.isFinite(Number(source.maxLayer))
      ? [0, Number(source.maxLayer)]
      : null;
  return {
    showTravel: normalizeBoolean(source.showTravel, false),
    layerRange: normalizeLayerRange(explicitRange, layerCount),
    detailMode,
    detailLevel,
    maxVisibleSegments: detailMode === "full"
      ? 0
      : Math.max(
        Math.trunc(toFiniteNumber(source.maxVisibleSegments, defaultSegmentBudget)),
        MIN_GCODE_PREVIEW_SEGMENT_BUDGET
      ),
    extrusionWidthMm: Math.max(toFiniteNumber(source.extrusionWidthMm, DEFAULT_EXTRUSION_WIDTH_MM), 0.01),
    travelWidthMm: Math.max(toFiniteNumber(source.travelWidthMm, DEFAULT_TRAVEL_WIDTH_MM), 0.01),
    extrusionHeightMm: Math.max(toFiniteNumber(source.extrusionHeightMm, DEFAULT_EXTRUSION_HEIGHT_MM), 0.01),
    travelHeightMm: Math.max(toFiniteNumber(source.travelHeightMm, DEFAULT_TRAVEL_HEIGHT_MM), 0.01)
  };
}

function layerColor(layerIndex) {
  const index = Math.max(0, Math.trunc(toFiniteNumber(layerIndex, 0)));
  return DEFAULT_LAYER_COLORS[index % DEFAULT_LAYER_COLORS.length];
}

function segmentGroupKey(segment) {
  if (segment.kind === "travel") {
    return "travel";
  }
  return `layer:${Math.max(0, Math.trunc(toFiniteNumber(segment.layerIndex, 0)))}`;
}

function groupLabel(key, layerIndex) {
  if (key === "travel") {
    return "Travel";
  }
  return `Layer ${Math.max(0, Math.trunc(toFiniteNumber(layerIndex, 0))) + 1}`;
}

function colorToRgb(color) {
  const normalized = String(color || "").trim();
  const expanded = /^#[0-9a-fA-F]{3}$/.test(normalized)
    ? `#${normalized[1]}${normalized[1]}${normalized[2]}${normalized[2]}${normalized[3]}${normalized[3]}`
    : normalized;
  if (!/^#[0-9a-fA-F]{6}$/.test(expanded)) {
    return [1, 1, 1];
  }
  return [
    parseInt(expanded.slice(1, 3), 16) / 255,
    parseInt(expanded.slice(3, 5), 16) / 255,
    parseInt(expanded.slice(5, 7), 16) / 255
  ];
}

function visibleSegmentMatches(segment, options) {
  const layerIndex = Math.max(0, Math.trunc(toFiniteNumber(segment?.layerIndex, 0)));
  const [minLayer, maxLayer] = options.layerRange;
  if (layerIndex < minLayer || layerIndex > maxLayer) {
    return false;
  }
  if (segment?.kind === "travel") {
    return options.showTravel;
  }
  return segment?.kind === "extrusion";
}

function analyzeVisibleSegments(gcodeData, options) {
  const segments = Array.isArray(gcodeData?.segments) ? gcodeData.segments : [];
  const segmentsByLayer = new Map();
  let visibleSegmentCount = 0;
  for (const segment of segments) {
    if (!visibleSegmentMatches(segment, options) || segmentLength(segment) <= MIN_SEGMENT_LENGTH_MM) {
      continue;
    }
    const layerIndex = Math.max(0, Math.trunc(toFiniteNumber(segment?.layerIndex, 0)));
    segmentsByLayer.set(layerIndex, (segmentsByLayer.get(layerIndex) || 0) + 1);
    visibleSegmentCount += 1;
  }
  return {
    visibleSegmentCount,
    segmentsByLayer
  };
}

function includeLayerForStride(layerIndex, minLayer, maxLayer, layerStride) {
  if (layerStride <= 1) {
    return true;
  }
  return (
    layerIndex === minLayer ||
    layerIndex === maxLayer ||
    (layerIndex - minLayer) % layerStride === 0
  );
}

function countSegmentsForLayerStride(segmentsByLayer, minLayer, maxLayer, layerStride) {
  let count = 0;
  for (const [layerIndex, segmentCount] of segmentsByLayer.entries()) {
    if (layerIndex >= minLayer && layerIndex <= maxLayer && includeLayerForStride(layerIndex, minLayer, maxLayer, layerStride)) {
      count += segmentCount;
    }
  }
  return count;
}

function layerStrideForBudget(segmentsByLayer, visibleSegmentCount, options) {
  const budget = Math.trunc(toFiniteNumber(options?.maxVisibleSegments, 0));
  if (options?.detailMode === "full" || budget <= 0 || visibleSegmentCount <= budget) {
    return 1;
  }
  const [minLayer, maxLayer] = options.layerRange;
  const visibleLayerCount = Math.max(1, maxLayer - minLayer + 1);
  for (let layerStride = 2; layerStride <= visibleLayerCount; layerStride += 1) {
    if (countSegmentsForLayerStride(segmentsByLayer, minLayer, maxLayer, layerStride) <= budget) {
      return layerStride;
    }
  }
  return visibleLayerCount;
}

function countRenderedLayers(segmentsByLayer, minLayer, maxLayer, layerStride) {
  let count = 0;
  for (const layerIndex of segmentsByLayer.keys()) {
    if (layerIndex >= minLayer && layerIndex <= maxLayer && includeLayerForStride(layerIndex, minLayer, maxLayer, layerStride)) {
      count += 1;
    }
  }
  return count;
}

function updateBoundsFromCoordinates(bounds, x, y, z) {
  bounds.min[0] = Math.min(bounds.min[0], x);
  bounds.min[1] = Math.min(bounds.min[1], y);
  bounds.min[2] = Math.min(bounds.min[2], z);
  bounds.max[0] = Math.max(bounds.max[0], x);
  bounds.max[1] = Math.max(bounds.max[1], y);
  bounds.max[2] = Math.max(bounds.max[2], z);
}

function updateSegmentBounds(bounds, segment) {
  updateBoundsFromCoordinates(
    bounds,
    coordinate(segment?.start, 0),
    coordinate(segment?.start, 1),
    coordinate(segment?.start, 2)
  );
  updateBoundsFromCoordinates(
    bounds,
    coordinate(segment?.end, 0),
    coordinate(segment?.end, 1),
    coordinate(segment?.end, 2)
  );
}

function segmentColor(segment, key, layerIndex) {
  if (key === "travel") {
    return TRAVEL_COLOR;
  }
  if (segment?.featureCategory === "support") {
    return SUPPORT_COLOR;
  }
  return layerColor(layerIndex);
}

function segmentZOffset(segment) {
  if (segment?.kind === "travel") {
    return GCODE_PREVIEW_Z_LIFT_MM + TRAVEL_Z_BIAS_MM;
  }
  const category = String(segment?.featureCategory || "other").trim().toLowerCase();
  return GCODE_PREVIEW_Z_LIFT_MM + (FEATURE_CATEGORY_Z_BIAS_MM[category] ?? FEATURE_CATEGORY_Z_BIAS_MM.other);
}

function writeRibbonVertex({ vertices, colors, normals, bounds, offset, x, y, z, zOffset = 0, color }) {
  vertices[offset] = x;
  vertices[offset + 1] = y;
  vertices[offset + 2] = z + zOffset;
  colors[offset] = color[0];
  colors[offset + 1] = color[1];
  colors[offset + 2] = color[2];
  normals[offset] = RIBBON_NORMAL[0];
  normals[offset + 1] = RIBBON_NORMAL[1];
  normals[offset + 2] = RIBBON_NORMAL[2];
  updateBoundsFromCoordinates(bounds, x, y, z + zOffset);
}

function writeSegmentRibbon({ vertices, indices, colors, normals, bounds, segment, segmentIndex, width, color, zOffset }) {
  const start = segment?.start;
  const end = segment?.end;
  const startX = coordinate(start, 0);
  const startY = coordinate(start, 1);
  const startZ = coordinate(start, 2);
  const endX = coordinate(end, 0);
  const endY = coordinate(end, 1);
  const endZ = coordinate(end, 2);
  const dx = endX - startX;
  const dy = endY - startY;
  const dz = endZ - startZ;
  const length = Math.hypot(dx, dy, dz);
  if (!(length > MIN_SEGMENT_LENGTH_MM)) {
    return null;
  }
  let nx = -dy;
  let ny = dx;
  let normalLength = Math.hypot(nx, ny);
  if (!(normalLength > MIN_SEGMENT_LENGTH_MM)) {
    nx = 1;
    ny = 0;
    normalLength = 1;
  }
  const halfWidth = width / 2;
  const offsetX = (nx / normalLength) * halfWidth;
  const offsetY = (ny / normalLength) * halfWidth;
  const vertexBase = segmentIndex * RIBBON_VERTICES_PER_SEGMENT;
  const vertexOffset = vertexBase * 3;

  writeRibbonVertex({
    vertices,
    colors,
    normals,
    bounds,
    offset: vertexOffset,
    x: startX + offsetX,
    y: startY + offsetY,
    z: startZ,
    zOffset,
    color
  });
  writeRibbonVertex({
    vertices,
    colors,
    normals,
    bounds,
    offset: vertexOffset + 3,
    x: startX - offsetX,
    y: startY - offsetY,
    z: startZ,
    zOffset,
    color
  });
  writeRibbonVertex({
    vertices,
    colors,
    normals,
    bounds,
    offset: vertexOffset + 6,
    x: endX - offsetX,
    y: endY - offsetY,
    z: endZ,
    zOffset,
    color
  });
  writeRibbonVertex({
    vertices,
    colors,
    normals,
    bounds,
    offset: vertexOffset + 9,
    x: endX + offsetX,
    y: endY + offsetY,
    z: endZ,
    zOffset,
    color
  });

  const indexOffset = segmentIndex * RIBBON_INDICES_PER_SEGMENT;
  indices[indexOffset] = vertexBase;
  indices[indexOffset + 1] = vertexBase + 1;
  indices[indexOffset + 2] = vertexBase + 2;
  indices[indexOffset + 3] = vertexBase;
  indices[indexOffset + 4] = vertexBase + 2;
  indices[indexOffset + 5] = vertexBase + 3;
  return true;
}

export function buildGcodePreviewMeshData(gcodeData, options = {}) {
  const layers = Array.isArray(gcodeData?.layers) ? gcodeData.layers : [];
  const normalized = normalizeGcodePreviewOptions(options, layers.length);
  const segments = Array.isArray(gcodeData?.segments) ? gcodeData.segments : [];
  const { visibleSegmentCount, segmentsByLayer } = analyzeVisibleSegments(gcodeData, normalized);
  const layerStride = layerStrideForBudget(segmentsByLayer, visibleSegmentCount, normalized);
  const [minLayer, maxLayer] = normalized.layerRange;
  const renderedSegmentCapacity = countSegmentsForLayerStride(segmentsByLayer, minLayer, maxLayer, layerStride);
  const renderedLayerCount = countRenderedLayers(segmentsByLayer, minLayer, maxLayer, layerStride);
  const vertices = new Float32Array(renderedSegmentCapacity * RIBBON_VERTICES_PER_SEGMENT * 3);
  const indices = new Uint32Array(renderedSegmentCapacity * RIBBON_INDICES_PER_SEGMENT);
  const colors = new Float32Array(vertices.length);
  const normals = new Float32Array(vertices.length);
  const parts = [];
  const geometryBounds = emptyBounds();
  const rawBounds = emptyBounds();
  let currentGroup = null;
  let writtenSegments = 0;

  for (const segment of segments) {
    if (!visibleSegmentMatches(segment, normalized) || segmentLength(segment) <= MIN_SEGMENT_LENGTH_MM) {
      continue;
    }
    const key = segmentGroupKey(segment);
    const layerIndex = Math.max(0, Math.trunc(toFiniteNumber(segment?.layerIndex, 0)));
    if (!includeLayerForStride(layerIndex, minLayer, maxLayer, layerStride)) {
      continue;
    }
    updateSegmentBounds(rawBounds, segment);
    if (!currentGroup || currentGroup.key !== key) {
      currentGroup = {
        key,
        layerIndex,
        vertexOffset: writtenSegments * RIBBON_VERTICES_PER_SEGMENT,
        triangleOffset: writtenSegments * 2,
        segmentCount: 0
      };
      parts.push(currentGroup);
    }
    const added = writeSegmentRibbon({
      vertices,
      indices,
      colors,
      normals,
      bounds: geometryBounds,
      segment,
      segmentIndex: writtenSegments,
      width: segment.kind === "travel" ? normalized.travelWidthMm : normalized.extrusionWidthMm,
      color: colorToRgb(segmentColor(segment, key, layerIndex)),
      zOffset: segmentZOffset(segment)
    });
    if (added) {
      currentGroup.segmentCount += 1;
      writtenSegments += 1;
    }
  }

  const finalizedParts = parts
    .map((part, index) => {
      const nextVertexOffset = parts[index + 1]?.vertexOffset ?? writtenSegments * RIBBON_VERTICES_PER_SEGMENT;
      const nextTriangleOffset = parts[index + 1]?.triangleOffset ?? writtenSegments * 2;
      return {
        id: part.key === "travel" ? `gcode:travel:${index}` : `gcode:layer:${part.layerIndex}:${index}`,
        label: groupLabel(part.key, part.layerIndex),
        vertexOffset: part.vertexOffset,
        vertexCount: Math.max(0, nextVertexOffset - part.vertexOffset),
        triangleOffset: part.triangleOffset,
        triangleCount: Math.max(0, nextTriangleOffset - part.triangleOffset),
        bounds: finalizeBounds(rawBounds),
        segmentCount: part.segmentCount
      };
    })
    .filter((part) => part.vertexCount > 0 && part.triangleCount > 0);

  const finalBounds = finalizeBounds(rawBounds);
  return {
    vertices,
    indices,
    normals,
    colors,
    bounds: finalBounds,
    parts: finalizedParts,
    has_source_colors: true,
    sourceFormat: "gcode",
    sourceColor: "#2563eb",
    metadata: {
      kind: "gcode",
      previewGeometry: "ribbon",
      options: normalized,
      visibleSegments: visibleSegmentCount,
      renderedSegments: writtenSegments,
      visibleLayers: Math.max(0, maxLayer - minLayer + 1),
      renderedLayers: renderedLayerCount,
      layerStride,
      segmentStride: 1,
      decimationMode: layerStride > 1 ? "layers" : "none",
      decimated: layerStride > 1,
      stats: gcodeData?.stats || {},
      features: Array.isArray(gcodeData?.features) ? gcodeData.features : [],
      warnings: Array.isArray(gcodeData?.warnings) ? gcodeData.warnings : []
    }
  };
}
