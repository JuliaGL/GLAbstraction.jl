#==
   Make debugging interface flexible (hopefully the compile step will remove
   dead code when not optimizing. Higher level values mean more intrusive
   (may render app unusable  if too much output is generated)
       Level (ORed bit values)
             1 : add traceback for constructors and related
             4 : print uniforms
             8 : print vertices
            16 : reserved for GLTypes.GLVertexArray
            32 : reserved for postRenderFunctions
==#
debugFlagOn = isdefined(:GLRenderDebugLevel)
debugLevel  = debugFlagOn ? GLRenderDebugLevel : 0

#==  Set the debug parameters; if this function is not used, GLRenderDebugLevel
     must be set at time of package loading.
==#
function setDebugLevels(flagOn::Bool,level::Int)
    global debugFlagOn
    global debugLevel
    debugFlagOn = flagOn
    debugLevel  = flagOn ? level : 0
end

function debugRenderUnif(program,renderobject)
       debugLevel & 4 == 0 && return
       id = program.id
       println("In debugRenderUnif program.id=$id")
       for (key,value) in program.uniformloc
           if haskey(renderobject.uniforms, key)
               tv=typeof(value)
               tu=typeof(renderobject.uniforms[key])
               println("\t$key corresponds to value with type=$tv")
               println("\t   and renderobject.uniform[$key] with type=$tu")
           else
               println("\t key $key not found in  renderobject")
           end
       end
end

function debugRenderVertex(va::GLVertexArray,  mode::GLenum=GL_TRIANGLES)
       debugLevel & 8 == 0 && return
       ln  = va.length
       iln = va.indexlength
       id =  va.id
       println("In debugVertex mode=$mode, \tGLVertexArray.id=$id,\tlength=$ln,\tindexlength=$iln")
end


function debugPostRenderFn(fn,args...)
    debugLevel & 32 == 0 && return
    fntyp = typeof(fn)
    
    println("In debugPostRenderFn\t$fntyp\t$fn" )
    println("   args=$args")
    println("++++ end debugPostRenderFn output ++++\n")
end
                
############  end of debugging section ############
       
function render(list::AbstractVector)
    for elem in list
        render(elem)
    end
end


function render(renderobject::RenderObject, vertexarray=renderobject.vertexarray)
    for elem in renderobject.prerenderfunctions
        elem[1](elem[2]...)
    end
    program = vertexarray.program
    glUseProgram(program.id)

    debugFlagOn && debugRenderUnif(program,renderobject) ## debug

    for (key,value) in program.uniformloc
        haskey(renderobject.uniforms, key) && gluniform(value..., renderobject.uniforms[key])
    end
    for elem in renderobject.postrenderfunctions

        debugFlagOn && debugPostRenderFn(elem[1],elem[2]...) ## debug
        # apply elem[1]
        elem[1](elem[2]...)
    end
end


function render(vao::GLVertexArray, mode::GLenum=GL_TRIANGLES)
    debugFlagOn && debugRenderVertex(vao, mode)         ## debug

    glBindVertexArray(vao.id)
    if vao.indexlength > 0
        glDrawElements(mode, vao.indexlength, GL_UNSIGNED_INT, C_NULL)
    else
        glDrawArrays(mode, 0, vao.length)
    end
end

function renderinstanced(vao::GLVertexArray, amount::Integer, primitive=GL_TRIANGLES)
    glBindVertexArray(vao.id)
    #If you get an error here, notify me and try:
    #glDrawElementsInstancedEXT(primitive, vao.indexlength, GL_UNSIGNED_INT, C_NULL, amount)
    glDrawElementsInstanced(primitive, vao.indexlength, GL_UNSIGNED_INT, C_NULL, amount)
end

#handle all uniform objects



##############################################################################################
#  Generic render functions
#####
function enabletransparency()
    glEnablei(GL_BLEND, 0)
    glDisablei(GL_BLEND, 1)
    glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA)
end

