#  Metal Mesh Viewer

_A simple triangle mesh viewer for MacOS_

This application is a simple (triangle) mesh viewer that should be capable of rendering even large meshes interactively on a Mac. It was made by creating a project with the game template using Swift and Metal. Models are loaded using the Assimp library via a C/C++ bridge. Using Assimp for model loading ensures that a fairly wide range of file formats are supported. 

From a graphics point of view, the project is kept as simple as possible. The shading is based on matcaps. Smooth shading, flat shading and wireframe rendering modes are supported. While assets may contain textures, these are not used by the viewer since the focus is on the geometry.

## Why is this useful?

This project could be of interest to different people for different reasons. Of course, if you want a simple mesh viewer that happens to work on MacOS, this application might be of interest. For others, this could simply be a relatively compact example of how a Swift/Metal computer graphics program can be put together. After all this is a relatively simple app made from the Swift/Metal game-app default project in Xcode, and I myself learned several things from the development. Specifically, I learned
- how to make a simple app without a xib file or a story board (I threw out the xib file). This turned out to be much less confusing than trying to connect the visual representation of the interface with the code. 
- how to implement a recently opened files menu using the NSDocumentController (in a not otherwise document based application). Not as easy as I had hoped, but actually not as hard as I feared either.
- how to connect a C/C++ library to Swift code by creating a framework that bridges the two. This is actually why the project contains two targets. It turned out to be much easier to have C++ code in the project if I made a separate framework that is then included.
- how to manually set up the vertex, normal, and index buffers used to convey the mesh to the GPU. The example project creates an MDLMesh which is then turned into an MTKMesh. This is all good and well, but if the MDL asset loader is not used then it is actually nicer to roll your own simple mesh class.
- a bit about how Metal works and also Swift.

Moreover, the shaders also demonstrate some computer graphics techniques which might be of interest.
- The rendering is based on matcaps. Matcaps let you render fairly plausible surfaces and simply require an image of a sphere. The shading is then done by mapping the normal of the mesh to the pixel in the image of the sphere where the sphere would have the same normal. This is done, essentially, by dropping the z coordinate of the normal. 
- The wireframe rendering is based on computing the distance to the edges of the triangle using the barycentric coordinates of the triangle. When we are close to the edge, the color is changed to edge color. To go from barycentrics to edge distance, we need to divide each barycentric coordinate with the length of its screen space gradient. This method turned out to be easy to implement in Metal, and it does not require any attributes to be added to the vertices because Metal exposes the barycentrics as potential inputs to the fragment shader.
- For flat shading, we again use derivatives. The normal is computed per pixel as the cross product of the x and y derivatives of the eye space coordinates. Correct flat shading would otherwise require you to send the mesh to the GPU with every vertex repeated for each triangle since the vertices would need to have different normals for each triangle. Thus, computing the normal per pixel adds a bit of GPU work, but it can be done with the exact same input to the shaders as smooth shading.
- A benefit of the way flat shading and wireframe rendering has been implemented is that we can send exactly the same geometry with the same attributes for smooth shading, flat shading, and wireframe. Thus, we only need to change shaders and not modify the assets when rendering in a different mode. That makes the switch very fast - actually instant as far as I can tell.

## User Interaction

1. Keys:
    - 'f' toggles between flat and smooth shading. 
    - 'w' turns wireframe on and off. 
    - 'r' resets the virtual trackball.
    - 'x' makes X the up axis.
    - 'y' makes Y the up axis (this is the default).
    - 'z' makes Z the up axis.
    - '1'-'4' switches between matcaps.

2. Mouse/trackpad:
    - dragging with the left mouse button rotates whereas 
    - the right button pans. 
    - Scroll wheel - scroll gesture on a trackpad - zooms in and out.

## Prerequisites

Compiling this project requires that Xcode is installed. Also, assimp needs to be installed. This is as simple as `> sudo port install assimp` if you are using MacPorts. The Xcode project presupposes that assimp is installed in `/opt/local`. If you have installed it elsewhere, you may need to change locations for header files and library.



## Design Decisions
The decision to use Metal was based on the fact that on Apple platforms it is likely to be the fastest option, and I wanted an application that would provide interactive frame rates for large meshes. Using Metal without Swift would be tricky, so that led to the choice of programming language. 

Matcaps are used for shading in order to keep things simple while trying to make the shading as flexible and visually pleasing as possible. Matcaps provide a lot of options and visual "oomph" for almost no coding. I have embedded several matcap images in the project, and these are, of course, easy to change or add to.


