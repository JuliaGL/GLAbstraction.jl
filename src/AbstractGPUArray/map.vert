{{GLSL_VERSION}}

{{arg1_type}} arg1;
{{arg2_type}} arg2;

{{out1_type}} out1;

{{KERNEL}}

void main() {
    out1 = kernel(arg1, arg2);
}
