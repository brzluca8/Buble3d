import { useRef, useState } from 'react'
import * as THREE from 'three'
import { Canvas, useFrame } from '@react-three/fiber'
import { PerformanceMonitor } from '@react-three/drei'
import { EffectComposer, Bloom, ToneMapping } from '@react-three/postprocessing'
import { ToneMappingMode } from 'postprocessing'
import { useGame } from '../store'
import { Terrain, Plaza, Droplets, Waterfalls } from './Island'
import { Buildings, SelectionRing, Sparks } from './Building'
import { Mascot } from './Mascot'
import { Clouds, FarIslands } from './Sky'
import { CameraRig } from './CameraRig'

function Island() {
  const ref = useRef()
  useFrame(({ clock }) => {
    ref.current.position.y = Math.sin(clock.elapsedTime * 0.8) * 0.15
  })
  return (
    <group ref={ref}>
      <Terrain />
      <Plaza />
      <Waterfalls />
      <Droplets />
      <Buildings />
      <SelectionRing />
      <Sparks />
      <Mascot />
      {/* lumini calde locale: palat și fântână */}
      <pointLight color="#ffb060" intensity={14} distance={12} decay={2} position={[0, 2, -1.5]} />
      <pointLight color="#4fe8d8" intensity={8} distance={7} decay={2} position={[0, 2.3, 0.3]} />
    </group>
  )
}

function Lights({ shadowSize }) {
  return (
    <>
      <hemisphereLight args={['#cfe6ff', '#7a5aa0', 2.2]} />
      <directionalLight
        color="#fff0d0"
        intensity={3.6}
        position={[9, 16, 11]}
        castShadow
        shadow-mapSize={[shadowSize, shadowSize]}
        shadow-bias={-0.0006}
        shadow-normalBias={0.02}
        shadow-camera-left={-11}
        shadow-camera-right={11}
        shadow-camera-top={11}
        shadow-camera-bottom={-11}
        shadow-camera-near={1}
        shadow-camera-far={50}
      />
    </>
  )
}

// Bloom real, cu buget pentru mobil: prag ridicat (doar emisivele strălucesc),
// mipmapBlur și rezoluție redusă. Dezactivat pe calitate scăzută.
function Effects() {
  return (
    <EffectComposer multisampling={4} disableNormalPass>
      <Bloom mipmapBlur luminanceThreshold={0.9} luminanceSmoothing={0.2} intensity={0.9} radius={0.7} resolutionScale={0.5} />
      <ToneMapping mode={ToneMappingMode.ACES_FILMIC} />
    </EffectComposer>
  )
}

export default function World() {
  const quality = useGame((s) => s.quality)
  const blastOpen = useGame((s) => s.blastOpen)
  const [degraded, setDegraded] = useState(false)
  const high = quality === 'inalta' && !degraded
  const maxDpr = high ? 2 : 1.25

  return (
    <Canvas
      className="scene"
      shadows={{ type: THREE.PCFShadowMap }}
      dpr={[1, maxDpr]}
      frameloop={blastOpen ? 'never' : 'always'}
      camera={{ fov: 45, near: 0.1, far: 300, position: [0, 20, 30] }}
      gl={{ antialias: !high, alpha: true, powerPreference: 'high-performance', toneMappingExposure: 1.1 }}
      onCreated={({ gl }) => gl.setClearColor(0x000000, 0)}
    >
      <PerformanceMonitor onDecline={() => setDegraded(true)} />
      <Lights shadowSize={high ? 2048 : 1024} />
      <CameraRig />
      <Island />
      <Clouds quality={high ? 'inalta' : 'scazuta'} />
      <FarIslands />
      {high && <Effects />}
    </Canvas>
  )
}
