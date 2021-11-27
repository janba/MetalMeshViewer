//
//  assimp.h
//  assimp
//
//  Created by Andreas Bærentzen on 15/11/2021.
//

#import <Foundation/Foundation.h>

//! Project version number for assimp.
FOUNDATION_EXPORT double assimpVersionNumber;

//! Project version string for assimp.
FOUNDATION_EXPORT const unsigned char assimpVersionString[];

// Below we declare the framework functions that we wish to expose.
// One might think I could just include the header, but

/// Create a new assimp importer. This function loads the mesh and returns a pointer to the identifier which can
/// be used to query for the mesh data.
void* new_importer(const char* file);

/// Return number of triangles for a given importer
int no_trianges(void* _importer_ptr);

/// Return number of vertices for a given importer
int no_vertices(void* _importer_ptr);

/// Get a pointer to the vertices
void get_vertices(void* _importer_ptr, float* vertices);

/// Get a pointer to the normals
void get_normals(void* _importer_ptr, float* normals);

/// Get a pointer to the indices
void get_indices(void* _importer_ptr, int32_t* indices);

/// Delete the importer - freeing resources.
void delete_importer(void* importer_ptr);

/// Check validity. It is a good idea to call this before getting the mesh data.
int valid(void* _importer_ptr);
