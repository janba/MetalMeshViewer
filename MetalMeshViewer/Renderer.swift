//
//  Renderer.swift
//  MetalMeshViewer
//
//  Created by Andreas Bærentzen on 06/11/2021.
//
// This Renderer class was (along with most of the project) based off of Xcode's Metal Game example
// which just shows a textured cube.
// The code was reworked significantly in order to make it simpler, to support meshes loaded using Assimp
// and also to support user interaction.

import Metal
import MetalKit
import AppKit
import simd
import assimp

/// SimpleMesh is a class that contains the vertices, normals, and vertex indices of a mesh.
/// For convenience it also caches the axis aligned bounding box. There is also a Metal Kit mesh
/// class, MTKMesh, but it is a little less simple and I really like simple.
struct SimpleMesh {
    var No_vertices: Int = 0
    var No_triangles: Int = 0
    var Vertex_buffer: MTLBuffer?
    var Normal_buffer: MTLBuffer?
    var Indices: MTLBuffer?
    var bbox_min = vector_float3(1e30,1e30,1e30)
    var bbox_max = vector_float3(-1e30,-1e30,-1e30)

    init?(asset_url: URL, device: MTLDevice) {
        let importer = assimp.new_importer(asset_url.path.cString(using: String.Encoding.ascii))
       
        if valid(importer) == 0 {
            print("Unable to import mesh")
            return nil
        }
        
        No_vertices = Int(no_vertices(importer))
        No_triangles = Int(no_trianges(importer))
        
        if No_triangles == 0 {
            print("Mesh contained no triangles")
            return nil
        }
        
        var V: [Float32] = Array(repeating: 0, count: (No_vertices*3))
        var N: [Float32] = Array(repeating: 0, count: (No_vertices*3))
        var I: [Int32] = Array(repeating: 0, count: (No_triangles*3))
        
        get_vertices(importer, &V)
        get_normals(importer, &N)
        get_indices(importer, &I)
        
        Vertex_buffer = device.makeBuffer(bytes: &V, length: No_vertices*3*4, options: .cpuCacheModeWriteCombined)
        Normal_buffer = device.makeBuffer(bytes: &N, length: No_vertices*3*4, options: .cpuCacheModeWriteCombined)
        Indices = device.makeBuffer(bytes: &I, length: No_triangles*3*4, options: .cpuCacheModeWriteCombined)

        for i in 0..<No_vertices {
            let p = vector_float3(x: V[3*i], y: V[3*i+1], z: V[3*i+2])
            bbox_min = min(bbox_min, p)
            bbox_max = max(bbox_max, p)
        }
    }
}

class Renderer: NSObject, MTKViewDelegate {
    
    // All of the state directly needed by Metal
    public let device: MTLDevice
    let metalkit_view: MTKView
    let command_queue: MTLCommandQueue
    var uniform_buffer: MTLBuffer
    var uniforms: UnsafeMutablePointer<Uniforms>
    var pipeline_state: MTLRenderPipelineState
    var depth_state: MTLDepthStencilState
    var matcaps: [MTLTexture] = []

    // THe mesh itself also contains some Metal buffers
    var mesh: SimpleMesh?

    // The remaining state (i.e. instance variables, class members) which
    // are needed for the user interaction.
    var projection_matrix: matrix_float4x4 = matrix_float4x4()
    var azimuth_angle: Float = 0
    var zenith_angle: Float = 0
    var proximity: Float = 1
    var translate: SIMD2<Float> = SIMD2<Float>(0,0)
    var up_axis = 1
    var current_matcap = 0
    var no_matcaps = 0
    var cached_size: CGSize
    var screen_scaling: Float = 2.5


    init?(metalKitView: MTKView) {
        self.metalkit_view = metalKitView
        self.device = metalKitView.device!
        self.command_queue = self.device.makeCommandQueue()!
        self.cached_size = metalKitView.drawableSize

        self.uniform_buffer = self.device.makeBuffer(length:MemoryLayout<Uniforms>.size,
                                                           options:[MTLResourceOptions.storageModeShared])!
        self.uniform_buffer.label = "UniformBuffer"
        uniforms = UnsafeMutableRawPointer(uniform_buffer.contents()).bindMemory(to:Uniforms.self, capacity:1)

        metalKitView.depthStencilPixelFormat = MTLPixelFormat.depth32Float_stencil8
        metalKitView.colorPixelFormat = MTLPixelFormat.bgra8Unorm_srgb
        metalKitView.sampleCount = 1

        do {
            pipeline_state = try Renderer.build_pipeline(device: device,
                                                        metalKitView: metalKitView,
                                                        draw_wire: false,
                                                        draw_flat: false)
        } catch {
            print("Unable to compile render pipeline state.  Error info: \(error)")
            return nil
        }

        let depthStateDescriptor = MTLDepthStencilDescriptor()
        depthStateDescriptor.depthCompareFunction = MTLCompareFunction.less
        depthStateDescriptor.isDepthWriteEnabled = true
        self.depth_state = device.makeDepthStencilState(descriptor:depthStateDescriptor)!

        let asset_url = Bundle.main.url(forResource: "b", withExtension: "obj")!
        mesh = SimpleMesh(asset_url: asset_url, device: device)
        if mesh != nil {
            proximity = length(mesh!.bbox_max-mesh!.bbox_min)
        } else {
            return nil
        }

        for fn in ["matcap0", "matcap1", "matcap2"] {
            let mat_cap = try? Renderer.load_texture(device: device, textureName: fn)
            
            if mat_cap != nil {
                matcaps.append(mat_cap!)
                no_matcaps += 1
            }
        }
        
        super.init()

    }
    
    func load_mesh(asset_url: URL) -> Bool {
        let _mesh = SimpleMesh(asset_url: asset_url, device: device)
        if _mesh != nil {
            mesh = _mesh
            proximity = length(mesh!.bbox_max-mesh!.bbox_min)
            update_projection_matrix()
        } else {
            return false
        }
        return true
    }


    class func build_pipeline(device: MTLDevice,
                              metalKitView: MTKView,
                              draw_wire: Bool,
                              draw_flat: Bool) throws -> MTLRenderPipelineState {
        /// Build a render state pipeline object

        let library = device.makeDefaultLibrary()

        let vertexFunction: MTLFunction?
        var fragmentFunction: MTLFunction?
        
        if draw_wire && draw_flat {
            vertexFunction = library?.makeFunction(name: "vertexShader_flat")
            fragmentFunction = library?.makeFunction(name: "fragmentShader_flat_wire")
        }
        else if draw_wire {
            vertexFunction = library?.makeFunction(name: "vertexShader")
            fragmentFunction = library?.makeFunction(name: "fragmentShader_wire")
        }
        else if draw_flat{
            vertexFunction = library?.makeFunction(name: "vertexShader_flat")
            fragmentFunction = library?.makeFunction(name: "fragmentShader_flat")
        }
        else {
            vertexFunction = library?.makeFunction(name: "vertexShader")
            fragmentFunction = library?.makeFunction(name: "fragmentShader")
        }

        let pipelineDescriptor = MTLRenderPipelineDescriptor()
        pipelineDescriptor.label = "RenderPipeline"
        pipelineDescriptor.sampleCount = metalKitView.sampleCount
        pipelineDescriptor.vertexFunction = vertexFunction
        pipelineDescriptor.fragmentFunction = fragmentFunction
        
        let mtlVertexDescriptor = MTLVertexDescriptor()
        mtlVertexDescriptor.attributes[VertexAttribute.position.rawValue].format = MTLVertexFormat.float3
        mtlVertexDescriptor.attributes[VertexAttribute.position.rawValue].offset = 0
        mtlVertexDescriptor.attributes[VertexAttribute.position.rawValue].bufferIndex = BufferIndex.meshPositions.rawValue
        mtlVertexDescriptor.attributes[VertexAttribute.normal.rawValue].format = MTLVertexFormat.float3
        mtlVertexDescriptor.attributes[VertexAttribute.normal.rawValue].offset = 0
        mtlVertexDescriptor.attributes[VertexAttribute.normal.rawValue].bufferIndex = BufferIndex.meshGenerics.rawValue
        mtlVertexDescriptor.layouts[BufferIndex.meshPositions.rawValue].stride = 12
        mtlVertexDescriptor.layouts[BufferIndex.meshPositions.rawValue].stepRate = 1
        mtlVertexDescriptor.layouts[BufferIndex.meshPositions.rawValue].stepFunction = MTLVertexStepFunction.perVertex
        mtlVertexDescriptor.layouts[BufferIndex.meshGenerics.rawValue].stride = 12
        mtlVertexDescriptor.layouts[BufferIndex.meshGenerics.rawValue].stepRate = 1
        mtlVertexDescriptor.layouts[BufferIndex.meshGenerics.rawValue].stepFunction = MTLVertexStepFunction.perVertex
        pipelineDescriptor.vertexDescriptor = mtlVertexDescriptor

        pipelineDescriptor.colorAttachments[0].pixelFormat = metalKitView.colorPixelFormat
        pipelineDescriptor.depthAttachmentPixelFormat = metalKitView.depthStencilPixelFormat
        pipelineDescriptor.stencilAttachmentPixelFormat = metalKitView.depthStencilPixelFormat

        return try device.makeRenderPipelineState(descriptor: pipelineDescriptor)
    }
    
    func rebuild_pipeline(draw_wire:Bool=false, draw_flat: Bool=false) {
        do {
            pipeline_state = try Renderer.build_pipeline(device: device,
                                                                       metalKitView: self.metalkit_view,
                                                                       draw_wire: draw_wire,
                                                                       draw_flat: draw_flat)
        } catch {
            print("Unable to compile render pipeline state.  Error info: \(error)")
        }
    }

    class func load_texture(device: MTLDevice,
                           textureName: String) throws -> MTLTexture {
        /// Load texture data with optimal parameters for sampling

        let textureLoader = MTKTextureLoader(device: device)

        let textureLoaderOptions = [
            MTKTextureLoader.Option.textureUsage: NSNumber(value: MTLTextureUsage.shaderRead.rawValue),
            MTKTextureLoader.Option.textureStorageMode: NSNumber(value: MTLStorageMode.`private`.rawValue)
        ]

        return try textureLoader.newTexture(name: textureName,
                                            scaleFactor: 1.0,
                                            bundle: nil,
                                            options: textureLoaderOptions)

    }
    
    public func set_up_axis(axis: Int) {
        up_axis = axis
    }
    
    public func reset_trackball() {
        azimuth_angle = 0
        zenith_angle = 0
        translate = SIMD2<Float>(0,0)
        proximity = length(mesh!.bbox_max-mesh!.bbox_min)
    }
    
    public func rotate(delta_x: Float, delta_y: Float) {
        azimuth_angle += .pi * delta_x / 100.0
        zenith_angle += .pi * delta_y / 200.0
    }
    
    public func pan(delta_x: Float, delta_y: Float) {
        let tan_fovy = tanf(radians_from_degrees(0.5 * 65))
        let tsx = screen_scaling*proximity * tan_fovy / Float(0.5*cached_size.width)
        let tsy = screen_scaling*proximity * tan_fovy / Float(0.5*cached_size.height)
        translate +=  SIMD2<Float>(tsx * delta_x, -tsy * delta_y)
    }

    public func change_proximity(delta_prox: Float) {
        proximity *= pow(0.99, delta_prox)
        update_projection_matrix()
    }
    
    public func set_matcap(matcap_no: Int) {
        if 0 <= matcap_no && matcap_no < no_matcaps {
            current_matcap = matcap_no
        }
    }
    

    private func update_viewer_state() {
        // Below we copy the projectionmatrix into the buffer whence uniforms are sourced for the
        // vertex and fragment shaders. Swift has a slightly funky syntax where an Unsafe pointer is
        // dereferenced as ptr.pointee instead of (*ptr) in C or C++ og Obj C.
        uniforms.pointee.projectionMatrix = projection_matrix
        
        var upMatrix: simd_float4x4
        if up_axis==0 {
            upMatrix = matrix4x4_rotation(radians: 0.5*355.0/113.0,
                                          axis: SIMD3<Float>(0,0,1))
        }
        else if up_axis==1 {
            upMatrix = matrix_float4x4.init(columns:(vector_float4(1, 0, 0, 0),
                                                     vector_float4(0, 1, 0, 0),
                                                     vector_float4(0, 0, 1, 0),
                                                     vector_float4(0, 0, 0, 1)))
        }
        else {
            upMatrix = matrix4x4_rotation(radians: -0.5*355.0/113.0,
                                          axis: SIMD3<Float>(1,0,0))
        }

        
        let center = 0.5*(mesh!.bbox_max-mesh!.bbox_min)+mesh!.bbox_min
        let centerMatrix = matrix4x4_translation(-center[0], -center[1], -center[2])
        let azimuthRotationAxis = SIMD3<Float>(0,1,0)
        let zenithRotationAxis = SIMD3<Float>(1,0,0)
        let azimuthMatrix = matrix4x4_rotation(radians: azimuth_angle, axis: azimuthRotationAxis)
        let zenithMatrix = matrix4x4_rotation(radians: zenith_angle, axis: zenithRotationAxis)
        let modelMatrix = simd_mul(simd_mul(simd_mul(zenithMatrix, azimuthMatrix), upMatrix), centerMatrix)
        let viewMatrix = matrix4x4_translation(translate.x,
                                               translate.y,
                                               -proximity)
        uniforms.pointee.modelViewMatrix = simd_mul(viewMatrix, modelMatrix)
    }

    func draw(in view: MTKView) {
        // This is where the actual drawing takes place. It has been dumbed down a bit, but it
        // is essentially the example code. The changes are mostly to remove some semaphore code
        // that I believe is mostly to make the app more resource parsimonious, but not sure.

        if let commandBuffer = command_queue.makeCommandBuffer() {
            
            self.update_viewer_state()
            
            /// Delay getting the currentRenderPassDescriptor until we absolutely need it to avoid
            ///   holding onto the drawable and blocking the display pipeline any longer than necessary
            if let renderPassDescriptor = view.currentRenderPassDescriptor {
                
                /// Final pass rendering code here
                if let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor) {
                    view.clearColor = MTLClearColorMake(1, 1, 1, 1)
                    
                    renderEncoder.setCullMode(.back)
                    renderEncoder.setFrontFacing(.counterClockwise)

                    renderEncoder.setRenderPipelineState(pipeline_state)
                    
                    renderEncoder.setDepthStencilState(depth_state)
                    
                    renderEncoder.setVertexBuffer(mesh!.Vertex_buffer, offset:0, index: VertexAttribute.position.rawValue)
                    renderEncoder.setVertexBuffer(mesh!.Normal_buffer, offset:0, index: VertexAttribute.normal.rawValue)
                    renderEncoder.setVertexBuffer(uniform_buffer, offset:0, index: BufferIndex.uniforms.rawValue)

                    renderEncoder.setFragmentBuffer(uniform_buffer, offset:0, index: BufferIndex.uniforms.rawValue)
                    renderEncoder.setFragmentTexture(matcaps[current_matcap], index: TextureIndex.color.rawValue)

                    renderEncoder.drawIndexedPrimitives(type: .triangle,
                                                        indexCount: mesh!.No_triangles*3,
                                                        indexType: .uint32,
                                                        indexBuffer: mesh!.Indices!,
                                                        indexBufferOffset: 0)
                    renderEncoder.endEncoding()
                    
                    if let drawable = view.currentDrawable {
                        commandBuffer.present(drawable)
                    }
                }
            }
            commandBuffer.commit()
        }
    }
    
    func update_projection_matrix() {
        let aspect = Float(cached_size.width) / Float(cached_size.height)
        projection_matrix = matrix_perspective_right_hand(fovyRadians: radians_from_degrees(65),
                                                         aspectRatio:aspect,
                                                         nearZ: 0.1 * proximity,
                                                         farZ: 10.0 * proximity)
    }

    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        /// Respond to drawable size or orientation changes here
        cached_size = size
        update_projection_matrix()
    }
}

// Generic matrix math utility functions. These are as I found them.

func matrix4x4_rotation(radians: Float, axis: SIMD3<Float>) -> matrix_float4x4 {
    let unitAxis = normalize(axis)
    let ct = cosf(radians)
    let st = sinf(radians)
    let ci = 1 - ct
    let x = unitAxis.x, y = unitAxis.y, z = unitAxis.z
    return matrix_float4x4.init(columns:(vector_float4(    ct + x * x * ci, y * x * ci + z * st, z * x * ci - y * st, 0),
                                         vector_float4(x * y * ci - z * st,     ct + y * y * ci, z * y * ci + x * st, 0),
                                         vector_float4(x * z * ci + y * st, y * z * ci - x * st,     ct + z * z * ci, 0),
                                         vector_float4(                  0,                   0,                   0, 1)))
}

func matrix4x4_translation(_ translationX: Float, _ translationY: Float, _ translationZ: Float) -> matrix_float4x4 {
    return matrix_float4x4.init(columns:(vector_float4(1, 0, 0, 0),
                                         vector_float4(0, 1, 0, 0),
                                         vector_float4(0, 0, 1, 0),
                                         vector_float4(translationX, translationY, translationZ, 1)))
}

func matrix_perspective_right_hand(fovyRadians fovy: Float, aspectRatio: Float, nearZ: Float, farZ: Float) -> matrix_float4x4 {
    let ys = 1 / tanf(fovy * 0.5)
    let xs = ys / aspectRatio
    let zs = farZ / (nearZ - farZ)
    return matrix_float4x4.init(columns:(vector_float4(xs,  0, 0,   0),
                                         vector_float4( 0, ys, 0,   0),
                                         vector_float4( 0,  0, zs, -1),
                                         vector_float4( 0,  0, zs * nearZ, 0)))
}

func radians_from_degrees(_ degrees: Float) -> Float {
    return (degrees / 180) * .pi
}
