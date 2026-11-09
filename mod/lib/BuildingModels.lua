-- BuildingModels

local V = ...
local SpriteVoxel = V.require('SpriteVoxel')
local Budget = V.require('BuildBudget')
local M = {}
M.RECIPES = false -- the SpriteVoxel box recipes; see prepare()

local CENTER = {
 width = 64,
 boxes = {
  { name = 'body', x0 = 0, x1 = 64, y0 = 0, y1 = 20, d0 = 2, d1 = 48,
    paint = {
      south  = {x = 0, y = 44, w = 64, h = 20},
      north  = {x = 8, y = 46, w = 48, h = 18},
      east   = {x = 58, y = 46, w = 4, h = 18},
      west   = {x = 2,  y = 46, w = 4, h = 18},
      bottom = {x = 8,  y = 60, w = 1, h = 1},
    }
  },
  { name = 'eave', x0 = 0, x1 = 64, y0 = 20, y1 = 23, d0 = 0, d1 = 48,
    paint = {
      south  = {x = 0, y = 41, w = 64, h = 3},
      top    = {x = 0, y = 40, w = 64, h = 2},
      north  = {x = 0, y = 41, w = 64, h = 3},
      east   = {x = 60, y = 41, w = 2, h = 3},
      west   = {x = 2,  y = 41, w = 2, h = 3},
    }
  },
  { name = 'red_band', x0 = 2, x1 = 62, y0 = 23, y1 = 34, d0 = 4, d1 = 46,
    paint = {
      south  = {x = 2, y = 29, w = 60, h = 11},
      top    = {x = 2, y = 28, w = 60, h = 2},
      north  = {x = 2, y = 29, w = 60, h = 11},
      east   = {x = 58, y = 29, w = 2, h = 11},
      west   = {x = 4,  y = 29, w = 2, h = 11},
    }
  },
  { name = 'ribbed_dome', x0 = 6, x1 = 58, y0 = 34, y1 = 46, d0 = 8, d1 = 42,
    paint = {
      south  = {x = 6, y = 18, w = 52, h = 12},
      top    = {x = 6, y = 16, w = 52, h = 2},
      north  = {x = 6, y = 18, w = 52, h = 12},
      east   = {x = 54, y = 18, w = 2, h = 12},
      west   = {x = 6,  y = 18, w = 2, h = 12},
    }
  },
  { name = 'top_crest', x0 = 10, x1 = 54, y0 = 46, y1 = 52, d0 = 14, d1 = 36,
    paint = {
      south  = {x = 10, y = 10, w = 44, h = 6},
      top    = {x = 10, y = 8,  w = 44, h = 4},
      north  = {x = 10, y = 10, w = 44, h = 6},
      east   = {x = 52, y = 10, w = 2, h = 6},
      west   = {x = 10, y = 10, w = 2, h = 6},
    }
  },
 }
}

local MART = {
 width = 64,
 boxes = {
  { name = 'body', x0 = 0, x1 = 64, y0 = 0, y1 = 22, d0 = 2, d1 = 48,
    paint = {
      south  = {x = 0, y = 42, w = 64, h = 22},
      north  = {x = 8, y = 44, w = 48, h = 18},
      east   = {x = 58, y = 44, w = 4, h = 18},
      west   = {x = 2,  y = 44, w = 4, h = 18},
      bottom = {x = 8,  y = 60, w = 1, h = 1},
    }
  },
  { name = 'eave', x0 = 0, x1 = 64, y0 = 22, y1 = 25, d0 = 0, d1 = 48,
    paint = {
      south  = {x = 0, y = 38, w = 64, h = 4},
      top    = {x = 0, y = 37, w = 64, h = 2},
      north  = {x = 0, y = 38, w = 64, h = 4},
      east   = {x = 60, y = 38, w = 2, h = 4},
      west   = {x = 2,  y = 38, w = 2, h = 4},
    }
  },
  { name = 'blue_roof', x0 = 2, x1 = 62, y0 = 25, y1 = 36, d0 = 4, d1 = 46,
    paint = {
      south  = {x = 2, y = 25, w = 60, h = 12},
      top    = {x = 2, y = 23, w = 60, h = 4},
      north  = {x = 2, y = 25, w = 60, h = 12},
      east   = {x = 58, y = 25, w = 2, h = 12},
      west   = {x = 4,  y = 25, w = 2, h = 12},
    }
  },
  { name = 'hipped_slope', x0 = 6, x1 = 58, y0 = 36, y1 = 46, d0 = 8, d1 = 42,
    paint = {
      south  = {x = 6, y = 10, w = 52, h = 14},
      top    = {x = 6, y = 8,  w = 52, h = 2},
      north  = {x = 6, y = 10, w = 52, h = 14},
      east   = {x = 54, y = 10, w = 2, h = 14},
      west   = {x = 6,  y = 10, w = 2, h = 14},
    }
  },
  { name = 'top_ridge', x0 = 8, x1 = 56, y0 = 46, y1 = 48, d0 = 16, d1 = 34,
    paint = {
      south  = {x = 8, y = 8, w = 48, h = 2},
      top    = {x = 8, y = 8, w = 48, h = 2},
      north  = {x = 8, y = 8, w = 48, h = 2},
      east   = {x = 54, y = 8, w = 2, h = 2},
      west   = {x = 8,  y = 8, w = 2, h = 2},
    }
  },
 }
}

local GYM = {
 width = 96,
 boxes = {
  { name = 'wing_left', x0 = 0, x1 = 28, y0 = 0, y1 = 36, d0 = 4, d1 = 60,
    paint = {
      south  = {x = 0, y = 44, w = 28, h = 36},
      north  = {x = 4, y = 46, w = 24, h = 34},
      west   = {x = 0, y = 46, w = 4,  h = 34},
      east   = {x = 24, y = 46, w = 4, h = 34},
      bottom = {x = 10, y = 78, w = 1, h = 1},
    }
  },
  { name = 'wing_right', x0 = 68, x1 = 96, y0 = 0, y1 = 36, d0 = 4, d1 = 60,
    paint = {
      south  = {x = 68, y = 44, w = 28, h = 36},
      north  = {x = 68, y = 46, w = 24, h = 34},
      east   = {x = 92, y = 46, w = 4,  h = 34},
      west   = {x = 68, y = 46, w = 4,  h = 34},
      bottom = {x = 80, y = 78, w = 1, h = 1},
    }
  },
  { name = 'portico_body', x0 = 28, x1 = 68, y0 = 0, y1 = 40, d0 = 0, d1 = 60,
    paint = {
      south  = {x = 28, y = 40, w = 40, h = 40},
      north  = {x = 28, y = 42, w = 40, h = 38},
      east   = {x = 64, y = 42, w = 4, h = 38},
      west   = {x = 28, y = 42, w = 4, h = 38},
      bottom = {x = 48, y = 78, w = 1, h = 1},
    }
  },
  { name = 'roof_left', x0 = 2, x1 = 28, y0 = 36, y1 = 40, d0 = 6, d1 = 58,
    paint = {
      top    = {x = 2, y = 14, w = 26, h = 26},
      south  = {x = 2, y = 38, w = 26, h = 4},
      north  = {x = 2, y = 14, w = 26, h = 4},
      west   = {x = 2, y = 14, w = 4,  h = 26},
      east   = {x = 24, y = 14, w = 4, h = 26},
    }
  },
  { name = 'roof_right', x0 = 68, x1 = 94, y0 = 36, y1 = 40, d0 = 6, d1 = 58,
    paint = {
      top    = {x = 68, y = 14, w = 26, h = 26},
      south  = {x = 68, y = 38, w = 26, h = 4},
      north  = {x = 68, y = 14, w = 26, h = 4},
      east   = {x = 90, y = 14, w = 4,  h = 26},
      west   = {x = 68, y = 14, w = 4,  h = 26},
    }
  },
  { name = 'portico_roof', x0 = 26, x1 = 70, y0 = 40, y1 = 48, d0 = 2, d1 = 58,
    paint = {
      top    = {x = 26, y = 8,  w = 44, h = 24},
      south  = {x = 26, y = 32, w = 44, h = 8},
      north  = {x = 26, y = 8,  w = 44, h = 8},
      east   = {x = 66, y = 8,  w = 4,  h = 24},
      west   = {x = 26, y = 8,  w = 4,  h = 24},
    }
  },
  { name = 'crest', x0 = 30, x1 = 66, y0 = 48, y1 = 54, d0 = 10, d1 = 48,
    paint = {
      top    = {x = 30, y = 0, w = 36, h = 8},
      south  = {x = 30, y = 4, w = 36, h = 6},
      north  = {x = 30, y = 0, w = 36, h = 6},
      east   = {x = 62, y = 0, w = 4, h = 8},
      west   = {x = 30, y = 0, w = 4, h = 8},
    }
  },
 }
}

local DEVON_CORP = {
 width = 160,
 boxes = {
  { name = 'wing_left', x0 = 2, x1 = 56, y0 = 0, y1 = 108, d0 = 4, d1 = 64,
    paint = {
      south  = {x = 2, y = 36, w = 54, h = 108},
      north  = {x = 10, y = 38, w = 46, h = 106},
      west   = {x = 2,  y = 38, w = 4,  h = 106},
      east   = {x = 52, y = 38, w = 4,  h = 106},
      bottom = {x = 20, y = 140, w = 1, h = 1},
    }
  },
  { name = 'wing_right', x0 = 104, x1 = 158, y0 = 0, y1 = 108, d0 = 4, d1 = 64,
    paint = {
      south  = {x = 104, y = 36, w = 54, h = 108},
      north  = {x = 104, y = 38, w = 46, h = 106},
      east   = {x = 154, y = 38, w = 4,  h = 106},
      west   = {x = 104, y = 38, w = 4,  h = 106},
      bottom = {x = 140, y = 140, w = 1, h = 1},
    }
  },
  { name = 'roof_left', x0 = 4, x1 = 54, y0 = 108, y1 = 112, d0 = 6, d1 = 60,
    paint = {
      top    = {x = 4, y = 8,  w = 50, h = 28},
      south  = {x = 4, y = 34, w = 50, h = 4},
      north  = {x = 4, y = 8,  w = 50, h = 4},
      east   = {x = 50, y = 8, w = 4,  h = 28},
      west   = {x = 4,  y = 8, w = 4,  h = 28},
    }
  },
  { name = 'roof_right', x0 = 106, x1 = 156, y0 = 108, y1 = 112, d0 = 6, d1 = 60,
    paint = {
      top    = {x = 106, y = 8,  w = 50, h = 28},
      south  = {x = 106, y = 34, w = 50, h = 4},
      north  = {x = 106, y = 8,  w = 50, h = 4},
      east   = {x = 152, y = 8,  w = 4,  h = 28},
      west   = {x = 106, y = 8,  w = 4,  h = 28},
    }
  },
  { name = 'portico', x0 = 56, x1 = 104, y0 = 0, y1 = 120, d0 = 0, d1 = 64,
    paint = {
      south  = {x = 56, y = 24, w = 48, h = 120},
      north  = {x = 56, y = 24, w = 48, h = 120},
      east   = {x = 100, y = 24, w = 4, h = 120},
      west   = {x = 56,  y = 24, w = 4, h = 120},
      bottom = {x = 80,  y = 140, w = 1, h = 1},
    }
  },
  { name = 'roof_portico', x0 = 58, x1 = 102, y0 = 120, y1 = 126, d0 = 2, d1 = 60,
    paint = {
      top    = {x = 58, y = 0,  w = 44, h = 24},
      south  = {x = 58, y = 20, w = 44, h = 4},
      north  = {x = 58, y = 0,  w = 44, h = 4},
      east   = {x = 98, y = 0,  w = 4,  h = 24},
      west   = {x = 58, y = 0,  w = 4,  h = 24},
    }
  },
  { name = 'col_fl', x0 = 0, x1 = 4, y0 = 0, y1 = 112, d0 = 0, d1 = 6,
    paint = {
      south = {x = 0, y = 36, w = 4, h = 108},
      west  = {x = 0, y = 36, w = 4, h = 108},
      east  = {x = 2, y = 36, w = 2, h = 108},
      top   = {x = 0, y = 36, w = 4, h = 4},
    }
  },
  { name = 'col_fr', x0 = 156, x1 = 160, y0 = 0, y1 = 112, d0 = 0, d1 = 6,
    paint = {
      south = {x = 156, y = 36, w = 4, h = 108},
      east  = {x = 156, y = 36, w = 4, h = 108},
      west  = {x = 156, y = 36, w = 2, h = 108},
      top   = {x = 156, y = 36, w = 4, h = 4},
    }
  },
  { name = 'col_bl', x0 = 0, x1 = 4, y0 = 0, y1 = 112, d0 = 60, d1 = 66,
    paint = {
      north = {x = 0, y = 36, w = 4, h = 108},
      west  = {x = 0, y = 36, w = 4, h = 108},
      east  = {x = 2, y = 36, w = 2, h = 108},
      top   = {x = 0, y = 36, w = 4, h = 4},
    }
  },
  { name = 'col_br', x0 = 156, x1 = 160, y0 = 0, y1 = 112, d0 = 60, d1 = 66,
    paint = {
      north = {x = 156, y = 36, w = 4, h = 108},
      east  = {x = 156, y = 36, w = 4, h = 108},
      west  = {x = 156, y = 36, w = 2, h = 108},
      top   = {x = 156, y = 36, w = 4, h = 4},
    }
  },
 }
}

local DEPT_STORE = {
 width = 144,
 boxes = {
  -- Main tower body: rows 8..112 (height 104 px), depth 4..60
  { name = 'tower', x0 = 0, x1 = 144, y0 = 0, y1 = 104, d0 = 4, d1 = 60,
    paint = {
      south  = {x = 0, y = 8,   w = 144, h = 104},
      north  = {x = 8, y = 12,  w = 128, h = 100},
      east   = {x = 140, y = 12, w = 4,   h = 100},
      west   = {x = 0,   y = 12, w = 4,   h = 100},
      bottom = {x = 20,  y = 108, w = 1,  h = 1},
    }
  },
  -- Roof parapet / top slab: rows 0..8, height 104..110, depth 8..56
  { name = 'roof_slab', x0 = 4, x1 = 140, y0 = 104, y1 = 110, d0 = 8, d1 = 56,
    paint = {
      top    = {x = 4, y = 0,  w = 136, h = 8},
      south  = {x = 4, y = 4,  w = 136, h = 4},
      north  = {x = 4, y = 0,  w = 136, h = 4},
      east   = {x = 136, y = 0, w = 4,  h = 8},
      west   = {x = 4,   y = 0, w = 4,  h = 8},
    }
  },
  { name = 'entrance_portico', x0 = 56, x1 = 88, y0 = 14, y1 = 20, d0 = 0, d1 = 6,
    paint = {
      south  = {x = 56, y = 92, w = 32, h = 6},
      top    = {x = 56, y = 92, w = 32, h = 2},
      bottom = {x = 56, y = 96, w = 32, h = 2},
      east   = {x = 86, y = 92, w = 2,  h = 6},
      west   = {x = 56, y = 92, w = 2,  h = 6},
    }
  },
  -- Left window awnings: rows 92..98 (height 14..20), depth 0..6
  { name = 'awning_left1', x0 = 8, x1 = 24, y0 = 14, y1 = 20, d0 = 0, d1 = 6,
    paint = {
      south  = {x = 8,  y = 92, w = 16, h = 6},
      top    = {x = 8,  y = 92, w = 16, h = 2},
      bottom = {x = 8,  y = 96, w = 16, h = 2},
      east   = {x = 22, y = 92, w = 2,  h = 6},
      west   = {x = 8,  y = 92, w = 2,  h = 6},
    }
  },
  { name = 'awning_left2', x0 = 24, x1 = 40, y0 = 14, y1 = 20, d0 = 0, d1 = 6,
    paint = {
      south  = {x = 24, y = 92, w = 16, h = 6},
      top    = {x = 24, y = 92, w = 16, h = 2},
      bottom = {x = 24, y = 96, w = 16, h = 2},
      east   = {x = 38, y = 92, w = 2,  h = 6},
      west   = {x = 24, y = 92, w = 2,  h = 6},
    }
  },
  -- Right window awnings: rows 92..98 (height 14..20), depth 0..6
  { name = 'awning_right1', x0 = 104, x1 = 120, y0 = 14, y1 = 20, d0 = 0, d1 = 6,
    paint = {
      south  = {x = 104, y = 92, w = 16, h = 6},
      top    = {x = 104, y = 92, w = 16, h = 2},
      bottom = {x = 104, y = 96, w = 16, h = 2},
      east   = {x = 118, y = 92, w = 2,  h = 6},
      west   = {x = 104, y = 92, w = 2,  h = 6},
    }
  },
  { name = 'awning_right2', x0 = 120, x1 = 136, y0 = 14, y1 = 20, d0 = 0, d1 = 6,
    paint = {
      south  = {x = 120, y = 92, w = 16, h = 6},
      top    = {x = 120, y = 92, w = 16, h = 2},
      bottom = {x = 120, y = 96, w = 16, h = 2},
      east   = {x = 134, y = 92, w = 2,  h = 6},
      west   = {x = 120, y = 92, w = 2,  h = 6},
    }
  },
 }
}

local MUSEUM = {
 width = 160,
 boxes = {
  { name = 'wing_left', x0 = 0, x1 = 56, y0 = 0, y1 = 44, d0 = 4, d1 = 52,
    paint = {
      south  = {x = 0, y = 52, w = 56, h = 44},
      north  = {x = 4, y = 52, w = 52, h = 44},
      west   = {x = 0, y = 52, w = 4,  h = 44},
      east   = {x = 52, y = 52, w = 4, h = 44},
      bottom = {x = 10, y = 92, w = 1, h = 1},
    }
  },
  { name = 'wing_right', x0 = 104, x1 = 160, y0 = 0, y1 = 44, d0 = 4, d1 = 52,
    paint = {
      south  = {x = 104, y = 52, w = 56, h = 44},
      north  = {x = 104, y = 52, w = 52, h = 44},
      east   = {x = 156, y = 52, w = 4,  h = 44},
      west   = {x = 104, y = 52, w = 4,  h = 44},
      bottom = {x = 110, y = 92, w = 1, h = 1},
    }
  },
  { name = 'center_portico', x0 = 56, x1 = 104, y0 = 0, y1 = 48, d0 = 0, d1 = 52,
    paint = {
      south  = {x = 56, y = 48, w = 48, h = 48},
      north  = {x = 56, y = 48, w = 48, h = 48},
      east   = {x = 100, y = 48, w = 4, h = 48},
      west   = {x = 56,  y = 48, w = 4, h = 48},
      bottom = {x = 70,  y = 92, w = 1, h = 1},
    }
  },
  { name = 'roof_left', x0 = 2, x1 = 54, y0 = 44, y1 = 48, d0 = 6, d1 = 48,
    paint = {
      top    = {x = 2, y = 20, w = 52, h = 32},
      south  = {x = 2, y = 48, w = 52, h = 4},
      north  = {x = 2, y = 20, w = 52, h = 4},
      east   = {x = 50, y = 20, w = 4,  h = 32},
      west   = {x = 2,  y = 20, w = 4,  h = 32},
    }
  },
  { name = 'roof_right', x0 = 106, x1 = 158, y0 = 44, y1 = 48, d0 = 6, d1 = 48,
    paint = {
      top    = {x = 106, y = 20, w = 52, h = 32},
      south  = {x = 106, y = 48, w = 52, h = 4},
      north  = {x = 106, y = 20, w = 52, h = 4},
      east   = {x = 154, y = 20, w = 4,  h = 32},
      west   = {x = 106, y = 20, w = 4,  h = 32},
    }
  },
  { name = 'upper_pavilion', x0 = 40, x1 = 120, y0 = 48, y1 = 66, d0 = 10, d1 = 46,
    paint = {
      south  = {x = 40, y = 16, w = 80, h = 18},
      north  = {x = 40, y = 16, w = 80, h = 18},
      east   = {x = 116, y = 16, w = 4, h = 18},
      west   = {x = 40,  y = 16, w = 4, h = 18},
    }
  },
  { name = 'pavilion_roof', x0 = 42, x1 = 118, y0 = 66, y1 = 70, d0 = 12, d1 = 44,
    paint = {
      top    = {x = 42, y = 0,  w = 76, h = 16},
      south  = {x = 42, y = 14, w = 76, h = 4},
      north  = {x = 42, y = 0,  w = 76, h = 4},
      east   = {x = 114, y = 0, w = 4,  h = 16},
      west   = {x = 42,  y = 0, w = 4,  h = 16},
    }
  },
 }
}

local WEATHER_INSTITUTE = {
 width = 160,
 boxes = {
  { name = 'tower_left', x0 = 0, x1 = 48, y0 = 0, y1 = 60, d0 = 4, d1 = 52,
    paint = {
      south  = {x = 0, y = 52, w = 48, h = 60},
      north  = {x = 4, y = 52, w = 44, h = 60},
      west   = {x = 0, y = 52, w = 4,  h = 60},
      east   = {x = 44, y = 52, w = 4, h = 60},
      bottom = {x = 10, y = 108, w = 1, h = 1},
    }
  },
  { name = 'tower_right', x0 = 112, x1 = 160, y0 = 0, y1 = 60, d0 = 4, d1 = 52,
    paint = {
      south  = {x = 112, y = 52, w = 48, h = 60},
      north  = {x = 112, y = 52, w = 44, h = 60},
      east   = {x = 156, y = 52, w = 4,  h = 60},
      west   = {x = 112, y = 52, w = 4,  h = 60},
      bottom = {x = 120, y = 108, w = 1, h = 1},
    }
  },
  { name = 'center_body', x0 = 48, x1 = 112, y0 = 0, y1 = 54, d0 = 0, d1 = 52,
    paint = {
      south  = {x = 48, y = 58, w = 64, h = 54},
      north  = {x = 48, y = 58, w = 64, h = 54},
      east   = {x = 108, y = 58, w = 4, h = 54},
      west   = {x = 48,  y = 58, w = 4, h = 54},
      bottom = {x = 80,  y = 108, w = 1, h = 1},
    }
  },
  { name = 'dome_left', x0 = 4, x1 = 44, y0 = 60, y1 = 78, d0 = 10, d1 = 46,
    paint = {
      south  = {x = 4, y = 20, w = 40, h = 18},
      top    = {x = 4, y = 16, w = 40, h = 4},
      north  = {x = 4, y = 20, w = 40, h = 18},
      east   = {x = 40, y = 20, w = 4, h = 18},
      west   = {x = 4,  y = 20, w = 4, h = 18},
    }
  },
  { name = 'dome_right', x0 = 116, x1 = 156, y0 = 60, y1 = 78, d0 = 10, d1 = 46,
    paint = {
      south  = {x = 116, y = 20, w = 40, h = 18},
      top    = {x = 116, y = 16, w = 40, h = 4},
      north  = {x = 116, y = 20, w = 40, h = 18},
      east   = {x = 152, y = 20, w = 4, h = 18},
      west   = {x = 116, y = 20, w = 4, h = 18},
    }
  },
  { name = 'center_roof', x0 = 48, x1 = 112, y0 = 54, y1 = 66, d0 = 8, d1 = 46,
    paint = {
      south  = {x = 48, y = 34, w = 64, h = 12},
      top    = {x = 48, y = 32, w = 64, h = 4},
      north  = {x = 48, y = 34, w = 64, h = 12},
      east   = {x = 108, y = 34, w = 4, h = 12},
      west   = {x = 48,  y = 34, w = 4, h = 12},
    }
  },
  { name = 'antenna_tier', x0 = 64, x1 = 96, y0 = 66, y1 = 80, d0 = 18, d1 = 38,
    paint = {
      south  = {x = 64, y = 0,  w = 32, h = 14},
      top    = {x = 64, y = 0,  w = 32, h = 4},
      north  = {x = 64, y = 0,  w = 32, h = 14},
      east   = {x = 92, y = 0,  w = 4,  h = 14},
      west   = {x = 64, y = 0,  w = 4,  h = 14},
    }
  },
 }
}

local PETALBURG_HOUSE = {
 width = 64,
 boxes = {
  { name = 'body', x0 = 0, x1 = 64, y0 = 0, y1 = 26, d0 = 2, d1 = 46,
    paint = {
      south  = {x = 0, y = 38, w = 64, h = 26},
      north  = {x = 4, y = 42, w = 56, h = 20},
      east   = {x = 58, y = 42, w = 4,  h = 20},
      west   = {x = 2,  y = 42, w = 4,  h = 20},
      bottom = {x = 8,  y = 60, w = 1,  h = 1},
    }
  },
  { name = 'eave', x0 = 0, x1 = 64, y0 = 26, y1 = 28, d0 = 0, d1 = 48,
    paint = {
      south  = {x = 0, y = 36, w = 64, h = 2},
      top    = {x = 0, y = 36, w = 64, h = 2},
      north  = {x = 0, y = 36, w = 64, h = 2},
      east   = {x = 60, y = 36, w = 2,  h = 2},
      west   = {x = 2,  y = 36, w = 2,  h = 2},
    }
  },
  { name = 'roof_slope', x0 = 0, x1 = 64, y0 = 28, y1 = 50, d0 = 4, d1 = 44,
    paint = {
      south  = {x = 0, y = 14, w = 64, h = 22},
      top    = {x = 0, y = 14, w = 64, h = 4},
      north  = {x = 0, y = 14, w = 64, h = 22},
      east   = {x = 58, y = 14, w = 4,  h = 22},
      west   = {x = 2,  y = 14, w = 4,  h = 22},
    }
  },
  { name = 'roof_ridge', x0 = 0, x1 = 64, y0 = 50, y1 = 64, d0 = 12, d1 = 36,
    paint = {
      south  = {x = 0, y = 0,  w = 64, h = 14},
      top    = {x = 0, y = 0,  w = 64, h = 4},
      north  = {x = 0, y = 0,  w = 64, h = 14},
      east   = {x = 58, y = 0,  w = 4,  h = 14},
      west   = {x = 2,  y = 0,  w = 4,  h = 14},
    }
  },
 }
}

local MAUVILLE_HOUSE = {
 width = 64,
 boxes = {
  { name = 'body', x0 = 0, x1 = 64, y0 = 0, y1 = 26, d0 = 2, d1 = 46,
    paint = {
      south  = {x = 0, y = 38, w = 64, h = 26},
      north  = {x = 4, y = 42, w = 56, h = 20},
      east   = {x = 58, y = 42, w = 4,  h = 20},
      west   = {x = 2,  y = 42, w = 4,  h = 20},
      bottom = {x = 8,  y = 60, w = 1,  h = 1},
    }
  },
  { name = 'eave', x0 = 0, x1 = 64, y0 = 26, y1 = 30, d0 = 0, d1 = 48,
    paint = {
      south  = {x = 0, y = 34, w = 64, h = 4},
      top    = {x = 0, y = 34, w = 64, h = 2},
      north  = {x = 0, y = 34, w = 64, h = 4},
      east   = {x = 60, y = 34, w = 2,  h = 4},
      west   = {x = 2,  y = 34, w = 2,  h = 4},
    }
  },
  { name = 'roof_slope', x0 = 0, x1 = 64, y0 = 30, y1 = 52, d0 = 4, d1 = 44,
    paint = {
      south  = {x = 0, y = 12, w = 64, h = 22},
      top    = {x = 0, y = 12, w = 64, h = 4},
      north  = {x = 0, y = 12, w = 64, h = 22},
      east   = {x = 58, y = 12, w = 4,  h = 22},
      west   = {x = 2,  y = 12, w = 4,  h = 22},
    }
  },
  { name = 'roof_ridge', x0 = 0, x1 = 64, y0 = 52, y1 = 64, d0 = 12, d1 = 36,
    paint = {
      south  = {x = 0, y = 0,  w = 64, h = 12},
      top    = {x = 0, y = 0,  w = 64, h = 4},
      north  = {x = 0, y = 0,  w = 64, h = 12},
      east   = {x = 58, y = 0,  w = 4,  h = 12},
      west   = {x = 2,  y = 0,  w = 4,  h = 12},
    }
  },
 }
}

local function claim(cells, bld)
 local claimed = {}
 for dy = 0, bld.depth - 1 do
  for dx = 0, bld.width - 1 do
   local c = cells[(bld.cx + dx) .. ':' .. (bld.cy + dy)]
   if c then
    c.bldModel = bld
    c.civic = bld
    claimed[#claimed + 1] = c
   end
  end
 end
 if #claimed == 0 then return nil end
 bld.claimed = claimed
 bld.ts = claimed[1].ts
 return bld
end

function M.prepare(cells, def, regions)
 local out = {}
 if not def or not cells then return out end
 local mapId = def.id or ''

 for _, bld in ipairs(V.require('BuildingVoxels').prepare(cells, def, claim)) do out[#out + 1] = bld end

 if not M.RECIPES then return out end

 if mapId == 'EM_RUSTBORO_CITY' then
  local c = cells['7:7']
  if c and (c.mid == 0x288 or c.mid == 648) then
   local bld = claim(cells, { cx = 7, cy = 7, width = 10, depth = 9, recipe = DEVON_CORP, name = 'devon_corp' })
   if bld then out[#out + 1] = bld end
  end
 elseif mapId == 'EM_LILYCOVE_CITY' then
  local c = cells['23:0']
  if c then
   local bld = claim(cells, { cx = 23, cy = 0, width = 9, depth = 7, recipe = DEPT_STORE, name = 'dept_store' })
   if bld then out[#out + 1] = bld end
  end
  local c2 = cells['7:1']
  if c2 then
   local bld = claim(cells, { cx = 7, cy = 1, width = 10, depth = 6, recipe = MUSEUM, name = 'museum' })
   if bld then out[#out + 1] = bld end
  end
 elseif mapId == 'EM_ROUTE119' then
  local c = cells['2:26']
  if c then
   local bld = claim(cells, { cx = 2, cy = 26, width = 10, depth = 7, recipe = WEATHER_INSTITUTE, name = 'weather_inst' })
   if bld then out[#out + 1] = bld end
  end
 elseif mapId == 'EM_PETALBURG_CITY' then
  local c = cells['12:4']
  if c and c.mid == 0x1aa then
   local bld = claim(cells, { cx = 12, cy = 4, width = 6, depth = 5, recipe = GYM, name = 'gym' })
   if bld then out[#out + 1] = bld end
  end
  local h1 = cells['9:16']
  if h1 and h1.mid == 0x008 then
   local bld = claim(cells, { cx = 9, cy = 16, width = 4, depth = 4, recipe = PETALBURG_HOUSE, name = 'petalburg_house1' })
   if bld then out[#out + 1] = bld end
  end
  local h2 = cells['6:2']
  if h2 and h2.mid == 0x009 then
   local bld = claim(cells, { cx = 6, cy = 2, width = 4, depth = 4, recipe = PETALBURG_HOUSE, name = 'petalburg_wally' })
   if bld then out[#out + 1] = bld end
  end
  local h3 = cells['19:21']
  if h3 and h3.mid == 0x008 then
   local bld = claim(cells, { cx = 19, cy = 21, width = 4, depth = 4, recipe = PETALBURG_HOUSE, name = 'petalburg_house2' })
   if bld then out[#out + 1] = bld end
  end
 elseif mapId == 'EM_SLATEPORT_CITY' then
  local h1 = cells['4:16']
  if h1 and h1.mid == 0x2c0 then
   local bld = claim(cells, { cx = 4, cy = 16, width = 4, depth = 4, recipe = PETALBURG_HOUSE, name = 'slateport_name_rater' })
   if bld then out[#out + 1] = bld end
  end
  local h2 = cells['20:41']
  if h2 and h2.mid == 0x2c0 then
   local bld = claim(cells, { cx = 20, cy = 41, width = 4, depth = 4, recipe = PETALBURG_HOUSE, name = 'slateport_house' })
   if bld then out[#out + 1] = bld end
  end
 elseif mapId == 'EM_MAUVILLE_CITY' then
  local h1 = cells['31:11']
  if h1 and h1.mid == 0x283 then
   local bld = claim(cells, { cx = 31, cy = 11, width = 4, depth = 4, recipe = MAUVILLE_HOUSE, name = 'mauville_house1' })
   if bld then out[#out + 1] = bld end
  end
  local h2 = cells['18:11']
  if h2 and h2.mid == 0x283 then
   local bld = claim(cells, { cx = 18, cy = 11, width = 4, depth = 4, recipe = MAUVILLE_HOUSE, name = 'mauville_house2' })
   if bld then out[#out + 1] = bld end
  end
 end

 for _, c in pairs(cells) do
  Budget.tick()
  if not c.bldModel and not c.civic and not c.prop then
   local r1_0 = cells[(c.cx) .. ':' .. (c.cy + 1)]
   local r1_1 = cells[(c.cx + 1) .. ':' .. (c.cy + 1)]
   local r1_2 = cells[(c.cx + 2) .. ':' .. (c.cy + 1)]
   local r1_3 = cells[(c.cx + 3) .. ':' .. (c.cy + 1)]
   if r1_0 and r1_1 and r1_2 and r1_3 and
      r1_0.mid == 0x050 and r1_1.mid == 0x051 and r1_2.mid == 0x052 and r1_3.mid == 0x053 then
    local r2_0 = cells[(c.cx) .. ':' .. (c.cy + 2)]
    local r2_1 = cells[(c.cx + 1) .. ':' .. (c.cy + 2)]
    local r2_2 = cells[(c.cx + 2) .. ':' .. (c.cy + 2)]
    local r2_3 = cells[(c.cx + 3) .. ':' .. (c.cy + 2)]
    if r2_0 and r2_1 and r2_2 and r2_3 and
       r2_0.mid == 0x058 and r2_1.mid == 0x059 and r2_2.mid == 0x05a and r2_3.mid == 0x05b then
     local bld = claim(cells, { cx = c.cx, cy = c.cy, width = 4, depth = 4, recipe = CENTER, name = 'center' })
     if bld then out[#out + 1] = bld end
    end
   end

   local m1_0 = cells[(c.cx) .. ':' .. (c.cy + 1)]
   local m1_1 = cells[(c.cx + 1) .. ':' .. (c.cy + 1)]
   local m1_2 = cells[(c.cx + 2) .. ':' .. (c.cy + 1)]
   local m1_3 = cells[(c.cx + 3) .. ':' .. (c.cy + 1)]
   if m1_0 and m1_1 and m1_2 and m1_3 and
      m1_0.mid == 0x030 and m1_1.mid == 0x031 and m1_2.mid == 0x032 and m1_3.mid == 0x033 then
    local m2_0 = cells[(c.cx) .. ':' .. (c.cy + 2)]
    local m2_1 = cells[(c.cx + 1) .. ':' .. (c.cy + 2)]
    local m2_2 = cells[(c.cx + 2) .. ':' .. (c.cy + 2)]
    local m2_3 = cells[(c.cx + 3) .. ':' .. (c.cy + 2)]
    if m2_0 and m2_1 and m2_2 and m2_3 and
       m2_0.mid == 0x038 and m2_1.mid == 0x039 and m2_2.mid == 0x03a and m2_3.mid == 0x03b then
     local bld = claim(cells, { cx = c.cx, cy = c.cy, width = 4, depth = 4, recipe = MART, name = 'mart' })
     if bld then out[#out + 1] = bld end
    end
   end
  end
 end

 return out
end

function M.compose(cells, bld)
 local ts = bld.ts
 if not ts or not ts.imageData then return nil end
 local w = bld.width * 16
 local h = bld.depth * 16
 local data = love.image.newImageData(w, h)

 local function origin(mid, t)
  local slot = t.midToSlot[mid]
  if not slot then return nil end
  return (slot % t.cols) * 16, math.floor(slot / t.cols) * 16
 end

 for dy = 0, bld.depth - 1 do
  for dx = 0, bld.width - 1 do
   local c = cells[(bld.cx + dx) .. ':' .. (bld.cy + dy)]
   local mid = c and (bld.voxels and c.mid or c.roofMid or c.mid)
   if bld.tiles then mid = bld.tiles[dy * bld.width + dx + 1] and bld.tiles[dy * bld.width + dx + 1][3] or mid end
   local t = ts
   if c and c.ts and c.ts.imageData and mid and c.ts.midToSlot[mid] then t = c.ts end
   if mid then
    local sx, sy = origin(mid, t)
    if not sx and t ~= ts then t = ts; sx, sy = origin(mid, t) end
    if sx then
     data:paste(t.imageData, dx * 16, dy * 16, sx, sy, 16, 16)
     for _, layer in ipairs({ t.overImageData or false }) do
      if layer then
      for py = 0, 15 do
       for px = 0, 15 do
        local r, g, b, a = layer:getPixel(sx + px, sy + py)
        if a > 0 then
         local br, bg, bb, ba = data:getPixel(dx * 16 + px, dy * 16 + py)
         local cr = r * a + br * (1 - a)
         local cg = g * a + bg * (1 - a)
         local cb = b * a + bb * (1 - a)
         local ca = math.max(ba, a)
         data:setPixel(dx * 16 + px, dy * 16 + py, cr, cg, cb, ca)
        end
       end
      end
      end
     end
    end
   end
  end
 end

 local img = love.graphics.newImage(data)
 img:setFilter('nearest', 'nearest')
 return data, img
end

function M.mesh(bld, cells)
 local data, img = M.compose(cells, bld)
 if not data or not img then return nil end
 if bld.voxels and bld.claimed then
  local votes, best, bn = {}, nil, 0
  for _, c in ipairs(bld.claimed) do
   local h = c.floor and c.floor.height
   if h then votes[h] = (votes[h] or 0) + 1; if votes[h] > bn then best, bn = h, votes[h] end end
  end
  if best then
   local off = 0
   local front = cells[(bld.cx + math.floor(bld.width / 2)) .. ':' .. (bld.cy + bld.depth)]
   if front and front.floor and front.floor.height and bld.groundHeight then off = bld.groundHeight - front.floor.height end
   local row = bld.cy + bld.depth - 1
   for x = bld.cx, bld.cx + bld.width - 1 do
    local d = cells[x .. ':' .. row]
    local s = cells[x .. ':' .. (row + 1)]
    local dc = d and (d.collision or 0)
    if d and dc ~= 7 and dc ~= 0xFF and s and s.floor and s.floor.height and s.floor.floor ~= false then
     best = s.floor.high or s.floor.height
     if front and front.floor and front.floor.height and bld.groundHeight then off = bld.groundHeight - front.floor.height end
     break
    end
   end
   local so = bld.voxels.standOn
   local sc = so and cells[so[1] .. ':' .. so[2]]
   if sc and sc.floor and sc.floor.height then best, off = sc.floor.height, 0 end
   bld.groundHeight = best + off
   local mine = {}
   for _, c in ipairs(bld.claimed) do mine[c] = true end
   local open, grew = {}, true
   while grew do
    grew = false
    for _, c in ipairs(bld.claimed) do
     if not open[c] and c.collision == 0 and not c.boundary and c.base ~= bld.groundHeight then
      for _, d in ipairs({ { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } }) do
       local n = cells[(c.cx + d[1]) .. ':' .. (c.cy + d[2])]
       if n and (not mine[n] or open[n]) and n.collision == 0 and not n.boundary and n.base == c.base then open[c] = true; grew = true; break end
      end
     end
    end
   end
   for _, c in ipairs(bld.claimed) do if not open[c] then c.base = bld.groundHeight end end
  end
 end
 if bld.voxels then
  local glass = V.require('GlassMask').buildingSet(data, cells, bld)
  local mesh, data2, img2, twins = V.require('BuildingVoxels').mesh(bld, data, img, glass)
  if not mesh or data2 then img:release(); if data.release then data:release() end end
  if not mesh then return nil end
  if data2 then data, img = data2, img2 end
  return { mesh = mesh, image = img, imageData = data, twins = twins, bld = bld }
 end
 local spr = {
  width = bld.width * 16,
  height = bld.depth * 16,
  imageData = data,
  image = img,
 }
 local origin = {
  bld.cx * 16,
  bld.groundHeight or 0,
  (bld.cy + bld.depth) * 16,
 }
 local mesh, stats = SpriteVoxel.build(spr, bld.recipe, origin)
 if not mesh then
  img:release()
  if data.release then data:release() end
  return nil
 end
 return {
  mesh = mesh,
  image = img,
  imageData = data,
  bld = bld,
 }
end

return M
