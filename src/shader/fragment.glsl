varying vec2 vUv;
uniform float uBlur;
uniform sampler2D uImg;
uniform vec2 uMouse;
uniform float uRadius;
uniform vec2 uResolution;
uniform float uBlurIntensity;
uniform float uThreshold;
uniform float uSoftness;
uniform float uTime;
uniform float uNoise1Size;
uniform float uNoise1Freq;
uniform float uNoise2Size;
uniform float uNoise2Freq;
uniform float uNoise2Factor;
uniform float uNoise3Size;
uniform float uNoise3Freq;
uniform float uNoise3Factor;

vec3 mod289(vec3 x) {
  return x - floor(x * (1.0 / 289.0)) * 289.0;
}

vec4 mod289(vec4 x) {
  return x - floor(x * (1.0 / 289.0)) * 289.0;
}

vec4 permute(vec4 x) {
     return mod289(((x*34.0)+1.0)*x);
}

vec4 taylorInvSqrt(vec4 r) {
  return 1.79284291400159 - 0.85373472095314 * r;
}

float snoise(vec3 v) {
  const vec2  C = vec2(1.0/6.0, 1.0/3.0) ;
  const vec4  D = vec4(0.0, 0.5, 1.0, 2.0);

  // First corner
  vec3 i  = floor(v + dot(v, C.yyy) );
  vec3 x0 =   v - i + dot(i, C.xxx) ;

  // Other corners
  vec3 g = step(x0.yzx, x0.xyz);
  vec3 l = 1.0 - g;
  vec3 i1 = min( g.xyz, l.zxy );
  vec3 i2 = max( g.xyz, l.zxy );

  //   x0 = x0 - 0.0 + 0.0 * C.xxx;
  //   x1 = x0 - i1  + 1.0 * C.xxx;
  //   x2 = x0 - i2  + 2.0 * C.xxx;
  //   x3 = x0 - 1.0 + 3.0 * C.xxx;
  vec3 x1 = x0 - i1 + C.xxx;
  vec3 x2 = x0 - i2 + C.yyy; // 2.0*C.x = 1/3 = C.y
  vec3 x3 = x0 - D.yyy;      // -1.0+3.0*C.x = -0.5 = -D.y

  // Permutations
  i = mod289(i);
  vec4 p = permute( permute( permute(
             i.z + vec4(0.0, i1.z, i2.z, 1.0 ))
           + i.y + vec4(0.0, i1.y, i2.y, 1.0 ))
           + i.x + vec4(0.0, i1.x, i2.x, 1.0 ));

  // Gradients: 7x7 points over a square, mapped onto an octahedron.
  // The ring size 17*17 = 289 is close to a multiple of 49 (49*6 = 294)
  float n_ = 0.142857142857; // 1.0/7.0
  vec3  ns = n_ * D.wyz - D.xzx;

  vec4 j = p - 49.0 * floor(p * ns.z * ns.z);  //  mod(p,7*7)

  vec4 x_ = floor(j * ns.z);
  vec4 y_ = floor(j - 7.0 * x_ );    // mod(j,N)

  vec4 x = x_ *ns.x + ns.yyyy;
  vec4 y = y_ *ns.x + ns.yyyy;
  vec4 h = 1.0 - abs(x) - abs(y);

  vec4 b0 = vec4( x.xy, y.xy );
  vec4 b1 = vec4( x.zw, y.zw );

  //vec4 s0 = vec4(lessThan(b0,0.0))*2.0 - 1.0;
  //vec4 s1 = vec4(lessThan(b1,0.0))*2.0 - 1.0;
  vec4 s0 = floor(b0)*2.0 + 1.0;
  vec4 s1 = floor(b1)*2.0 + 1.0;
  vec4 sh = -step(h, vec4(0.0));

  vec4 a0 = b0.xzyw + s0.xzyw*sh.xxyy ;
  vec4 a1 = b1.xzyw + s1.xzyw*sh.zzww ;

  vec3 p0 = vec3(a0.xy,h.x);
  vec3 p1 = vec3(a0.zw,h.y);
  vec3 p2 = vec3(a1.xy,h.z);
  vec3 p3 = vec3(a1.zw,h.w);

 //Normalise gradients
  vec4 norm = taylorInvSqrt(vec4(dot(p0,p0), dot(p1,p1), dot(p2, p2), dot(p3,p3)));
  p0 *= norm.x;
  p1 *= norm.y;
  p2 *= norm.z;
  p3 *= norm.w;

  // Mix final noise value
  vec4 m = max(0.6 - vec4(dot(x0,x0), dot(x1,x1), dot(x2,x2), dot(x3,x3)), 0.0);
  m = m * m;
  return 42.0 * dot( m*m, vec4( dot(p0,x0), dot(p1,x1),
                                dot(p2,x2), dot(p3,x3) ) );
}

float circle(vec2 pos, float radius, float blurriness) {
  float dist = length(pos);
  return 1. - smoothstep(radius - (radius * blurriness), radius + (radius * blurriness), dist);
}

vec3 brightnessContrast(vec3 value, float brightness, float contrast) {
  return (value - 0.5) * contrast + 0.5 + brightness;
}

vec3 grayscale(vec3 color) {
  return vec3(dot(color.rgb, vec3(0.299, 0.587, 0.114)));
}

void main() {
  vec4 sourceColor = texture2D(uImg, vUv);
  vec4 color = vec4(grayscale(sourceColor.rgb), sourceColor.a);
  if (uRadius > 0.001) {
    vec3 invertedColor = vec3(1.0) - color.rgb;
    vec2 circlePos = (vUv - uMouse) * vec2(1., uResolution.y / uResolution.x);
    float progress = circle(circlePos, uRadius, uBlur);
    float nx = vUv.x + cos(vUv.y + uTime * 0.01);
    float ny = vUv.y - cos(uTime) * 0.01 - sin(uTime * .0001) * .01;
    float s1 = snoise(vec3(nx * uNoise1Size, ny * uNoise1Size, uTime * uNoise1Freq)) - 0.866;
    float s2 = snoise(vec3(nx * uNoise2Size, ny * uNoise2Size, uTime * uNoise2Freq)) - 0.866;
    float s3 = snoise(vec3(nx * uNoise3Size, ny * uNoise3Size, uTime * uNoise3Freq)) - 0.866;
    float s = s1 * (1. - s2 * uNoise2Factor) * (1. - s3 * uNoise3Factor); // since s1, s2, s3 are all negative, so the result here is negative
    float mask = smoothstep(uThreshold - uSoftness, uThreshold, s + progress * uBlurIntensity);
    gl_FragColor = vec4(mix(color.rgb, invertedColor.rgb, mask), 1.0);
  } else {
    gl_FragColor = color;
  }
}