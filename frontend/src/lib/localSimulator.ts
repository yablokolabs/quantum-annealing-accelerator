export interface SimulationConfig {
  numSpins: number;
  temperature: number;
  coolingRate: number;
  schedule: "linear" | "exponential" | "adaptive";
  problemType: "max-cut-ring" | "max-cut-complete" | "random";
}

export interface SimulationState {
  spins: Int8Array;
  energy: number;
  temperature: number;
  step: number;
  bestEnergy: number;
  bestSpins: Int8Array;
  history: { step: number; energy: number; temperature: number }[];
  converged: boolean;
}

function generateCouplings(
  n: number,
  problemType: SimulationConfig["problemType"]
): Float64Array {
  const J = new Float64Array(n * n);
  if (problemType === "max-cut-ring") {
    for (let i = 0; i < n; i++) {
      const j = (i + 1) % n;
      J[i * n + j] = -1;
      J[j * n + i] = -1;
    }
  } else if (problemType === "max-cut-complete") {
    for (let i = 0; i < n; i++) {
      for (let j = i + 1; j < n; j++) {
        J[i * n + j] = -1;
        J[j * n + i] = -1;
      }
    }
  } else {
    for (let i = 0; i < n; i++) {
      for (let j = i + 1; j < n; j++) {
        const val = Math.random() * 2 - 1;
        J[i * n + j] = val;
        J[j * n + i] = val;
      }
    }
  }
  return J;
}

function computeEnergy(spins: Int8Array, J: Float64Array, n: number): number {
  let energy = 0;
  for (let i = 0; i < n; i++) {
    for (let j = i + 1; j < n; j++) {
      energy += J[i * n + j] * spins[i] * spins[j];
    }
  }
  return energy;
}

function localField(
  spins: Int8Array,
  J: Float64Array,
  n: number,
  idx: number
): number {
  let h = 0;
  for (let j = 0; j < n; j++) {
    if (j !== idx) h += J[idx * n + j] * spins[j];
  }
  return h;
}

export function createSimulator(config: SimulationConfig) {
  const n = config.numSpins;
  const J = generateCouplings(n, config.problemType);
  const spins = new Int8Array(n);
  for (let i = 0; i < n; i++) spins[i] = Math.random() < 0.5 ? 1 : -1;

  let temperature = config.temperature;
  let step = 0;
  let energy = computeEnergy(spins, J, n);
  let bestEnergy = energy;
  const bestSpins = new Int8Array(spins);
  const history: SimulationState["history"] = [
    { step: 0, energy, temperature },
  ];
  let stagnantCount = 0;
  let lastBestEnergy = energy;

  function coolTemperature() {
    if (config.schedule === "linear") {
      temperature = Math.max(0.001, temperature - config.coolingRate);
    } else if (config.schedule === "exponential") {
      temperature *= 1 - config.coolingRate;
      if (temperature < 0.001) temperature = 0.001;
    } else {
      if (stagnantCount > 20) {
        temperature *= 1.5;
        stagnantCount = 0;
      } else {
        temperature *= 1 - config.coolingRate;
        if (temperature < 0.001) temperature = 0.001;
      }
    }
  }

  function doStep(): SimulationState {
    for (let sweep = 0; sweep < n; sweep++) {
      const idx = Math.floor(Math.random() * n);
      const h = localField(spins, J, n, idx);
      const dE = 2 * spins[idx] * h;
      if (dE < 0 || Math.random() < Math.exp(-dE / temperature)) {
        spins[idx] *= -1;
        energy += dE;
      }
    }

    step++;
    coolTemperature();

    if (energy < bestEnergy) {
      bestEnergy = energy;
      bestSpins.set(spins);
      stagnantCount = 0;
    } else {
      stagnantCount++;
    }

    const converged =
      Math.abs(energy - lastBestEnergy) < 0.001 && stagnantCount > 50;
    lastBestEnergy = bestEnergy;

    history.push({ step, energy, temperature });

    return {
      spins: new Int8Array(spins),
      energy,
      temperature,
      step,
      bestEnergy,
      bestSpins: new Int8Array(bestSpins),
      history: [...history],
      converged,
    };
  }

  function reset() {
    for (let i = 0; i < n; i++) spins[i] = Math.random() < 0.5 ? 1 : -1;
    temperature = config.temperature;
    step = 0;
    energy = computeEnergy(spins, J, n);
    bestEnergy = energy;
    bestSpins.set(spins);
    history.length = 0;
    history.push({ step: 0, energy, temperature });
    stagnantCount = 0;
    lastBestEnergy = energy;
  }

  function getLocalField(idx: number): number {
    return localField(spins, J, n, idx);
  }

  return { doStep, reset, getLocalField };
}
