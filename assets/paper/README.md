# Paper crumpling atlas

`crumple-stages-v1.png` is a locally bundled, alpha-transparent 2×2 atlas.
Top-left: lightly crushed sheet. Top-right: half crushed. Bottom-left: loose ball.
Bottom-right: tighter ball. Flutter crops quadrants at render time; the PNG is unmodified.

Created with the built-in image_gen tool, using the user's supplied white-paper image as a material reference. No journal content was included in generation.

Generation prompt: Produce a transparent square 2×2 sprite atlas of the same white office paper in four progressively crumpled states. Match broad folded flaps, thin edges, matte fibers and deep occlusion in the reference. Same camera and upper-left light. No text, watermark, floor, checkerboard or cast shadows. Keep every object centered inside its own cell with clear margins.

Refinement prompt: Preserve the four paper objects and their appearance; correct quadrant margins and clean stray alpha-edge debris. Keep genuine transparency and the same camera and lighting.

This is staged photographic animation, not a physical paper simulation. The implementation preserves reduced-motion support and the existing throw/undo behavior.
