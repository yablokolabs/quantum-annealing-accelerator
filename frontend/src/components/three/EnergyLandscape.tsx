import { useMemo, useRef } from "react";
import { Canvas, useFrame } from "@react-three/fiber";
import { OrbitControls, Grid } from "@react-three/drei";
import * as THREE from "three";

function Surface() {
  const meshRef = useRef<THREE.Mesh>(null);
  const geometry = useMemo(() => {
    const res = 80;
    const geo = new THREE.PlaneGeometry(10, 10, res, res);
    const pos = geo.attributes.position;
    const colors = new Float32Array(pos.count * 3);

    let minY = Infinity;
    let maxY = -Infinity;

    for (let i = 0; i < pos.count; i++) {
      const x = pos.getX(i);
      const z = pos.getY(i);
      const y =
        -2 * Math.exp(-((x - 1) ** 2 + (z - 1) ** 2)) +
        -1.5 * Math.exp(-((x + 2) ** 2 + (z + 1) ** 2) / 2) +
        -2.5 * Math.exp(-((x + 0.5) ** 2 + (z - 2) ** 2) / 1.5) +
        0.3 * Math.sin(x * 2) * Math.cos(z * 2);
      pos.setZ(i, y);
      if (y < minY) minY = y;
      if (y > maxY) maxY = y;
    }

    for (let i = 0; i < pos.count; i++) {
      const y = pos.getZ(i);
      const t = (y - minY) / (maxY - minY + 0.001);
      // Blue (low) → Cyan → Yellow → Red (high)
      const color = new THREE.Color();
      if (t < 0.33) {
        color.setRGB(0.1, 0.2 + t * 2, 0.9 - t);
      } else if (t < 0.66) {
        const u = (t - 0.33) / 0.33;
        color.setRGB(u, 0.8, 0.6 - u * 0.5);
      } else {
        const u = (t - 0.66) / 0.34;
        color.setRGB(0.9 + u * 0.1, 0.6 - u * 0.5, 0.1);
      }
      colors[i * 3] = color.r;
      colors[i * 3 + 1] = color.g;
      colors[i * 3 + 2] = color.b;
    }

    geo.setAttribute("color", new THREE.BufferAttribute(colors, 3));
    geo.computeVertexNormals();
    return geo;
  }, []);

  return (
    <mesh ref={meshRef} geometry={geometry} rotation={[-Math.PI / 2, 0, 0]} receiveShadow>
      <meshStandardMaterial vertexColors side={THREE.DoubleSide} roughness={0.6} metalness={0.1} />
    </mesh>
  );
}

function OptimizationParticle() {
  const ref = useRef<THREE.Mesh>(null);

  useFrame(({ clock }) => {
    if (!ref.current) return;
    const t = clock.getElapsedTime() * 0.3;
    const x = 1 + Math.sin(t) * 2;
    const z = 1 + Math.cos(t * 0.7) * 2;
    const y =
      -2 * Math.exp(-((x - 1) ** 2 + (z - 1) ** 2)) +
      -1.5 * Math.exp(-((x + 2) ** 2 + (z + 1) ** 2) / 2) +
      -2.5 * Math.exp(-((x + 0.5) ** 2 + (z - 2) ** 2) / 1.5) +
      0.3 * Math.sin(x * 2) * Math.cos(z * 2) +
      0.2;
    ref.current.position.set(x, y, z);
  });

  return (
    <mesh ref={ref} castShadow>
      <sphereGeometry args={[0.15, 16, 16]} />
      <meshStandardMaterial color="#22d3ee" emissive="#22d3ee" emissiveIntensity={0.5} />
    </mesh>
  );
}

export default function EnergyLandscape() {
  return (
    <div className="h-[400px] w-full rounded-2xl overflow-hidden border border-slate-200 dark:border-slate-700">
      <Canvas
        camera={{ position: [6, 5, 6], fov: 50 }}
        shadows
        gl={{ antialias: true }}
      >
        <color attach="background" args={["#0f172a"]} />
        <ambientLight intensity={0.4} />
        <directionalLight position={[5, 8, 5]} intensity={0.8} castShadow />
        <pointLight position={[-3, 4, -3]} intensity={0.3} color="#818cf8" />
        <Surface />
        <OptimizationParticle />
        <Grid
          args={[20, 20]}
          position={[0, -3, 0]}
          cellSize={1}
          cellColor="#334155"
          sectionColor="#475569"
          fadeDistance={15}
          infiniteGrid
        />
        <OrbitControls
          enableDamping
          dampingFactor={0.05}
          maxPolarAngle={Math.PI / 2.1}
        />
      </Canvas>
    </div>
  );
}
