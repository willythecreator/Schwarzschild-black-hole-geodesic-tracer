#version 330 core

in vec2 fragCoord;
out vec4 FragColor;

uniform sampler2D sourceTexture;

void main()
{
    vec2 uv = fragCoord * 0.5 + 0.5;
    FragColor = texture(sourceTexture, uv);
}