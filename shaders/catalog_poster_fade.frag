#include <flutter/runtime_effect.glsl>

uniform vec2 uRegion;
uniform vec2 uOutgoingSize;
uniform vec2 uIncomingSize;
uniform float uBlend;
uniform sampler2D uOutgoing;
uniform sampler2D uIncoming;

out vec4 fragColor;

vec2 posterUV(vec2 size, vec2 position) {
  vec2 origin = vec2(uRegion.x - size.x, (uRegion.y - size.y) * 0.5);
  return (position - origin) / max(size, vec2(1.0));
}

bool inPoster(vec2 uv) {
  return uv.x >= 0.0 && uv.x <= 1.0 && uv.y >= 0.0 && uv.y <= 1.0;
}

vec4 shadePoster(vec3 original, vec2 uv, float opacity) {
  float light = dot(original, vec3(0.2126, 0.7152, 0.0722));
  vec3 wash = mix(vec3(0.063, 0.044, 0.087), vec3(0.88, 0.62, 0.73), light);
  float strength = 0.25 + 0.28 * (1.0 - uv.x);
  vec3 color = mix(original * 0.78, wash, strength);
  float mask = smoothstep(0.0, 0.74, uv.x) * (1.0 - smoothstep(0.74, 1.0, uv.y));
  float alpha = mask * opacity;
  return vec4(color * alpha, alpha);
}

void main() {
  vec2 position = FlutterFragCoord().xy;
  vec4 outgoing = vec4(0.0);
  vec4 incoming = vec4(0.0);
  vec2 oldUV = posterUV(uOutgoingSize, position);
  vec2 newUV = posterUV(uIncomingSize, position);
  if (uOutgoingSize.x > 0.0 && uBlend < 1.0 && inPoster(oldUV)) {
    outgoing = shadePoster(texture(uOutgoing, oldUV).rgb, oldUV, 1.0 - uBlend);
  }
  if (uIncomingSize.x > 0.0 && uBlend > 0.0 && inPoster(newUV)) {
    incoming = shadePoster(texture(uIncoming, newUV).rgb, newUV, uBlend);
  }
  fragColor = incoming + outgoing * (1.0 - incoming.a);
}
