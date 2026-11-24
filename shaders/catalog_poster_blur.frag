#include <flutter/runtime_effect.glsl>

uniform vec2 uResolution;
uniform sampler2D uPoster;
out vec4 fragColor;

void main() {
  const float fullTurn = 6.28318530718;
  const int directions = 16;
  const int quality = 3;
  const float size = 2.0;

  vec2 radius = size / uResolution;
  vec2 uv = FlutterFragCoord().xy / uResolution;
  vec4 color = texture(uPoster, uv);

  for (int direction = 0; direction < directions; direction++) {
    float angle = fullTurn * float(direction) / float(directions);
    vec2 offset = vec2(cos(angle), sin(angle)) * radius;
    for (int sampleIndex = 1; sampleIndex <= quality; sampleIndex++) {
      float distance = float(sampleIndex) / float(quality);
      color += texture(uPoster, uv + offset * distance);
    }
  }

  fragColor = color / float(1 + directions * quality);
}
