function openglerrorcallback(
                source::GLenum, typ::GLenum,
                id::GLuint, severity::GLenum,
                length::GLsizei, message::Ptr{GLchar},
                userParam::Ptr{Void}
            )
    errormessage =  "\n"*
                    " ________________________________________________________________\n"* 
                    "|\n"*
                    "| OpenGL Error!\n"*
                    "| source: $(GLENUM(source).name) :: type: $(GLENUM(typ).name)\n"*
                    "| "*ascii(bytestring(message, length))*"\n"*
                    "|________________________________________________________________\n"

    if typ == GL_DEBUG_TYPE_ERROR
        println(errormessage)
    else
        error(errormessage)
    end
    nothing
end

global const _openglerrorcallback = cfunction(openglerrorcallback, Void,
                                        (GLenum, GLenum,
                                        GLuint, GLenum,
                                        GLsizei, Ptr{GLchar},
                                        Ptr{Void}))