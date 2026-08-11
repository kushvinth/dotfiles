import {
  assemblyUsesSelfContainedMesh,
  buildSelfContainedAssemblyMeshData
} from "../lib/assembly/meshData.js";
import { buildMeshDataFromGlbBuffer } from "../lib/render/glbMeshData.js";
import {
  loadRenderDisplayEdgeBundle,
  loadRenderGlb,
  loadRenderSelectorBundle,
  loadRenderTopologyIndex
} from "../lib/stepRenderAssetClient.js";
import {
  buildDisplayEdgeRuntime,
  buildSelectorRuntime
} from "../lib/selectors/runtime.js";
import {
  isRenderAssetSourceScopeError,
  renderAssetSourceScope,
  renderAssetSourceScopeForJob,
  setRenderAssetSourceScope
} from "../lib/renderAssetSourceScope.js";
import {
  loadStepModuleDefinition
} from "./stepModule.js";
import {
  hasStepParameterRenderValues,
  normalizeStepParameterRenderValues,
  stepParameterRenderFrameState,
  stepParameterRenderFrameValues
} from "./stepParameters.js";

export const SOURCE_KIND = Object.freeze({
  STEP: "step",
  STP: "stp",
  GLB: "glb",
  STL: "stl",
  THREE_MF: "3mf",
  UNKNOWN: "unknown"
});

function isObject(value) {
  return Boolean(value) && typeof value === "object" && !Array.isArray(value);
}

function normalizeKind(value = "") {
  const kind = String(value || "").trim().toLowerCase();
  if (kind === "step" || kind === "stp" || kind === "glb" || kind === "stl" || kind === "3mf") {
    return kind;
  }
  return SOURCE_KIND.UNKNOWN;
}

function sourceKindFromUrl(url = "") {
  const pathname = String(url || "").split(/[?#]/, 1)[0].toLowerCase();
  if (pathname.endsWith(".step")) {
    return SOURCE_KIND.STEP;
  }
  if (pathname.endsWith(".stp")) {
    return SOURCE_KIND.STP;
  }
  if (pathname.endsWith(".glb") || pathname.endsWith(".gltf")) {
    return SOURCE_KIND.GLB;
  }
  if (pathname.endsWith(".stl")) {
    return SOURCE_KIND.STL;
  }
  if (pathname.endsWith(".3mf")) {
    return SOURCE_KIND.THREE_MF;
  }
  return SOURCE_KIND.UNKNOWN;
}

export function sourceIsStep(sourceOrKind) {
  const kind = typeof sourceOrKind === "string" ? sourceOrKind : sourceOrKind?.kind;
  const normalized = normalizeKind(kind);
  return normalized === SOURCE_KIND.STEP || normalized === SOURCE_KIND.STP;
}

function assertStepOnlyOption(kind, value, label) {
  if (value === undefined || value === null) {
    return;
  }
  if (!sourceIsStep(kind)) {
    throw new Error(`${label} is supported only for STEP/STP sources`);
  }
}

async function loadStepMeshFromGlb(glbUrl) {
  const meshData = await loadRenderGlb(glbUrl);
  const topology = await loadRenderTopologyIndex(glbUrl);
  if (assemblyUsesSelfContainedMesh(topology)) {
    return buildSelfContainedAssemblyMeshData(topology, meshData);
  }
  return meshData;
}

async function loadSelectorRuntime(glbUrl, { cadPath = "" } = {}) {
  if (!glbUrl) {
    return null;
  }
  try {
    const selectorBundle = await loadRenderSelectorBundle(glbUrl);
    return buildSelectorRuntime(selectorBundle, {
      copyCadPath: cadPath
    });
  } catch (error) {
    // Missing or unreadable selector topology is a normal condition and degrades to null. A
    // cross-source cache collision is not: swallowing it would render a plausible wrong image at
    // exit 0, which is the failure this scope check exists to make loud.
    if (isRenderAssetSourceScopeError(error)) {
      throw error;
    }
    return null;
  }
}

async function loadDisplayEdgeRuntime(glbUrl) {
  if (!glbUrl) {
    return null;
  }
  try {
    return buildDisplayEdgeRuntime(await loadRenderDisplayEdgeBundle(glbUrl));
  } catch (error) {
    if (isRenderAssetSourceScopeError(error)) {
      throw error;
    }
    return null;
  }
}

async function loadMeshDataFromUrl(url, kind) {
  if (sourceIsStep(kind)) {
    return loadStepMeshFromGlb(url);
  }
  if (kind === SOURCE_KIND.GLB) {
    const response = await fetch(url, { cache: "no-store" });
    if (!response.ok) {
      throw new Error(`Failed to load GLB source: HTTP ${response.status}`);
    }
    return buildMeshDataFromGlbBuffer(await response.arrayBuffer());
  }
  throw new Error(`Unsupported render source kind: ${kind || SOURCE_KIND.UNKNOWN}`);
}

async function loadStepParameters({
  kind,
  stepParameters,
  stepParameterUrl,
  cadPath,
  selectorRuntime
}) {
  assertStepOnlyOption(kind, stepParameters, "stepParameters");
  assertStepOnlyOption(kind, stepParameterUrl, "stepParameterUrl");
  const explicit = hasStepParameterRenderValues(stepParameters);
  if (!stepParameterUrl) {
    if (!explicit) {
      return null;
    }
    throw new Error("STEP render parameters require resolved.stepParameterUrl");
  }
  const definition = await loadStepModuleDefinition(stepParameterUrl, { cadPath });
  const renderParameters = normalizeStepParameterRenderValues(definition, explicit ? stepParameters : {});
  return {
    definition,
    renderParameters,
    selectorRuntime,
    cadPath: cadPath || definition.cadPath || "",
    sourceUrl: stepParameterUrl
  };
}

export function stepParameterFrameRuntime(stepParameterSource, frameIndex = 0) {
  if (!stepParameterSource) {
    return null;
  }
  const { definition, renderParameters } = stepParameterSource;
  return {
    definition,
    selectorRuntime: stepParameterSource.selectorRuntime || null,
    parameterValues: stepParameterRenderFrameValues(definition, renderParameters, frameIndex),
    animationState: stepParameterRenderFrameState(renderParameters, frameIndex),
    cadPath: stepParameterSource.cadPath || definition.cadPath || "",
    sourceUrl: stepParameterSource.sourceUrl || definition.url || ""
  };
}

export async function loadSource(input, options = {}) {
  const inputObject = isObject(input) ? input : {};
  if (Object.prototype.hasOwnProperty.call(inputObject, "params")) {
    throw new Error("Render source jobs use stepParameters; params is no longer a shared render API field");
  }
  const resolved = isObject(inputObject.resolved) ? inputObject.resolved : {};
  const explicitMeshData = inputObject.meshData || options.meshData || (
    inputObject.vertices && inputObject.indices ? inputObject : null
  );
  const rawKind = inputObject.kind || resolved.kind || options.kind || (
    typeof input === "string" ? sourceKindFromUrl(input) : ""
  );
  const kind = normalizeKind(rawKind);
  const stepParameters = inputObject.stepParameters ?? options.stepParameters;
  const stepParameterUrl = String(
    inputObject.stepParameterUrl || resolved.stepParameterUrl || options.stepParameterUrl || ""
  ).trim();
  const cadPath = String(inputObject.cadPath || resolved.inputPath || options.cadPath || "").trim();
  assertStepOnlyOption(kind, stepParameters, "stepParameters");
  assertStepOnlyOption(kind, stepParameterUrl, "stepParameterUrl");

  let meshData = explicitMeshData;
  const glbUrl = String(inputObject.glbUrl || resolved.glbUrl || options.glbUrl || "").trim();
  const url = String(typeof input === "string" ? input : inputObject.url || resolved.url || glbUrl || "").trim();

  // Render asset caches live for the whole page, so every entry a resolved job populates must be
  // tagged with the source it belongs to. This is the only place a resolved job meets those caches,
  // so it is where the scope is declared; the scope is restored afterwards so one job can never
  // leave its identity attached to another caller's loads. Callers with no resolved job keep the
  // unscoped default and are unaffected.
  const previousSourceScope = renderAssetSourceScope();
  if (glbUrl || url) {
    setRenderAssetSourceScope(renderAssetSourceScopeForJob(inputObject));
  }
  try {
    if (!meshData) {
      if (!url) {
        throw new Error("loadSource requires meshData, a source URL, or resolved.glbUrl");
      }
      meshData = await loadMeshDataFromUrl(sourceIsStep(kind) ? glbUrl || url : url, kind);
    }

    const selectorRuntime = inputObject.selectorRuntime || options.selectorRuntime || await loadSelectorRuntime(glbUrl || url, { cadPath });
    const displayEdgeRuntime = inputObject.displayEdgeRuntime || options.displayEdgeRuntime || await loadDisplayEdgeRuntime(glbUrl || url);
    const stepParameterSource = await loadStepParameters({
      kind,
      stepParameters,
      stepParameterUrl,
      cadPath,
      selectorRuntime
    });

    return {
      kind,
      meshData,
      selectorRuntime,
      displayEdgeRuntime,
      stepParameterSource,
      resolved,
      url,
      glbUrl,
      cadPath
    };
  } finally {
    setRenderAssetSourceScope(previousSourceScope);
  }
}
