/*
 Copyright (c) 2012 The VCT Project

  This file is part of VoxelConeTracing and is an implementation of
  "Interactive Indirect Illumination Using Voxel Cone Tracing" by Crassin et al

  VoxelConeTracing is free software: you can redistribute it and/or modify
  it under the terms of the GNU General Public License as published by
  the Free Software Foundation, either version 3 of the License, or
  (at your option) any later version.

  VoxelConeTracing is distributed in the hope that it will be useful,
  but WITHOUT ANY WARRANTY; without even the implied warranty of
  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
  GNU General Public License for more details.

  You should have received a copy of the GNU General Public License
  along with VoxelConeTracing.  If not, see <http://www.gnu.org/licenses/>.
*/

/*!
* \author Dominik Lazarek (dominik.lazarek@gmail.com)
* \author Andreas Weinmann (andy.weinmann@gmail.com)
*/

#version 420 core

const uint NODE_MASK_NEXT = 0x3FFFFFFF;
const uint NODE_MASK_TAG = (0x00000001 << 31);
const uint NODE_MASK_TAG_STATIC = (0x00000003 << 30);
const uint NODE_NOT_FOUND = 0xFFFFFFFF;
const uint pow2[] = {1, 2, 4, 8, 16, 32, 64, 128, 256, 512, 1024};

layout(r32ui) uniform volatile uimageBuffer voxelFragmentListPosition;
layout(r32ui) uniform volatile uimageBuffer nodePool_next;
uniform uint voxelGridResolution;
uniform uint numLevels;

const uvec3 childOffsets[8] = {
  uvec3(0, 0, 0),
  uvec3(1, 0, 0),
  uvec3(0, 1, 0),
  uvec3(1, 1, 0),
  uvec3(0, 0, 1),
  uvec3(1, 0, 1),
  uvec3(0, 1, 1), 
  uvec3(1, 1, 1)};
  

uint vec3ToUintXYZ10(uvec3 val) {
    return (uint(val.z) & 0x000003FF)   << 20U
            |(uint(val.y) & 0x000003FF) << 10U 
            |(uint(val.x) & 0x000003FF);
}

uvec3 uintXYZ10ToVec3(uint val) {
    return uvec3(uint((val & 0x000003FF)),
                 uint((val & 0x000FFC00) >> 10U), 
                 uint((val & 0x3FF00000) >> 20U));
}

void flagNode(in uint nodeNext, in uint address) {
  nodeNext = (0x00000001 << 31) | (0x7FFFFFFF & nodeNext); 
  imageStore(nodePool_next, int(address), uvec4(nodeNext));
  memoryBarrier();
}

uint getNextAddress(in uint nodeNext) {
  return nodeNext & NODE_MASK_NEXT;
}

bool nextEmpty(in uint nodeNext) {
  return (nodeNext & NODE_MASK_NEXT) == 0U;
}

uint sizeOnLevel(in uint level) {
  return uint(voxelGridResolution / pow2[level]);
}

void main() {
  uint voxelPosU = imageLoad(voxelFragmentListPosition, gl_VertexID).x;
  uvec3 voxelPos = uintXYZ10ToVec3(voxelPosU);
  uint nodeNext = imageLoad(nodePool_next, 0).x;
  uint nodeAddress = 0;
  uvec3 nodePos = uvec3(0, 0, 0);
  uint childLevel = 1;
  uint sideLength = sizeOnLevel(childLevel);

  // Loop as long as node != voxel
  for(uint iLevel = 0; iLevel < numLevels -1; ++iLevel) {
      if (nextEmpty(nodeNext)) {
        flagNode(nodeNext, nodeAddress);
        return;
      }

    sideLength = sizeOnLevel(childLevel);
    uint childStartAddress = getNextAddress(nodeNext);

    for (uint iChild = 0; iChild < 8; ++iChild) {
      uvec3 posMin = nodePos + childOffsets[iChild] * uvec3(sideLength);
      uvec3 posMax = posMin + uvec3(sideLength);

      if (voxelPos.x >= posMin.x && voxelPos.x < posMax.x &&
          voxelPos.y >= posMin.y && voxelPos.y < posMax.y &&
          voxelPos.z >= posMin.z && voxelPos.z < posMax.z ) {
            uint childAddress = childStartAddress + iChild;
            uint childNodeNext = imageLoad(nodePool_next, int(childAddress)).x;

            // Restart while-loop with the child node (aka recursion)
            nodeNext = childNodeNext;
            nodeAddress = childAddress;
            nodePos = posMin;
            childLevel += 1;
        } // if
      } // for
    } // while
}  // main
