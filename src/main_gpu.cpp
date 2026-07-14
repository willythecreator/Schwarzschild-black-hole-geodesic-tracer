#include <GL/glew.h>
#include <GLFW/glfw3.h>

#include <algorithm>
#include <cmath>
#include <fstream>
#include <iostream>
#include <sstream>
#include <string>

struct V3
{
    float x, y, z;
};

V3 normalize(V3 v)
{
    float length = std::sqrt(v.x * v.x + v.y * v.y + v.z * v.z);
    return {v.x / length, v.y / length, v.z / length};
}

V3 cross(V3 a, V3 b)
{
    return {
        a.y * b.z - a.z * b.y,
        a.z * b.x - a.x * b.z,
        a.x * b.y - a.y * b.x};
}

V3 operator+(V3 a, V3 b) { return {a.x + b.x, a.y + b.y, a.z + b.z}; }
V3 operator-(V3 a, V3 b) { return {a.x - b.x, a.y - b.y, a.z - b.z}; }
V3 operator*(V3 v, float s) { return {v.x * s, v.y * s, v.z * s}; }

std::string readFile(const std::string &path)
{
    std::ifstream file(path);
    if (!file)
    {
        std::cerr << "Could not open shader: " << path << "\n";
        return "";
    }

    std::stringstream stream;
    stream << file.rdbuf();
    return stream.str();
}

GLuint compileShader(GLenum type, const std::string &source)
{
    GLuint shader = glCreateShader(type);
    const char *text = source.c_str();

    glShaderSource(shader, 1, &text, nullptr);
    glCompileShader(shader);

    GLint success = 0;
    glGetShaderiv(shader, GL_COMPILE_STATUS, &success);

    if (!success)
    {
        char log[2048];
        glGetShaderInfoLog(shader, sizeof(log), nullptr, log);
        std::cerr << "Shader compilation error:\n"
                  << log << "\n";
    }

    return shader;
}

GLuint buildProgram(const std::string &vertexPath, const std::string &fragmentPath)
{
    GLuint vertex = compileShader(GL_VERTEX_SHADER, readFile(vertexPath));
    GLuint fragment = compileShader(GL_FRAGMENT_SHADER, readFile(fragmentPath));

    GLuint program = glCreateProgram();
    glAttachShader(program, vertex);
    glAttachShader(program, fragment);
    glLinkProgram(program);

    GLint success = 0;
    glGetProgramiv(program, GL_LINK_STATUS, &success);

    if (!success)
    {
        char log[2048];
        glGetProgramInfoLog(program, sizeof(log), nullptr, log);
        std::cerr << "Program link error:\n"
                  << log << "\n";
    }

    glDeleteShader(vertex);
    glDeleteShader(fragment);
    return program;
}

struct RenderTarget
{
    GLuint framebuffer = 0;
    GLuint texture = 0;
    int width = 0;
    int height = 0;
};

void createRenderTarget(RenderTarget &target, int width, int height)
{
    if (target.width == width && target.height == height)
        return;

    if (target.texture)
        glDeleteTextures(1, &target.texture);
    if (target.framebuffer)
        glDeleteFramebuffers(1, &target.framebuffer);

    target.width = width;
    target.height = height;

    glGenFramebuffers(1, &target.framebuffer);
    glBindFramebuffer(GL_FRAMEBUFFER, target.framebuffer);

    glGenTextures(1, &target.texture);
    glBindTexture(GL_TEXTURE_2D, target.texture);

    glTexImage2D(
        GL_TEXTURE_2D, 0, GL_RGBA8,
        width, height, 0,
        GL_RGBA, GL_UNSIGNED_BYTE, nullptr);

    // Linear filtering makes the lower-resolution render look smoother.
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);

    glFramebufferTexture2D(
        GL_FRAMEBUFFER,
        GL_COLOR_ATTACHMENT0,
        GL_TEXTURE_2D,
        target.texture,
        0);

    if (glCheckFramebufferStatus(GL_FRAMEBUFFER) != GL_FRAMEBUFFER_COMPLETE)
        std::cerr << "Render target creation failed.\n";

    glBindFramebuffer(GL_FRAMEBUFFER, 0);
}

static V3 camPos = {0.0f, 7.0f, -30.0f};
static float yaw = 90.0f;
static float pitch = -13.0f;
static float speed = 5.0f;
static double lastX = 640.0;
static double lastY = 360.0;
static bool firstMouse = true;

V3 forward()
{
    constexpr float DEG_TO_RAD = 3.14159265f / 180.0f;
    float y = yaw * DEG_TO_RAD;
    float p = pitch * DEG_TO_RAD;

    return normalize({std::cos(p) * std::cos(y),
                      std::sin(p),
                      std::cos(p) * std::sin(y)});
}

V3 right()
{
    return normalize(cross(forward(), {0.0f, 1.0f, 0.0f}));
}

V3 up()
{
    return normalize(cross(right(), forward()));
}

void mouseCallback(GLFWwindow *, double x, double y)
{
    if (firstMouse)
    {
        lastX = x;
        lastY = y;
        firstMouse = false;
    }

    float dx = static_cast<float>(x - lastX) * 0.1f;
    float dy = static_cast<float>(lastY - y) * 0.1f;

    lastX = x;
    lastY = y;

    yaw += dx;
    pitch = std::clamp(pitch + dy, -89.0f, 89.0f);
}

void processInput(GLFWwindow *window, float deltaTime)
{
    if (glfwGetKey(window, GLFW_KEY_ESCAPE) == GLFW_PRESS)
        glfwSetWindowShouldClose(window, true);

    V3 fwd = forward();
    V3 rgt = right();

    if (glfwGetKey(window, GLFW_KEY_W) == GLFW_PRESS)
        camPos = camPos + fwd * (speed * deltaTime);
    if (glfwGetKey(window, GLFW_KEY_S) == GLFW_PRESS)
        camPos = camPos - fwd * (speed * deltaTime);
    if (glfwGetKey(window, GLFW_KEY_A) == GLFW_PRESS)
        camPos = camPos - rgt * (speed * deltaTime);
    if (glfwGetKey(window, GLFW_KEY_D) == GLFW_PRESS)
        camPos = camPos + rgt * (speed * deltaTime);
    if (glfwGetKey(window, GLFW_KEY_SPACE) == GLFW_PRESS)
        camPos.y += speed * deltaTime;
    if (glfwGetKey(window, GLFW_KEY_LEFT_SHIFT) == GLFW_PRESS)
        camPos.y -= speed * deltaTime;

    speed = glfwGetKey(window, GLFW_KEY_Q) == GLFW_PRESS ? 15.0f : glfwGetKey(window, GLFW_KEY_E) == GLFW_PRESS ? 1.0f
                                                                                                                : 5.0f;
}

int main()
{
    if (!glfwInit())
        return -1;

    glfwWindowHint(GLFW_CONTEXT_VERSION_MAJOR, 3);
    glfwWindowHint(GLFW_CONTEXT_VERSION_MINOR, 3);
    glfwWindowHint(GLFW_OPENGL_PROFILE, GLFW_OPENGL_CORE_PROFILE);

    GLFWwindow *window = glfwCreateWindow(
        1280, 720,
        "Schwarzschild Black Hole Tracer",
        nullptr, nullptr);

    if (!window)
    {
        glfwTerminate();
        return -1;
    }

    glfwMakeContextCurrent(window);
    glfwSwapInterval(1);

    glfwSetCursorPosCallback(window, mouseCallback);
    glfwSetInputMode(window, GLFW_CURSOR, GLFW_CURSOR_DISABLED);

    glewExperimental = GL_TRUE;
    if (glewInit() != GLEW_OK)
    {
        glfwTerminate();
        return -1;
    }

    float vertices[] = {
        -1, -1, 1, -1, 1, 1,
        -1, -1, 1, 1, -1, 1};

    GLuint vao, vbo;
    glGenVertexArrays(1, &vao);
    glBindVertexArray(vao);

    glGenBuffers(1, &vbo);
    glBindBuffer(GL_ARRAY_BUFFER, vbo);
    glBufferData(GL_ARRAY_BUFFER, sizeof(vertices), vertices, GL_STATIC_DRAW);

    glVertexAttribPointer(0, 2, GL_FLOAT, GL_FALSE, 0, nullptr);
    glEnableVertexAttribArray(0);

    GLuint blackHoleProgram = buildProgram(
        "../src/shaders/vert.glsl",
        "../src/shaders/frag.glsl");

    GLuint presentProgram = buildProgram(
        "../src/shaders/vert.glsl",
        "../src/shaders/present_frag.glsl");

    RenderTarget blackHoleTarget;

    constexpr float RENDER_SCALE = 0.65f; // Try 0.50 on slower laptops.

    double previousTime = glfwGetTime();
    double fpsStart = previousTime;
    int frameCount = 0;
    float elapsed = 0.0f;

    while (!glfwWindowShouldClose(window))
    {
        double now = glfwGetTime();
        float deltaTime = static_cast<float>(now - previousTime);
        previousTime = now;
        elapsed += deltaTime;
        frameCount++;

        if (now - fpsStart >= 1.0)
        {
            std::string title = "Schwarzschild Black Hole Tracer | " +
                                std::to_string(frameCount) + " FPS";
            glfwSetWindowTitle(window, title.c_str());

            frameCount = 0;
            fpsStart = now;
        }

        processInput(window, deltaTime);

        int screenWidth, screenHeight;
        glfwGetFramebufferSize(window, &screenWidth, &screenHeight);

        int renderWidth = std::max(1, static_cast<int>(screenWidth * RENDER_SCALE));
        int renderHeight = std::max(1, static_cast<int>(screenHeight * RENDER_SCALE));

        createRenderTarget(blackHoleTarget, renderWidth, renderHeight);

        // Pass 1: expensive black-hole calculation at lower resolution.
        glBindFramebuffer(GL_FRAMEBUFFER, blackHoleTarget.framebuffer);
        glViewport(0, 0, renderWidth, renderHeight);
        glClear(GL_COLOR_BUFFER_BIT);

        glUseProgram(blackHoleProgram);

        V3 fwd = forward();
        V3 rgt = right();
        V3 cameraUp = up();

        glUniform3f(glGetUniformLocation(blackHoleProgram, "camPos"), camPos.x, camPos.y, camPos.z);
        glUniform3f(glGetUniformLocation(blackHoleProgram, "camForward"), fwd.x, fwd.y, fwd.z);
        glUniform3f(glGetUniformLocation(blackHoleProgram, "camRight"), rgt.x, rgt.y, rgt.z);
        glUniform3f(glGetUniformLocation(blackHoleProgram, "camUp"), cameraUp.x, cameraUp.y, cameraUp.z);
        glUniform1f(glGetUniformLocation(blackHoleProgram, "aspectRatio"),
                    static_cast<float>(renderWidth) / static_cast<float>(renderHeight));
        glUniform1f(glGetUniformLocation(blackHoleProgram, "time"), elapsed);

        glBindVertexArray(vao);
        glDrawArrays(GL_TRIANGLES, 0, 6);

        // Pass 2: cheap upscale to the full display resolution.
        glBindFramebuffer(GL_FRAMEBUFFER, 0);
        glViewport(0, 0, screenWidth, screenHeight);
        glClear(GL_COLOR_BUFFER_BIT);

        glUseProgram(presentProgram);
        glActiveTexture(GL_TEXTURE0);
        glBindTexture(GL_TEXTURE_2D, blackHoleTarget.texture);
        glUniform1i(glGetUniformLocation(presentProgram, "sourceTexture"), 0);

        glBindVertexArray(vao);
        glDrawArrays(GL_TRIANGLES, 0, 6);

        glfwSwapBuffers(window);
        glfwPollEvents();
    }

    glDeleteProgram(blackHoleProgram);
    glDeleteProgram(presentProgram);
    glDeleteTextures(1, &blackHoleTarget.texture);
    glDeleteFramebuffers(1, &blackHoleTarget.framebuffer);
    glDeleteBuffers(1, &vbo);
    glDeleteVertexArrays(1, &vao);

    glfwTerminate();
    return 0;
}