import {
  applyDisplayRecordTransform,
  buildStepClipPlane,
  readBoundsCenter,
  syncMaterialClipPlanes
} from "../../common/cadScene.js";
import {
  clampSceneModelRadius,
  getShadowCameraSettings,
  normalizeSceneScaleMode,
  VIEWER_SCENE_SCALE
} from "./sceneScale.js";

export {
  applyDisplayRecordTransform,
  buildStepClipPlane,
  readBoundsCenter,
  syncMaterialClipPlanes
};

export function toNumber(value, fallback = 0) {
  return Number.isFinite(Number(value)) ? Number(value) : fallback;
}

export function normalizeRuntimeModelKey(value) {
  return String(value ?? "").trim();
}

export function runtimeModelKeyMatches(runtime, modelKey) {
  if (!runtime?.hasVisibleModel) {
    return false;
  }
  const activeModelKey = normalizeRuntimeModelKey(runtime.activeModelKey);
  const currentModelKey = normalizeRuntimeModelKey(modelKey);
  return activeModelKey || currentModelKey
    ? activeModelKey === currentModelKey
    : true;
}

export function resolveRuntimeModelFloorZ(bounds, modelPosition, sceneScaleMode) {
  const positionZ = toNumber(modelPosition?.z);
  if (normalizeSceneScaleMode(sceneScaleMode) === VIEWER_SCENE_SCALE.URDF) {
    return positionZ;
  }
  const boundsMin = Array.isArray(bounds?.min) ? bounds.min : [0, 0, 0];
  return toNumber(boundsMin[2]) + positionZ;
}

export function applyRuntimeModelBounds(THREE, runtime, bounds, sceneScaleMode, {
  shadowMapSize = 2048
} = {}) {
  const boundsMin = Array.isArray(bounds?.min) ? bounds.min : [0, 0, 0];
  const boundsMax = Array.isArray(bounds?.max) ? bounds.max : [0, 0, 0];
  const radius = clampSceneModelRadius(
    new THREE.Vector3(
      toNumber(boundsMax[0]) - toNumber(boundsMin[0]),
      toNumber(boundsMax[1]) - toNumber(boundsMin[1]),
      toNumber(boundsMax[2]) - toNumber(boundsMin[2])
    ).length() / 2,
    sceneScaleMode
  );
  runtime.modelBounds = {
    min: boundsMin,
    max: boundsMax
  };
  runtime.modelRadius = radius;
  if (runtime.keyLight?.shadow?.camera) {
    const keyLightDistance = typeof runtime.keyLight.position?.length === "function"
      ? runtime.keyLight.position.length()
      : 0;
    const shadowSettings = getShadowCameraSettings(sceneScaleMode, {
      radius,
      keyLightDistance
    });
    runtime.keyLight.shadow.mapSize.set(shadowMapSize, shadowMapSize);
    runtime.keyLight.shadow.bias = -0.00025;
    runtime.keyLight.shadow.normalBias = shadowSettings.normalBias;
    runtime.keyLight.shadow.radius = shadowSettings.radius;
    runtime.keyLight.shadow.camera.left = -shadowSettings.extent;
    runtime.keyLight.shadow.camera.right = shadowSettings.extent;
    runtime.keyLight.shadow.camera.top = shadowSettings.extent;
    runtime.keyLight.shadow.camera.bottom = -shadowSettings.extent;
    runtime.keyLight.shadow.camera.near = 0.1;
    runtime.keyLight.shadow.camera.far = shadowSettings.far;
    runtime.keyLight.shadow.camera.updateProjectionMatrix?.();
  }
  return {
    boundsMin,
    boundsMax,
    radius
  };
}

export function syncObjectClipPlanes(object, clipPlanes) {
  if (!object?.traverse) {
    return;
  }
  object.traverse((child) => {
    syncMaterialClipPlanes(child?.material, clipPlanes);
  });
}

export function syncRuntimeStepClipPlane(runtime, clipSettings) {
  if (!runtime?.THREE) {
    return;
  }
  const clipPlane = buildStepClipPlane(
    runtime.THREE,
    clipSettings,
    runtime.modelBounds,
    runtime.modelGroup?.position
  );
  const clipPlanes = clipPlane ? [clipPlane] : [];
  runtime.activeClipPlane = clipPlane;
  runtime.activeClipPlanes = clipPlanes;
  if (runtime.renderer) {
    runtime.renderer.localClippingEnabled = true;
  }
  for (const record of Array.isArray(runtime.displayRecords) ? runtime.displayRecords : []) {
    syncMaterialClipPlanes(record.material, clipPlanes);
    syncMaterialClipPlanes(record.edgeMaterial, clipPlanes);
  }
  syncObjectClipPlanes(runtime.facePickGroup, clipPlanes);
  syncObjectClipPlanes(runtime.edgePickGroup, clipPlanes);
  syncObjectClipPlanes(runtime.vertexPickGroup, clipPlanes);
  syncObjectClipPlanes(runtime.surfaceLineGroup, clipPlanes);
  syncObjectClipPlanes(runtime.topologyDisplayEdgeLine, clipPlanes);
}
