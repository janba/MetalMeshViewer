//
//  import_assets.cpp
//  assimp
//
//  Created by Andreas Bærentzen on 15/11/2021.
//

#include <iostream>
#include <assimp/Importer.hpp>      // C++ importer interface
#include <assimp/scene.h>           // Output data structure
#include <assimp/postprocess.h>     // Post processing flags

// Below, we redeclare the functions we export with C linkage.
// This is necessary because we would get wrong linkage otherwise, and
// for reasons I do not fully understand, I cannot include the assimp.h
// file.
extern "C" {
void* new_importer(const char* file);
int no_trianges(void* _importer_ptr);
int no_vertices(void* _importer_ptr);
void get_vertices(void* _importer_ptr, float* vertices);
void get_normals(void* _importer_ptr, float* normals);
void get_indices(void* _importer_ptr, int32_t* indices);
void delete_importer(void* importer_ptr);
int valid(void* _importer_ptr);
}


using namespace std;

void* new_importer(const char* file) {
    Assimp::Importer* importer_ptr = new Assimp::Importer;

    // And have it read the given file with some example postprocessing
    // Usually - if speed is not the most important aspect for you - you'll
    // probably to request more postprocessing than we do in this example.
    importer_ptr->ReadFile( string(file),
                           aiProcess_Triangulate            |
                           aiProcess_JoinIdenticalVertices  |
                           aiProcess_GenSmoothNormals       |
                           aiProcess_ForceGenNormals        |
                           aiProcess_OptimizeGraph          |
                           aiProcess_SortByPType);

    return reinterpret_cast<void*>(importer_ptr);
}

int valid(void* _importer_ptr) {
    auto importer_ptr = reinterpret_cast<Assimp::Importer*>(_importer_ptr);
    if (importer_ptr->GetScene() != 0) {
        return 1;
    }
    cout << "From AssImp: " << importer_ptr->GetErrorString() << endl;
    return 0;
}

int no_trianges(void* _importer_ptr) {
    auto importer_ptr = reinterpret_cast<Assimp::Importer*>(_importer_ptr);
    auto mesh_ptr = importer_ptr->GetScene()->mMeshes[0];
    if (mesh_ptr != 0) {
        return mesh_ptr->mNumFaces;
    }
    return 0;
}

int no_vertices(void* _importer_ptr) {
    auto importer_ptr = reinterpret_cast<Assimp::Importer*>(_importer_ptr);
    auto mesh_ptr = importer_ptr->GetScene()->mMeshes[0];
    if (mesh_ptr != 0) {
        return mesh_ptr->mNumVertices;
    }
    return 0;
}

void get_vertices(void* _importer_ptr, float* vertices) {
    auto importer_ptr = reinterpret_cast<Assimp::Importer*>(_importer_ptr);
    auto mesh_ptr = importer_ptr->GetScene()->mMeshes[0];
    if (mesh_ptr != 0) {
        for (int j=0; j<mesh_ptr->mNumVertices; ++j) {
            vertices[3*j+0] = mesh_ptr->mVertices[j].x;
            vertices[3*j+1] = mesh_ptr->mVertices[j].y;
            vertices[3*j+2] = mesh_ptr->mVertices[j].z;
        }
    }
}

void get_normals(void* _importer_ptr, float* normals) {
    auto importer_ptr = reinterpret_cast<Assimp::Importer*>(_importer_ptr);
    auto mesh_ptr = importer_ptr->GetScene()->mMeshes[0];
    if (mesh_ptr != 0) {
        for (int j=0; j<mesh_ptr->mNumVertices; ++j) {
            normals[3*j+0] = mesh_ptr->mNormals[j].x;
            normals[3*j+1] = mesh_ptr->mNormals[j].y;
            normals[3*j+2] = mesh_ptr->mNormals[j].z;
        }
    }
}

void get_indices(void* _importer_ptr, int32_t* indices) {
    auto importer_ptr = reinterpret_cast<Assimp::Importer*>(_importer_ptr);
    auto mesh_ptr = importer_ptr->GetScene()->mMeshes[0];
    if (mesh_ptr != 0) {
        for (int j=0; j<mesh_ptr->mNumFaces; ++j) {
            indices[3*j+0] = mesh_ptr->mFaces[j].mIndices[0];
            indices[3*j+1] = mesh_ptr->mFaces[j].mIndices[1];
            indices[3*j+2] = mesh_ptr->mFaces[j].mIndices[2];
        }
    }
}

void delete_importer(void* importer_ptr) {
    delete reinterpret_cast<Assimp::Importer*>(importer_ptr);
}
