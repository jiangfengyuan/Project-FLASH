import { useRef, useMemo } from 'react';
import { Canvas, useFrame } from '@react-three/fiber';
import * as THREE from 'three';

const vertexShader = `
  uniform float uTime;
  varying vec2 vUv;
  varying float vElevation;

  float random(vec2 st) {
    return fract(sin(dot(st.xy, vec2(12.9898,78.233))) * 43758.5453123);
  }

  float noise(vec2 st) {
    vec2 i = floor(st);
    vec2 f = fract(st);
    f = f * f * (3.0 - 2.0 * f);
    float a = random(i);
    float b = random(i + vec2(1.0, 0.0));
    float c = random(i + vec2(0.0, 1.0));
    float d = random(i + vec2(1.0, 1.0));
    return mix(a, b, f.x) + (c - a) * f.y * (1.0 - f.x) + (d - b) * f.x * f.y;
  }

  void main() {
    vUv = uv;
    vec3 pos = position;
    float t = uTime * 0.05;
    float elevation = sin(pos.x * 0.06 + t) * cos(pos.y * 0.06 + t) * 1.2;
    elevation += noise(pos.xy * 0.3 + t) * 0.6;
    elevation += noise(pos.xy * 1.2 - t) * 0.25;
    pos.z = elevation;
    vElevation = elevation;
    gl_Position = projectionMatrix * modelViewMatrix * vec4(pos, 1.0);
  }
`;

const fragmentShader = `
  uniform float uTime;
  uniform float uOpacity;
  varying vec2 vUv;
  varying float vElevation;

  void main() {
    // Soft pastel palette: desaturated cyan-teal-blue
    // Base colors shift slowly with elevation and time
    float pt = vElevation * 0.08 + uTime * 0.015;

    // Color A: soft mint green (low saturation, light)
    vec3 colorA = vec3(0.55, 0.68, 0.62);
    // Color B: pale sky blue
    vec3 colorB = vec3(0.58, 0.72, 0.78);
    // Color C: light lavender
    vec3 colorC = vec3(0.65, 0.62, 0.72);

    float mixAB = sin(pt) * 0.5 + 0.5;
    float mixBC = cos(pt * 0.7) * 0.5 + 0.5;

    vec3 color = mix(mix(colorA, colorB, mixAB), colorC, mixBC * 0.3);

    // Very subtle wave highlight
    float edge = smoothstep(-1.0, 1.0, vElevation);
    color += vec3(0.95, 0.97, 1.0) * edge * 0.04;

    // Soft glass distortion
    vec2 glassDistortion = vec2(
      sin(vUv.y * 4.0 + uTime * 0.4),
      cos(vUv.x * 4.0 + uTime * 0.4)
    ) * 0.02;
    color += glassDistortion.xyx * 0.08;

    // Gentle radial vignette to darken edges slightly
    float dist = length(vUv - 0.5);
    color *= 1.0 - smoothstep(0.3, 0.75, dist) * 0.2;

    // Overall brightness: light and airy
    color *= 0.65;

    gl_FragColor = vec4(color, uOpacity);
  }
`;

function WaveMesh() {
  const meshRef = useRef<THREE.Mesh>(null);
  const materialRef = useRef<THREE.ShaderMaterial>(null);

  const uniforms = useMemo(
    () => ({
      uTime: { value: 0 },
      uOpacity: { value: 1.0 },
    }),
    []
  );

  useFrame((state) => {
    if (materialRef.current) {
      materialRef.current.uniforms.uTime.value = state.clock.elapsedTime;
    }
  });

  return (
    <mesh ref={meshRef} rotation={[-Math.PI / 2, 0, 0]} position={[0, 0, 0]}>
      <planeGeometry args={[100, 100, 256, 256]} />
      <shaderMaterial
        ref={materialRef}
        vertexShader={vertexShader}
        fragmentShader={fragmentShader}
        uniforms={uniforms}
        transparent
        side={THREE.DoubleSide}
      />
    </mesh>
  );
}

export default function WaveBackground() {
  return (
    <div
      style={{
        position: 'fixed',
        top: 0,
        left: 0,
        width: '100%',
        height: '100%',
        zIndex: 0,
        pointerEvents: 'none',
      }}
    >
      <Canvas
        camera={{ position: [0, -10, 5], fov: 45 }}
        gl={{ antialias: true, alpha: true }}
        style={{ width: '100%', height: '100%' }}
      >
        <WaveMesh />
      </Canvas>
    </div>
  );
}
