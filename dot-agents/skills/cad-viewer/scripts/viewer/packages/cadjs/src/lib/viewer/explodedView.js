import { MAX_EXPLODED_VIEW_DEPTH, normalizeExplodedViewSettings } from "../../common/displaySettings.js";

const EPSILON = 1e-6;
const GOLDEN_ANGLE = Math.PI * (3 - Math.sqrt(5));
const AXIS_INDEX = Object.freeze({ x: 0, y: 1, z: 2 });

function clamp(value, min, max) {
  return Math.min(Math.max(value, min), max);
}

function toNumber(value, fallback = 0) {
  const numericValue = Number(value);
  return Number.isFinite(numericValue) ? numericValue : fallback;
}

function boundsCenter(THREE, bounds, fallback = null) {
  const min = Array.isArray(bounds?.min) || ArrayBuffer.isView(bounds?.min) ? bounds.min : null;
  const max = Array.isArray(bounds?.max) || ArrayBuffer.isView(bounds?.max) ? bounds.max : null;
  if (!min || !max) {
    return fallback?.clone?.() || new THREE.Vector3();
  }
  return new THREE.Vector3(
    (toNumber(min[0]) + toNumber(max[0])) / 2,
    (toNumber(min[1]) + toNumber(max[1])) / 2,
    (toNumber(min[2]) + toNumber(max[2])) / 2
  );
}

function boundsRadius(THREE, bounds) {
  const min = Array.isArray(bounds?.min) || ArrayBuffer.isView(bounds?.min) ? bounds.min : null;
  const max = Array.isArray(bounds?.max) || ArrayBuffer.isView(bounds?.max) ? bounds.max : null;
  if (!min || !max) {
    return 0;
  }
  return new THREE.Vector3(
    Math.max(toNumber(max[0]) - toNumber(min[0]), 0),
    Math.max(toNumber(max[1]) - toNumber(min[1]), 0),
    Math.max(toNumber(max[2]) - toNumber(min[2]), 0)
  ).length() / 2;
}

function boundsSize(bounds, axis) {
  const min = Array.isArray(bounds?.min) || ArrayBuffer.isView(bounds?.min) ? bounds.min : null;
  const max = Array.isArray(bounds?.max) || ArrayBuffer.isView(bounds?.max) ? bounds.max : null;
  if (!min || !max) {
    return 0;
  }
  return Math.max(toNumber(max[axis]) - toNumber(min[axis]), 0);
}

function boundsMaxSize(bounds) {
  return Math.max(
    boundsSize(bounds, 0),
    boundsSize(bounds, 1),
    boundsSize(bounds, 2)
  );
}

function shiftedBounds(bounds, translation = [0, 0, 0], amount = 1) {
  if (!bounds || !Array.isArray(bounds.min) || !Array.isArray(bounds.max)) {
    return null;
  }
  return {
    min: bounds.min.map((value, index) => toNumber(value) + toNumber(translation[index]) * amount),
    max: bounds.max.map((value, index) => toNumber(value) + toNumber(translation[index]) * amount)
  };
}

function mergeBounds(boundsList) {
  const min = [Infinity, Infinity, Infinity];
  const max = [-Infinity, -Infinity, -Infinity];
  let count = 0;
  for (const bounds of Array.isArray(boundsList) ? boundsList : []) {
    if (!bounds || !Array.isArray(bounds.min) || !Array.isArray(bounds.max)) {
      continue;
    }
    count += 1;
    for (let axis = 0; axis < 3; axis += 1) {
      min[axis] = Math.min(min[axis], toNumber(bounds.min[axis]));
      max[axis] = Math.max(max[axis], toNumber(bounds.max[axis]));
    }
  }
  return count > 0 && min.every(Number.isFinite) && max.every(Number.isFinite) ? { min, max } : null;
}

function translationVector(THREE, value, fallback = null) {
  if (value?.isVector3) {
    return value;
  }
  if (Array.isArray(value) || ArrayBuffer.isView(value)) {
    return new THREE.Vector3(
      toNumber(value[0]),
      toNumber(value[1]),
      toNumber(value[2])
    );
  }
  return fallback;
}

function occurrenceSegments(partId) {
  const text = String(partId || "").trim();
  const match = text.match(/^o\d+(?:\.\d+)*/i);
  return match ? match[0].split(".").filter(Boolean) : [];
}

function commonOccurrencePrefix(records = []) {
  const paths = records
    .map((record) => occurrenceSegments(record?.partId))
    .filter((segments) => segments.length > 1);
  if (!paths.length) {
    return [];
  }
  const prefix = [];
  const shortest = Math.min(...paths.map((segments) => segments.length));
  for (let index = 0; index < shortest; index += 1) {
    const value = paths[0][index];
    if (!paths.every((segments) => segments[index] === value)) {
      break;
    }
    prefix.push(value);
  }
  return prefix.length >= shortest ? prefix.slice(0, -1) : prefix;
}

export function explodedViewGroupKey(partId, {
  depth = 1,
  commonPrefix = []
} = {}) {
  const text = String(partId || "").trim();
  const segments = occurrenceSegments(text);
  if (!segments.length) {
    return text;
  }
  const safeDepth = Math.max(1, Math.min(Math.round(Number(depth)) || 1, MAX_EXPLODED_VIEW_DEPTH));
  const prefixLength = Math.min(commonPrefix.length, Math.max(segments.length - 1, 0));
  const groupLength = Math.min(segments.length, prefixLength + safeDepth);
  return segments.slice(0, groupLength).join(".") || text;
}

function recordCanExplode(record) {
  const partId = String(record?.partId || "").trim();
  return Boolean(record?.mesh && partId && partId !== "__model__");
}

function groupRecords(THREE, records, settings) {
  const commonPrefix = commonOccurrencePrefix(records);
  const groupsByKey = new Map();
  records.forEach((record, recordIndex) => {
    const groupKey = explodedViewGroupKey(record?.partId, {
      depth: settings.depth,
      commonPrefix
    }) || String(record?.partId || `part:${recordIndex}`);
    const bounds = record?.partBounds && Array.isArray(record.partBounds.min) && Array.isArray(record.partBounds.max)
      ? record.partBounds
      : null;
    const existing = groupsByKey.get(groupKey) || {
      key: groupKey,
      records: [],
      recordIndex,
      boundsList: []
    };
    existing.records.push(record);
    if (bounds) {
      existing.boundsList.push(bounds);
    }
    groupsByKey.set(groupKey, existing);
  });
  return [...groupsByKey.values()].map((group) => {
    const bounds = mergeBounds(group.boundsList) || group.records[0]?.partBounds || null;
    return {
      ...group,
      bounds,
      center: boundsCenter(THREE, bounds),
      radius: boundsRadius(THREE, bounds)
    };
  });
}

function createAxisVector(THREE, axis, direction) {
  const vector = new THREE.Vector3();
  vector.setComponent(AXIS_INDEX[axis] ?? 2, direction === "negative" ? -1 : 1);
  return vector;
}

function fallbackDirection(THREE, index, count) {
  const normalizedCount = Math.max(1, count);
  const y = normalizedCount > 1
    ? 1 - ((index + 0.5) / normalizedCount) * 2
    : 0;
  const radius = Math.sqrt(Math.max(0, 1 - y * y));
  const angle = index * GOLDEN_ANGLE;
  const vector = new THREE.Vector3(
    Math.cos(angle) * radius,
    Math.sin(angle) * radius,
    y
  );
  if (vector.lengthSq() <= EPSILON) {
    vector.set(1, 0, 0);
  }
  return vector.normalize();
}

function radialGroupDirection(THREE, group, modelCenter, index, count, direction) {
  const vector = group.center?.isVector3
    ? group.center.clone().sub(modelCenter)
    : new THREE.Vector3();
  if (vector.lengthSq() <= EPSILON) {
    vector.copy(fallbackDirection(THREE, index, count));
  } else {
    vector.normalize();
  }
  return direction === "negative" ? vector.multiplyScalar(-1) : vector;
}

function createRadialExplodedViewRecordStates(THREE, groups, bounds, settings) {
  const modelCenter = boundsCenter(THREE, bounds);
  const modelRadius = Math.max(boundsRadius(THREE, bounds), EPSILON);
  const modelMaxSize = Math.max(boundsMaxSize(bounds), EPSILON);
  const spacing = Math.max(toNumber(settings.spacing, 1.45), 0.25);
  const baseDistance = Math.max(modelRadius * 0.32 * spacing, modelRadius * 0.12);
  const states = [];
  const radialGroups = groups
    .filter((group) => group.records.length > 0 && group.bounds)
    .sort((left, right) => left.recordIndex - right.recordIndex);

  radialGroups.forEach((group, groupIndex) => {
    const direction = radialGroupDirection(
      THREE,
      group,
      modelCenter,
      groupIndex,
      radialGroups.length,
      settings.direction
    );
    const groupRadius = boundsRadius(THREE, group.bounds);
    const travel = baseDistance + Math.min(groupRadius * 0.18 * spacing, modelRadius * 0.2 * spacing);
    const translation = direction.clone().multiplyScalar(travel);
    for (const record of group.records) {
      states.push({
        record,
        partId: String(record.partId || "").trim(),
        groupKey: group.key,
        layerIndex: groupIndex,
        direction: direction.clone(),
        distance: travel,
        translation: translation.clone(),
        matrix: new THREE.Matrix4()
      });
    }
  });

  if (settings.keepBaseGrounded !== false) {
    const baseMin = Array.isArray(bounds?.min) || ArrayBuffer.isView(bounds?.min) ? bounds.min : null;
    const baseMinZ = baseMin ? toNumber(baseMin[2]) : null;
    const explodedBounds = mergeBounds(
      states.map((state) => shiftedBounds(state.record?.partBounds, state.translation.toArray(), 1))
    );
    const explodedMinZ = Array.isArray(explodedBounds?.min) ? toNumber(explodedBounds.min[2]) : null;
    if (
      Number.isFinite(baseMinZ) &&
      Number.isFinite(explodedMinZ) &&
      explodedMinZ < baseMinZ - EPSILON
    ) {
      const lift = Math.min(baseMinZ - explodedMinZ, modelMaxSize * spacing);
      for (const state of states) {
        state.translation.z += lift;
        state.distance = state.translation.length();
        state.direction = state.distance > EPSILON
          ? state.translation.clone().normalize()
          : state.direction;
      }
    }
  }

  return states;
}

export function createExplodedViewRecordStates(THREE, records = [], bounds = null, options = {}) {
  if (!THREE?.Vector3 || !THREE?.Matrix4) {
    return [];
  }
  const settings = normalizeExplodedViewSettings(options);
  const radialAxis = settings.axis === "radial";
  const axisIndex = AXIS_INDEX[settings.axis] ?? 2;
  const explodableRecords = (Array.isArray(records) ? records : []).filter(recordCanExplode);
  if (explodableRecords.length < 2) {
    return [];
  }

  const modelRadius = Math.max(boundsRadius(THREE, bounds), EPSILON);
  const modelSpan = Math.max(boundsSize(bounds, axisIndex), EPSILON);
  const baseGroups = groupRecords(THREE, explodableRecords, settings)
    .filter((group) => group.records.length > 0 && group.bounds);
  if (baseGroups.length < 2) {
    return [];
  }
  if (radialAxis) {
    return createRadialExplodedViewRecordStates(THREE, baseGroups, bounds, settings);
  }

  const groups = baseGroups
    .sort((left, right) => {
      const leftCenter = toNumber(left.center?.getComponent?.(axisIndex));
      const rightCenter = toNumber(right.center?.getComponent?.(axisIndex));
      if (Math.abs(leftCenter - rightCenter) > EPSILON) {
        return leftCenter - rightCenter;
      }
      return left.recordIndex - right.recordIndex;
    });
  const maxGroupThickness = Math.max(
    ...groups.map((group) => boundsSize(group.bounds, axisIndex)),
    modelSpan * 0.08,
    EPSILON
  );
  const sortedThicknesses = groups
    .map((group) => boundsSize(group.bounds, axisIndex))
    .filter((value) => value > EPSILON)
    .sort((left, right) => left - right);
  const medianGroupThickness = sortedThicknesses.length
    ? sortedThicknesses[Math.floor(sortedThicknesses.length / 2)]
    : maxGroupThickness;
  const layerTolerance = Math.max(modelSpan * 0.025, maxGroupThickness * 0.18, EPSILON);
  const spacing = Math.max(toNumber(settings.spacing, 1.45), 0.25);
  const minimumGap = Math.max(modelSpan * 0.075, medianGroupThickness * 0.35, modelRadius * 0.035, EPSILON) * spacing;
  const axisVector = createAxisVector(THREE, settings.axis, settings.direction);

  const layers = [];
  for (const group of groups) {
    const groupCenter = toNumber(group.center.getComponent(axisIndex));
    const previousLayer = layers[layers.length - 1];
    if (settings.mergeCoplanar === true && previousLayer && Math.abs(groupCenter - previousLayer.center) <= layerTolerance) {
      previousLayer.groups.push(group);
      previousLayer.bounds = mergeBounds([previousLayer.bounds, group.bounds]) || previousLayer.bounds;
      previousLayer.center = (previousLayer.center * (previousLayer.groups.length - 1) + groupCenter) / previousLayer.groups.length;
    } else {
      layers.push({
        center: groupCenter,
        bounds: group.bounds,
        groups: [group]
      });
    }
  }

  const layerGap = (previousLayer, layer) => {
    const previousThickness = previousLayer ? boundsSize(previousLayer.bounds, axisIndex) : medianGroupThickness;
    const currentThickness = layer ? boundsSize(layer.bounds, axisIndex) : medianGroupThickness;
    return Math.max(minimumGap, Math.min(previousThickness, currentThickness) * 0.22 * spacing);
  };

  let previousMax = null;
  let previousLayer = null;
  const states = [];
  layers.forEach((layer, layerIndex) => {
    const layerMin = toNumber(layer.bounds.min[axisIndex]);
    const layerMax = toNumber(layer.bounds.max[axisIndex]);
    let axisDistance = 0;
    if (settings.keepBaseGrounded !== false && layerIndex === 0) {
      axisDistance = 0;
      previousMax = layerMax;
    } else {
      const targetMin = previousMax === null ? layerMin : previousMax + layerGap(previousLayer, layer);
      axisDistance = Math.max(0, targetMin - layerMin);
      previousMax = layerMax + axisDistance;
    }
    previousLayer = layer;

    for (const group of layer.groups) {
      const translation = axisVector.clone().multiplyScalar(axisDistance);
      for (const record of group.records) {
        states.push({
          record,
          partId: String(record.partId || "").trim(),
          groupKey: group.key,
          layerIndex,
          direction: translation.lengthSq() > EPSILON ? translation.clone().normalize() : axisVector.clone(),
          distance: translation.length(),
          translation,
          matrix: new THREE.Matrix4()
        });
      }
    }
  });
  return states;
}

export function explodedViewStateTranslationAtProgress(THREE, state, progress = 0) {
  if (!THREE?.Vector3) {
    return null;
  }
  const amount = clamp(toNumber(progress), 0, 1);
  const targetTranslation = translationVector(
    THREE,
    state?.toTranslation,
    translationVector(
      THREE,
      state?.translation,
      new THREE.Vector3(0, 0, toNumber(state?.distance))
    )
  );
  const fromTranslation = translationVector(THREE, state?.fromTranslation, null);
  if (!fromTranslation && amount <= EPSILON) {
    return null;
  }
  const x = fromTranslation
    ? fromTranslation.x + (targetTranslation.x - fromTranslation.x) * amount
    : targetTranslation.x * amount;
  const y = fromTranslation
    ? fromTranslation.y + (targetTranslation.y - fromTranslation.y) * amount
    : targetTranslation.y * amount;
  const z = fromTranslation
    ? fromTranslation.z + (targetTranslation.z - fromTranslation.z) * amount
    : targetTranslation.z * amount;
  if (
    fromTranslation &&
    Math.abs(x) <= EPSILON &&
    Math.abs(y) <= EPSILON &&
    Math.abs(z) <= EPSILON
  ) {
    return null;
  }
  return new THREE.Vector3(x, y, z);
}

export function applyExplodedViewProgress(THREE, states = [], progress = 0) {
  for (const state of Array.isArray(states) ? states : []) {
    const record = state?.record;
    if (!record) {
      continue;
    }
    const translation = explodedViewStateTranslationAtProgress(THREE, state, progress);
    if (!translation) {
      record.explodedViewMatrix = null;
      continue;
    }
    const matrix = state.matrix instanceof THREE.Matrix4 ? state.matrix : new THREE.Matrix4();
    matrix.makeTranslation(translation.x, translation.y, translation.z);
    state.matrix = matrix;
    record.explodedViewMatrix = matrix;
  }
}

export function clearExplodedViewRecords(records = []) {
  for (const record of Array.isArray(records) ? records : []) {
    if (record) {
      record.explodedViewMatrix = null;
    }
  }
}

export function explodedViewBoundsFromStates(THREE, states = [], fallbackBounds = null, progress = 1) {
  if (!THREE?.Vector3) {
    return fallbackBounds;
  }
  const amount = clamp(toNumber(progress), 0, 1);
  const boundsList = (Array.isArray(states) ? states : [])
    .map((state) => shiftedBounds(state?.record?.partBounds, state?.translation?.toArray?.() || [0, 0, 0], amount));
  return mergeBounds(boundsList) || fallbackBounds;
}

export function easeExplodedViewProgress(value) {
  const amount = clamp(toNumber(value), 0, 1);
  return 1 - (1 - amount) ** 3;
}
