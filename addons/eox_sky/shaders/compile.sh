OPTIONS="-matrix-layout-row-major -profile glsl_450"
slangc main.slang $OPTIONS -target spirv -o compute_atmos_transmit_lut.spv -entry ComputeAtmosTransmitLut
slangc main.slang $OPTIONS -target spirv -o render_sky_octmap.spv -entry RenderSkyOctmap
slangc main.slang $OPTIONS -target spirv -o render_sky_background.vert.spv -entry RenderSkyBackgroundVert
slangc main.slang $OPTIONS -target spirv -o render_sky_background.frag.spv -entry RenderSkyBackgroundFrag
slangc main.slang $OPTIONS -target spirv -o render_sky_foreground.spv -entry RenderSkyForeground
