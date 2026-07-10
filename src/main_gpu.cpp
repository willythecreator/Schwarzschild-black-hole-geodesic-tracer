#include <GL/glew.h>
#include <GLFW/glfw3.h>
#include <iostream>
#include <fstream>
#include <sstream>
#include <string>
#include <cmath>

struct V3
{
    float x, y, z;
};
V3 normalize(V3 v)
{
    float l = std::sqrt(v.x * v.x + v.y * v.y + v.z * v.z);
    return {v.x / l, v.y / l, v.z / l};
}
V3 cross(V3 a, V3 b)
{
    return {a.y * b.z - a.z * b.y, a.z * b.x - a.x * b.z, a.x * b.y - a.y * b.x};
}
V3 operator+(V3 a, V3 b) { return {a.x + b.x, a.y + b.y, a.z + b.z}; }
V3 operator-(V3 a, V3 b) { return {a.x - b.x, a.y - b.y, a.z - b.z}; }
V3 operator*(V3 v, float s) { return {v.x * s, v.y * s, v.z * s}; }

static std::string readFile(const std::string &path)
{
    std::ifstream f(path);
    if (!f)
    {
        std::cerr << "Cannot open: " << path << "\n";
        return "";
    }
    std::ostringstream ss;
    ss << f.rdbuf();
    return ss.str();
}

static GLuint compileShader(GLenum type, const std::string &src)
{
    GLuint s = glCreateShader(type);
    const char *c = src.c_str();
    glShaderSource(s, 1, &c, nullptr);
    glCompileShader(s);
    GLint ok;
    glGetShaderiv(s, GL_COMPILE_STATUS, &ok);
    if (!ok)
    {
        char log[1024];
        glGetShaderInfoLog(s, 1024, nullptr, log);
        std::cerr << "Shader error:\n"
                  << log << "\n";
    }
    return s;
}

static GLuint buildProgram(const std::string &vertPath, const std::string &fragPath)
{
    GLuint vert = compileShader(GL_VERTEX_SHADER, readFile(vertPath));
    GLuint frag = compileShader(GL_FRAGMENT_SHADER, readFile(fragPath));
    GLuint prog = glCreateProgram();
    glAttachShader(prog, vert);
    glAttachShader(prog, frag);
    glLinkProgram(prog);
    glDeleteShader(vert);
    glDeleteShader(frag);
    return prog;
}

static V3 camPos = {0.f, 0.5f, -30.f};
static float yaw = 90.f;
static float pitch = -1.0f;
static float speed = 5.f;
static double lastX = 640, lastY = 360;
static bool firstMouse = true;

static V3 forward()
{
    float y = yaw * 3.14159f / 180.f, p = pitch * 3.14159f / 180.f;
    return normalize({std::cos(p) * std::cos(y), std::sin(p), std::cos(p) * std::sin(y)});
}
static V3 right() { return normalize(cross(forward(), {0, 1, 0})); }
static V3 up() { return normalize(cross(right(), forward())); }

static void mouseCallback(GLFWwindow *, double xpos, double ypos)
{
    if (firstMouse)
    {
        lastX = xpos;
        lastY = ypos;
        firstMouse = false;
    }
    float dx = float(xpos - lastX) * 0.1f;
    float dy = float(lastY - ypos) * 0.1f;
    lastX = xpos;
    lastY = ypos;
    yaw += dx;
    pitch = std::max(-89.f, std::min(89.f, pitch + dy));
}

static void processInput(GLFWwindow *w, float dt)
{
    if (glfwGetKey(w, GLFW_KEY_ESCAPE) == GLFW_PRESS)
        glfwSetWindowShouldClose(w, true);
    V3 fwd = forward(), rgt = right();
    if (glfwGetKey(w, GLFW_KEY_W) == GLFW_PRESS)
        camPos = camPos + fwd * (speed * dt);
    if (glfwGetKey(w, GLFW_KEY_S) == GLFW_PRESS)
        camPos = camPos - fwd * (speed * dt);
    if (glfwGetKey(w, GLFW_KEY_A) == GLFW_PRESS)
        camPos = camPos - rgt * (speed * dt);
    if (glfwGetKey(w, GLFW_KEY_D) == GLFW_PRESS)
        camPos = camPos + rgt * (speed * dt);
    if (glfwGetKey(w, GLFW_KEY_SPACE) == GLFW_PRESS)
        camPos.y += speed * dt;
    if (glfwGetKey(w, GLFW_KEY_LEFT_SHIFT) == GLFW_PRESS)
        camPos.y -= speed * dt;
    if (glfwGetKey(w, GLFW_KEY_Q) == GLFW_PRESS)
        speed = 15.f;
    else if (glfwGetKey(w, GLFW_KEY_E) == GLFW_PRESS)
        speed = 1.f;
    else
        speed = 5.f;
}

int main()
{
    if (!glfwInit())
    {
        std::cerr << "GLFW init failed\n";
        return -1;
    }
    glfwWindowHint(GLFW_CONTEXT_VERSION_MAJOR, 3);
    glfwWindowHint(GLFW_CONTEXT_VERSION_MINOR, 3);
    glfwWindowHint(GLFW_OPENGL_PROFILE, GLFW_OPENGL_CORE_PROFILE);

    GLFWwindow *window = glfwCreateWindow(1280, 720, "Schwarzschild Black Hole Tracer", nullptr, nullptr);
    if (!window)
    {
        std::cerr << "Window failed\n";
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
        std::cerr << "GLEW init failed\n";
        return -1;
    }

    float verts[] = {-1, -1, 1, -1, 1, 1, -1, -1, 1, 1, -1, 1};
    GLuint vao, vbo;
    glGenVertexArrays(1, &vao);
    glBindVertexArray(vao);
    glGenBuffers(1, &vbo);
    glBindBuffer(GL_ARRAY_BUFFER, vbo);
    glBufferData(GL_ARRAY_BUFFER, sizeof(verts), verts, GL_STATIC_DRAW);
    glVertexAttribPointer(0, 2, GL_FLOAT, GL_FALSE, 0, nullptr);
    glEnableVertexAttribArray(0);

    GLuint prog = buildProgram("../src/shaders/vert.glsl", "../src/shaders/frag.glsl");
    glUseProgram(prog);

    double prevTime = glfwGetTime();
    float elapsed = 0.f;
    int frameCount = 0;
    double fpsTimer = glfwGetTime();

    while (!glfwWindowShouldClose(window))
    {
        double now = glfwGetTime();
        float dt = float(now - prevTime);
        prevTime = now;
        elapsed += dt;
        frameCount++;

        if (now - fpsTimer >= 1.0)
        {
            char title[64];
            std::snprintf(title, sizeof(title),
                          "Schwarzschild Black Hole Tracer  |  %d FPS", frameCount);
            glfwSetWindowTitle(window, title);
            frameCount = 0;
            fpsTimer = now;
        }

        processInput(window, dt);

        int W, H;
        glfwGetFramebufferSize(window, &W, &H);
        glViewport(0, 0, W, H);

        V3 fwd = forward(), rgt = right(), u = up();
        glUniform3f(glGetUniformLocation(prog, "camPos"), camPos.x, camPos.y, camPos.z);
        glUniform3f(glGetUniformLocation(prog, "camForward"), fwd.x, fwd.y, fwd.z);
        glUniform3f(glGetUniformLocation(prog, "camRight"), rgt.x, rgt.y, rgt.z);
        glUniform3f(glGetUniformLocation(prog, "camUp"), u.x, u.y, u.z);
        glUniform1f(glGetUniformLocation(prog, "fov"), 60.f);
        glUniform1f(glGetUniformLocation(prog, "aspectRatio"), float(W) / float(H));
        glUniform1f(glGetUniformLocation(prog, "time"), elapsed);

        glClear(GL_COLOR_BUFFER_BIT);
        glBindVertexArray(vao);
        glDrawArrays(GL_TRIANGLES, 0, 6);

        glfwSwapBuffers(window);
        glfwPollEvents();
    }

    glDeleteProgram(prog);
    glDeleteBuffers(1, &vbo);
    glDeleteVertexArrays(1, &vao);
    glfwTerminate();
    return 0;
}