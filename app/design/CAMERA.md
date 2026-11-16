# Shared art camera

StarCraft is documented as an axonometric-view game in Cornell CS3152's
Perspective in 2D Games lecture (page 30):
https://www.cs.cornell.edu/courses/cs3152/2020sp/lectures/15-Perspective.pdf

An exact original StarCraft production-camera angle has not been verified.
Do not describe 30 or 45 degrees as an established original-game camera value.

Our production target is a fixed parallel/orthographic camera looking down
approximately 45 degrees, with no perspective convergence or distance scaling.
This is our chosen art direction, not a measured StarCraft parameter.

The logic grid uses square tiles and the command center occupies 4x3 cells.
The approved factory artwork faces southwest: open front toward screen lower-left,
rear service wall toward upper-right. This is a world yaw of the building drawing,
not rotation of the finished image plane. Columns and chimney remain vertical.
Height rises above a fixed ground anchor. Unit anchors are at their feet.
All character directions change the body facing, never the camera position.

Open-air factory: timber columns, a narrow permanent rear canopy, naturally open
front/sides, visible conveyor and furnace. It is not a cutaway house.
Keep the structure fixed. Smoke, wheel spokes, pump rod, conveyor load, water and
fire are independent animation layers sharing the exact same ground anchor.
Do not animate complete regenerated building frames: they drift between images.

The low, wide factory is a visual treatment only. Never change logical tile occupancy
to adjust an image silhouette. Sprite width/ground anchor are rendering properties.
