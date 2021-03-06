#include "stereoLite.h"

/// scalar field to upscale
texture<float, cudaTextureType2D, cudaReadModeElementType> texCoarse;
texture<float2, cudaTextureType2D, cudaReadModeElementType> texCoarseFloat2;

__global__ 
void LiteUpscaleKernel(int width, int height, int stride, float scale, float *out)
{
	const int ix = threadIdx.x + blockIdx.x * blockDim.x;
	const int iy = threadIdx.y + blockIdx.y * blockDim.y;

	if (ix >= width || iy >= height) return;

	float x = ((float)ix + 0.5f) / (float)width;
	float y = ((float)iy + 0.5f) / (float)height;

	// exploit hardware interpolation
	// and scale interpolated vector to match next pyramid level resolution
	out[ix + iy * stride] = tex2D(texCoarse, x, y) * scale;
}

void StereoLite::Upscale(const float *src, int width, int height, int stride,
	int newWidth, int newHeight, int newStride, float scale, float *out)
{
	dim3 threads(BlockWidth, BlockHeight);
	dim3 blocks(iDivUp(newWidth, threads.x), iDivUp(newHeight, threads.y));

	// mirror if a coordinate value is out-of-range
	texCoarse.addressMode[0] = cudaAddressModeMirror;
	texCoarse.addressMode[1] = cudaAddressModeMirror;
	texCoarse.filterMode = cudaFilterModeLinear;
	texCoarse.normalized = true;

	cudaChannelFormatDesc desc = cudaCreateChannelDesc<float>();

	cudaBindTexture2D(0, texCoarse, src, width, height, stride * sizeof(float));

	LiteUpscaleKernel << < blocks, threads >> > (newWidth, newHeight, newStride, scale, out);
}


//******************************
// Upscaling for Float2
//******************************
__global__ void LiteUpscaleFloat2Kernel(int width, int height, int stride, float scale, float2 *out)
{
	const int ix = threadIdx.x + blockIdx.x * blockDim.x;
	const int iy = threadIdx.y + blockIdx.y * blockDim.y;

	if (ix >= width || iy >= height) return;

	float x = ((float)ix + 0.5f) / (float)width;
	float y = ((float)iy + 0.5f) / (float)height;

	// exploit hardware interpolation
	// and scale interpolated vector to match next pyramid level resolution
	float2 src = tex2D(texCoarseFloat2, x, y);
	out[ix + iy * stride].x = src.x * scale;
	out[ix + iy * stride].y = src.y * scale;
}

void StereoLite::Upscale(const float2 *src, int width, int height, int stride,
	int newWidth, int newHeight, int newStride, float scale, float2 *out)
{
	dim3 threads(BlockWidth, BlockHeight);
	dim3 blocks(iDivUp(newWidth, threads.x), iDivUp(newHeight, threads.y));

	// mirror if a coordinate value is out-of-range
	texCoarseFloat2.addressMode[0] = cudaAddressModeMirror;
	texCoarseFloat2.addressMode[1] = cudaAddressModeMirror;
	texCoarseFloat2.filterMode = cudaFilterModeLinear;
	texCoarseFloat2.normalized = true;

	cudaChannelFormatDesc desc = cudaCreateChannelDesc<float2>();

	cudaBindTexture2D(0, texCoarseFloat2, src, width, height, stride * sizeof(float2));

	LiteUpscaleFloat2Kernel << < blocks, threads >> > (newWidth, newHeight, newStride, scale, out);
}