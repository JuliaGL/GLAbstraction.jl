# OpenGL tutorials in Julia

The code in this directory closely follows the tutorials at
https://open.gl/, but they are written in Julia rather than C++.  They
are not replacements for the (excellent) exposition of those
tutorials, but they show how to write the same code in Julia.

The file names match the corresponding page (e.g.,
`"context_creation.jl"`), sometimes with different versions (`1`, `2`,
etc.) representing either different portions of the chapter, or, in
some cases, alternative approaches to the same task.  This directory
also contains answers to the exercises posed at the end of some
chapters; if you are trying to learn OpenGL, you should try to
complete the exercises first on your own and look at the answer only
if you get stuck.

The earliest files are deliberately low-level, using just
[GLFW](https://github.com/JuliaGL/GLFW.jl) and
[ModernGL](https://github.com/JuliaGL/ModernGL.jl)---they are
essentially direct, minimal translations of the C++ code. Starting
with `drawing_polygons5.jl`, more of the "julian" conveniences
available in GLAbstraction are introduced.
