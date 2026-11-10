-- Voxel world mode



local Voxel = {}

Voxel.ANGLES_DEG = { 0, 35, 15, 35, 50, 75, 75, 75 }
Voxel.ANGLE_LABELS = { "OFF", "FULL", "15", "35", "50", "75",
                       "1ST", "3RD (EXPERIMENTAL)" }
Voxel.MAX_LEVEL = #Voxel.ANGLES_DEG - 1

Voxel.FULL_LEVEL = 1

Voxel.FP_LEVEL = 6

function Voxel.isFirstPerson(level)
  return (level or Voxel.level) == Voxel.FP_LEVEL
end

Voxel.TP_LEVEL = 7

function Voxel.isThirdPerson(level)
  return (level or Voxel.level) == Voxel.TP_LEVEL
end

Voxel.ORBIT_LEVEL_COUNT = 6

Voxel.HOTKEY_ORDER = { 0, 2, 3, 4, 5, 6, 7 } -- OFF, 15, 35, 50, 75, 1ST, 3RD

Voxel.level = 0
Voxel.angle = 0
Voxel.from = 0
Voxel.goal = 0
Voxel.t = 1

Voxel.ready = true

Voxel.TWEEN_TIME = 0.25
Voxel.FOCAL = 1.0

return Voxel
