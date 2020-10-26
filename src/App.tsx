import React, {
  useRef,
  Suspense,
  useMemo,
  useLayoutEffect,
  useState,
  useEffect,
  useCallback,
} from "react";
import {
  Canvas,
  useFrame,
  ReactThreeFiber,
  extend,
  useThree,
  useUpdate,
  createPortal,
} from "react-three-fiber";
import * as THREE from "three";
import { OrbitControls, shaderMaterial, useTexture, Html } from "@react-three/drei";
import * as dat from "dat.gui";
import { useDeepMemo, useDeepCompareEffect } from "./useDeep";
import vertex from "./shader/vertex.glsl";
import fragment from "./shader/fragment.glsl";
import { PerspectiveCamera, PlaneBufferGeometry, TypedArray } from "three";
import image1 from "url:./assets/img1.jpg";
import { PointerEvent } from "react-three-fiber/canvas";
import { useSpring } from "react-spring";
import { Bloom, EffectComposer, Noise, Vignette } from "@react-three/postprocessing";

interface DatGuiSetting {
  value: string | number | undefined;
  type?: "color" | undefined;
  min?: number;
  max?: number;
  step?: number;
}

const ImgShaderMaterial = shaderMaterial(
  {
    uImg: null,
    uMouse: new THREE.Vector2(0, 0),
    uResolution: new THREE.Vector2(0, 0),
    uBlur: 5.8,
    uRadius: 0.004,
    uTime: 0,
    uThreshold: 0,
    uSoftness: 0,
  },
  vertex,
  fragment
);

declare global {
  namespace JSX {
    interface IntrinsicElements {
      imgShaderMaterial: any;
    }
  }
}

extend({
  ImgShaderMaterial,
});

const useDatGui = <T extends Record<string, DatGuiSetting>>(settings: T) => {
  const obj = useDeepMemo<Record<keyof T, DatGuiSetting["value"]>>(() => {
    const o = {} as Record<keyof T, DatGuiSetting["value"]>;
    Object.keys(settings).forEach((key) => {
      const setting = settings[key];
      const { value } = setting;
      o[key as keyof T] = value;
    });
    return o;
  }, [settings]);

  useDeepCompareEffect(() => {
    const inst = new dat.GUI();
    Object.keys(settings).forEach((key) => {
      const setting = settings[key];
      const { type, min, max, step } = setting;
      if (type === "color") {
        inst.addColor(obj, key);
      } else {
        inst.add(obj, key, min, max, step);
      }
    });
    return () => {
      inst.destroy();
    };
  }, [obj]);

  return obj;
};

const maxRadius = 0.1;

const Image = () => {
  const settings = useDatGui({
    blur: {
      value: 0.8,
      min: 0,
      max: 10,
      step: 0.01
    },
  })
  const { viewport, size, camera, aspect, clock } = useThree();
  const texture = useTexture(image1) as THREE.Texture;
  const img = texture.image as HTMLImageElement;
  const mouse = useRef<THREE.Vector2>(new THREE.Vector2(0, 0));
  const [hoverProps, set] = useSpring(() => ({
    radius: 0,
  }));

  const resolution = useMemo(() => {
    if (!img) return new THREE.Vector2(0, 0);
    return new THREE.Vector2(img.naturalWidth, img.naturalHeight);
  }, [img]);
  // compute the plane size which is in camera's viewport, if the z coordinate of the current item is not 0, use the following calculation
  // let z = 0;
  // const h = 2 * Math.tan((camera as PerspectiveCamera).fov * Math.PI / 180 / 2) * (camera.position.z - z);
  // const w = h * (camera as PerspectiveCamera).aspect;

  const imageAspect = img.naturalWidth / img.naturalHeight;
  const sizeScale = 0.8; // percentage of viewport width
  let sx = 1;
  let sy = 1;
  if (aspect < imageAspect) {
    sx = sizeScale * viewport.width;
    sy = sx / imageAspect;
  } else {
    sy = sizeScale * viewport.height;
    sx = sy * imageAspect;
  }

  const onPointerMove = useCallback((e: PointerEvent) => {
    mouse.current.x = e.uv.x;
    mouse.current.y = e.uv.y;
  }, []);

  const material = useRef<THREE.ShaderMaterial>();

  useFrame(() => {
    material.current.uniforms.uRadius.value = hoverProps.radius.getValue();
    material.current.uniforms.uMouse.value = mouse.current;
    material.current.uniforms.uBlur.value = settings.blur;
    material.current.uniforms.uTime.value = clock.getElapsedTime();
  });

  return (
    <mesh
      scale={[sx, sy, 1]}
      onPointerOver={(e) => {
        set({
          radius: maxRadius,
        });
      }}
      onPointerMove={onPointerMove}
      onPointerOut={(e) => {
        set({
          radius: 0,
        });
      }}
    >
      <planeBufferGeometry attach="geometry" args={[1, 1]} />
      <imgShaderMaterial
        ref={material}
        attach="material"
        transparent
        uImg={texture}
        uResolution={resolution}
        uSoftness={0.2}
        uThreshold={0.4}
      />
    </mesh>
  );
};

const Scene = () => {
  return (
    <>
      <Image />
    </>
  );
};

const App = () => {
  return (
    <Canvas
      colorManagement
      onCreated={({ gl }) => {
        gl.setClearColor(0x999999);
      }}
    >
      <ambientLight intensity={0.5} />
      <OrbitControls />
      <Suspense
        fallback={
          <Html>
            <div>Loading</div>
          </Html>
        }
      >
        <Scene />
      </Suspense>
      <EffectComposer>
        {/* <Bloom luminanceThreshold={0.3} luminanceSmoothing={0.05} height={300} /> */}
        <Noise opacity={0.1} />
        <Vignette eskil={false} offset={0.2} darkness={0.7} />
      </EffectComposer>
    </Canvas>
  );
};

export default App;