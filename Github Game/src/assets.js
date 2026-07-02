import { clamp } from './utils/math.js';

export const tileSheets = {
  base: {
    key: 'base',
    path: 'tilesheet/Overworld.png',
    tileSize: 32,
    image: null
  },
  dwarfholdInterior: {
    key: 'dwarfholdInterior',
    path: 'tilesheet/Interior_Tileset.png',
    tileSize: 32,
    image: null
  },
  dwarfholdWalls: {
    key: 'dwarfholdWalls',
    path: 'tilesheet/Tiled_files/walls_floor.png',
    tileSize: 16,
    image: null
  },
  dwarfholdObjects: {
    key: 'dwarfholdObjects',
    path: 'tilesheet/Tiled_files/Objects.png',
    tileSize: 16,
    image: null
  },
  worldDetails: {
    key: 'worldDetails',
    path: 'tilesheet/df/world_map_details.png',
    tileSize: 16,
    image: null
  },
  worldEdgeGlacier: {
    key: 'worldEdgeGlacier',
    path: 'tilesheet/df/world_map_edge_glacier.png',
    tileSize: 16,
    image: null
  },
  custom: {
    key: 'custom',
    path: 'tilesheet/tiles.png',
    tileSize: 16,
    image: null
  }
};

export const dwarfSpriteSheets = {
  body: {
    key: 'body',
    path: 'tilesheet/Mobs/character sprite/PNG/Unarmed/Parts/Unarmed_Idle2_body.png',
    tileSize: 64,
    image: null
  },
  head: {
    key: 'head',
    path: 'tilesheet/Mobs/character sprite/PNG/Unarmed/Parts/Unarmed_Idle3_head.png',
    tileSize: 64,
    image: null
  },
  hair: {
    key: 'hair',
    path: 'tilesheet/df/dwarf_hair_straight.png',
    tileSize: 32,
    image: null
  },
  hairCurly: {
    key: 'hairCurly',
    path: 'tilesheet/df/dwarf_hair_curly.png',
    tileSize: 32,
    image: null
  }
};

export const orcSpriteSheets = {
  orc1_idle: {
    key: 'orc1_idle',
    path: 'tilesheet/Mobs/Orc/PNG/Orc1/Without_shadow/orc1_idle_without_shadow.png',
    tileSize: 16,
    image: null
  },
  orc1_walk: {
    key: 'orc1_walk',
    path: 'tilesheet/Mobs/Orc/PNG/Orc1/Without_shadow/orc1_walk_without_shadow.png',
    tileSize: 16,
    image: null
  },
  orc1_attack: {
    key: 'orc1_attack',
    path: 'tilesheet/Mobs/Orc/PNG/Orc1/Without_shadow/orc1_attack_without_shadow.png',
    tileSize: 16,
    image: null
  },
  orc1_hurt: {
    key: 'orc1_hurt',
    path: 'tilesheet/Mobs/Orc/PNG/Orc1/Without_shadow/orc1_hurt_without_shadow.png',
    tileSize: 16,
    image: null
  },
  orc1_death: {
    key: 'orc1_death',
    path: 'tilesheet/Mobs/Orc/PNG/Orc1/Without_shadow/orc1_death_without_shadow.png',
    tileSize: 16,
    image: null
  },
  orc2_idle: {
    key: 'orc2_idle',
    path: 'tilesheet/Mobs/Orc/PNG/Orc2/Without_shadow/orc2_idle_without_shadow.png',
    tileSize: 16,
    image: null
  },
  orc2_walk: {
    key: 'orc2_walk',
    path: 'tilesheet/Mobs/Orc/PNG/Orc2/Without_shadow/orc2_walk_without_shadow.png',
    tileSize: 16,
    image: null
  },
  orc2_attack: {
    key: 'orc2_attack',
    path: 'tilesheet/Mobs/Orc/PNG/Orc2/Without_shadow/orc2_attack_without_shadow.png',
    tileSize: 16,
    image: null
  },
  orc2_hurt: {
    key: 'orc2_hurt',
    path: 'tilesheet/Mobs/Orc/PNG/Orc2/Without_shadow/orc2_hurt_without_shadow.png',
    tileSize: 16,
    image: null
  },
  orc2_death: {
    key: 'orc2_death',
    path: 'tilesheet/Mobs/Orc/PNG/Orc2/Without_shadow/orc2_death_without_shadow.png',
    tileSize: 16,
    image: null
  },
  orc3_idle: {
    key: 'orc3_idle',
    path: 'tilesheet/Mobs/Orc/PNG/Orc3/Without_shadow/orc3_idle_without_shadow.png',
    tileSize: 16,
    image: null
  },
  orc3_walk: {
    key: 'orc3_walk',
    path: 'tilesheet/Mobs/Orc/PNG/Orc3/Without_shadow/orc3_walk_without_shadow.png',
    tileSize: 16,
    image: null
  },
  orc3_attack: {
    key: 'orc3_attack',
    path: 'tilesheet/Mobs/Orc/PNG/Orc3/Without_shadow/orc3_attack_without_shadow.png',
    tileSize: 16,
    image: null
  },
  orc3_hurt: {
    key: 'orc3_hurt',
    path: 'tilesheet/Mobs/Orc/PNG/Orc3/Without_shadow/orc3_hurt_without_shadow.png',
    tileSize: 16,
    image: null
  },
  orc3_death: {
    key: 'orc3_death',
    path: 'tilesheet/Mobs/Orc/PNG/Orc3/Without_shadow/orc3_death_without_shadow.png',
    tileSize: 16,
    image: null
  }
};

export const dungeonPlayerSpriteSheets = {
  idle: {
    key: 'dungeonPlayerIdle',
    path: 'tilesheet/Mobs/character sprite/PNG/Unarmed/Without_shadow/Unarmed_Idle_without_shadow.png',
    frameWidth: 64,
    frameHeight: 64,
    image: null
  },
  walk: {
    key: 'dungeonPlayerWalk',
    path: 'tilesheet/Mobs/character sprite/PNG/Unarmed/Without_shadow/Unarmed_Walk_without_shadow.png',
    frameWidth: 64,
    frameHeight: 64,
    image: null
  }
};

export const characterCreatorPortraitAssets = {
  maleBody: {
    key: 'maleBody',
    path: 'tilesheet/Character Creator/body_male.png',
    image: null
  },
  femaleBody: {
    key: 'femaleBody',
    path: 'tilesheet/Character Creator/body_female.png',
    image: null
  },
  headDefault: {
    key: 'headDefault',
    path: 'tilesheet/Character Creator/head_default.png',
    image: null
  },
  beard1: {
    key: 'beard1',
    path: 'tilesheet/Character Creator/beard_1.png',
    image: null
  },
  beard2: {
    key: 'beard2',
    path: 'tilesheet/Character Creator/beard_2.png',
    image: null
  },
  beard3: {
    key: 'beard3',
    path: 'tilesheet/Character Creator/beard_3.png',
    image: null
  },
  beard4: {
    key: 'beard4',
    path: 'tilesheet/Character Creator/beard_4.png',
    image: null
  },
  beard5: {
    key: 'beard5',
    path: 'tilesheet/Character Creator/beard_5.png',
    image: null
  },
  beard6: {
    key: 'beard6',
    path: 'tilesheet/Character Creator/beard_6.png',
    image: null
  },
  beard7: {
    key: 'beard7',
    path: 'tilesheet/Character Creator/beard_7.png',
    image: null
  },
  beardRinged: {
    key: 'beardRinged',
    path: 'tilesheet/Character Creator/7.png',
    image: null
  },
  mustache: {
    key: 'mustache',
    path: 'tilesheet/Character Creator/mustache.png',
    image: null
  },
  hairShort: {
    key: 'hairShort',
    path: 'tilesheet/Character Creator/hair_3.png',
    image: null
  },
  hairMedium: {
    key: 'hairMedium',
    path: 'tilesheet/Character Creator/hair_1.png',
    image: null
  },
  hairLong: {
    key: 'hairLong',
    path: 'tilesheet/Character Creator/hair_2.png',
    image: null
  },
  hairBraided: {
    key: 'hairBraided',
    path: 'tilesheet/Character Creator/hair_4.png',
    image: null
  },
  nose: {
    key: 'nose',
    path: 'tilesheet/Character Creator/nose.png',
    image: null
  }
};

export const characterCreatorBeardAssetMap = {
  short: 'beard1',
  full: 'beard2',
  braided: 'beard3',
  forked: 'beard4',
  mutton: 'beard5',
  stubble: 'beard6',
  trimmed: 'beard6',
  goatee: 'beard6',
  imperial: 'mustache',
  wizard: 'beard7',
  ringed: 'beardRinged'
};

export const characterCreatorHairAssetMap = {
  short: 'hairShort',
  medium: 'hairMedium',
  long: 'hairLong',
  braided: 'hairBraided'
};

export const characterCreatorHairStyleCategoryMap = {
  bald: null,
  straight_shoulder: 'medium',
  straight_short: 'short',
  straight_braided: 'braided',
  curly_stubble: 'short',
  curly_short_unkempt: 'short',
  curly_mid_unkempt: 'medium',
  curly_long_unkempt: 'long',
  curly_short_combed: 'short',
  curly_mid_combed: 'medium',
  curly_long_combed: 'long',
  curly_short_braided: 'braided',
  curly_mid_braided: 'braided',
  curly_long_braided: 'braided',
  curly_short_double_braids: 'braided',
  curly_mid_double_braids: 'braided',
  curly_long_double_braids: 'braided'
};

export function normaliseHexColor(hex) {
  if (typeof hex !== 'string') {
    return '#000000';
  }
  let value = hex.trim();
  if (!value) {
    return '#000000';
  }
  if (!value.startsWith('#')) {
    value = `#${value}`;
  }
  const hexPart = value.slice(1);
  if (/^[0-9a-f]{3}$/i.test(hexPart)) {
    const expanded = hexPart
      .split('')
      .map((char) => char.repeat(2))
      .join('');
    return `#${expanded.toLowerCase()}`;
  }
  if (/^[0-9a-f]{6}$/i.test(hexPart)) {
    return `#${hexPart.toLowerCase()}`;
  }
  return '#000000';
}

export function hexToRgb(hex) {
  const normalised = normaliseHexColor(hex);
  const value = normalised.slice(1);
  const r = Number.parseInt(value.slice(0, 2), 16);
  const g = Number.parseInt(value.slice(2, 4), 16);
  const b = Number.parseInt(value.slice(4, 6), 16);
  return {
    r: Number.isNaN(r) ? 0 : r,
    g: Number.isNaN(g) ? 0 : g,
    b: Number.isNaN(b) ? 0 : b
  };
}

export const characterCreatorDefaultSkinColor = '#c47231';
export const characterCreatorDefaultHairColor = '#141015';

const characterCreatorSkinTintCache = new Map();
const characterCreatorHairTintCache = new Map();

const characterCreatorSkinBaseRgb = hexToRgb(characterCreatorDefaultSkinColor);
const characterCreatorSkinBaseColorSum = Math.max(
  characterCreatorSkinBaseRgb.r + characterCreatorSkinBaseRgb.g + characterCreatorSkinBaseRgb.b,
  1
);
const characterCreatorSkinBaseNormalised = {
  r: characterCreatorSkinBaseRgb.r / characterCreatorSkinBaseColorSum,
  g: characterCreatorSkinBaseRgb.g / characterCreatorSkinBaseColorSum,
  b: characterCreatorSkinBaseRgb.b / characterCreatorSkinBaseColorSum
};

function analyseCharacterCreatorAsset(
  assetKey,
  cache,
  hasPropertyKey,
  pixelCheckFn,
  pixelModificationFn,
  multiplierCalculationFn,
  fallbackHasPropertyKey
) {
  if (cache.has(assetKey)) {
    return cache.get(assetKey);
  }
  const asset = characterCreatorPortraitAssets[assetKey];
  const image = asset?.image;
  if (!image || !image.width || !image.height) {
    const fallback = {
      [fallbackHasPropertyKey]: false,
      baseCanvas: null,
      tinted: new Map()
    };
    cache.set(assetKey, fallback);
    return fallback;
  }
  const width = image.width;
  const height = image.height;
  const canvas = document.createElement('canvas');
  canvas.width = width;
  canvas.height = height;
  const ctx = canvas.getContext('2d');
  if (!ctx) {
    const fallback = {
      [fallbackHasPropertyKey]: false,
      baseCanvas: null,
      tinted: new Map()
    };
    cache.set(assetKey, fallback);
    return fallback;
  }
  ctx.imageSmoothingEnabled = false;
  ctx.drawImage(image, 0, 0, width, height);
  const imageData = ctx.getImageData(0, 0, width, height);
  const { data } = imageData;
  const pixelCount = width * height;
  const mask = new Uint8Array(pixelCount);
  const alpha = new Uint8Array(pixelCount);
  const multiplierR = new Float32Array(pixelCount);
  const multiplierG = new Float32Array(pixelCount);
  const multiplierB = new Float32Array(pixelCount);
  let hasProperty = false;
  for (let i = 0, p = 0; i < data.length; i += 4, p += 1) {
    const a = data[i + 3];
    const r = data[i];
    const g = data[i + 1];
    const b = data[i + 2];

    if (pixelCheckFn(r, g, b, a)) {
      mask[p] = 1;
      alpha[p] = a;
      const multipliers = multiplierCalculationFn(r, g, b);
      multiplierR[p] = multipliers.r;
      multiplierG[p] = multipliers.g;
      multiplierB[p] = multipliers.b;
      pixelModificationFn(data, i);
      hasProperty = true;
    }
  }
  if (hasProperty) {
    ctx.putImageData(imageData, 0, 0);
  }
  const analysis = {
    [hasPropertyKey]: hasProperty,
    baseCanvas: canvas,
    mask,
    alpha,
    multiplierR,
    multiplierG,
    multiplierB,
    tinted: new Map()
  };
  cache.set(assetKey, analysis);
  return analysis;
}



function analyseCharacterCreatorSkinAsset(assetKey) {
  const pixelCheckFn = (r, g, b, a) => {
    if (a < 16) return false;
    const sum = r + g + b;
    if (sum === 0) return false;

    // Keep skin masking constrained to warm skin-toned pixels only.
    // This prevents dark slider values (for example coal) from also tinting
    // hair, beard, clothing, or other non-skin details in the portrait layers.
    if (r < g || g < b) return false;

    const brightnessRatio = sum / characterCreatorSkinBaseColorSum;
    if (brightnessRatio < 0.42 || brightnessRatio > 1.75) return false;

    const normalisedR = r / sum;
    const normalisedG = g / sum;
    const normalisedB = b / sum;
    const diffR = Math.abs(normalisedR - characterCreatorSkinBaseNormalised.r);
    const diffG = Math.abs(normalisedG - characterCreatorSkinBaseNormalised.g);
    const diffB = Math.abs(normalisedB - characterCreatorSkinBaseNormalised.b);
    return diffR + diffG + diffB <= 0.14;
  };

  const pixelModificationFn = (data, i) => {
    data[i + 3] = 0;
  };

  const multiplierCalculationFn = (r, g, b) => {
    const safeR = characterCreatorSkinBaseRgb.r || 1;
    const safeG = characterCreatorSkinBaseRgb.g || 1;
    const safeB = characterCreatorSkinBaseRgb.b || 1;
    return {
      r: clamp(r / safeR, 0.15, 2.4),
      g: clamp(g / safeG, 0.15, 2.4),
      b: clamp(b / safeB, 0.15, 2.4),
    };
  };

  return analyseCharacterCreatorAsset(
    assetKey,
    characterCreatorSkinTintCache,
    'hasSkin',
    pixelCheckFn,
    pixelModificationFn,
    multiplierCalculationFn,
    'hasSkin'
  );
}



function createCharacterCreatorTintCanvas(analysis, colorHex) {
  const { baseCanvas, mask, alpha, multiplierR, multiplierG, multiplierB } = analysis;
  if (!baseCanvas || !mask || !alpha || !multiplierR || !multiplierG || !multiplierB) {
    return null;
  }
  const tint = hexToRgb(colorHex);
  const width = baseCanvas.width;
  const height = baseCanvas.height;
  const canvas = document.createElement('canvas');
  canvas.width = width;
  canvas.height = height;
  const ctx = canvas.getContext('2d');
  if (!ctx) {
    return null;
  }
  const imageData = ctx.createImageData(width, height);
  const { data } = imageData;
  for (let i = 0, p = 0; p < mask.length; i += 4, p += 1) {
    if (!mask[p]) {
      continue;
    }
    const alphaValue = alpha[p];
    if (alphaValue <= 0) {
      continue;
    }
    data[i] = clamp(Math.round(tint.r * multiplierR[p]), 0, 255);
    data[i + 1] = clamp(Math.round(tint.g * multiplierG[p]), 0, 255);
    data[i + 2] = clamp(Math.round(tint.b * multiplierB[p]), 0, 255);
    data[i + 3] = alphaValue;
  }
  ctx.putImageData(imageData, 0, 0);
  return canvas;
}

export function getCharacterCreatorSkinTintLayers(assetKey, tintColor) {
  const analysis = analyseCharacterCreatorSkinAsset(assetKey);
  if (!analysis || !analysis.hasSkin || !analysis.baseCanvas) {
    return null;
  }
  const colourKey = normaliseHexColor(tintColor || characterCreatorDefaultSkinColor);
  let tintedCanvas = analysis.tinted.get(colourKey);
  if (!tintedCanvas) {
    tintedCanvas = createCharacterCreatorTintCanvas(analysis, colourKey);
    if (tintedCanvas) {
      analysis.tinted.set(colourKey, tintedCanvas);
    }
  }
  if (!tintedCanvas) {
    return null;
  }
  return {
    baseCanvas: analysis.baseCanvas,
    tintedCanvas
  };
}

function analyseCharacterCreatorHairAsset(assetKey) {
  const pixelCheckFn = (r, g, b, a) => {
    if (a < 8) return false;
    if (r + g + b <= 0) return false;
    return true;
  };

  const pixelModificationFn = (data, i) => {
    data[i] = 0;
    data[i + 1] = 0;
    data[i + 2] = 0;
    data[i + 3] = 0;
  };

  const multiplierCalculationFn = (r, g, b) => {
    return {
      r: clamp(r / 255, 0.05, 1.2),
      g: clamp(g / 255, 0.05, 1.2),
      b: clamp(b / 255, 0.05, 1.2),
    };
  };

  return analyseCharacterCreatorAsset(
    assetKey,
    characterCreatorHairTintCache,
    'hasHair',
    pixelCheckFn,
    pixelModificationFn,
    multiplierCalculationFn,
    'hasHair'
  );
}



export function getCharacterCreatorHairTintLayers(assetKey, tintColor) {
  if (!assetKey) {
    return null;
  }
  const analysis = analyseCharacterCreatorHairAsset(assetKey);
  if (!analysis || !analysis.hasHair || !analysis.baseCanvas) {
    return null;
  }
  const colourKey = normaliseHexColor(tintColor || characterCreatorDefaultHairColor);
  let tintedCanvas = analysis.tinted.get(colourKey);
  if (!tintedCanvas) {
    tintedCanvas = createCharacterCreatorTintCanvas(analysis, colourKey);
    if (tintedCanvas) {
      analysis.tinted.set(colourKey, tintedCanvas);
    }
  }
  if (!tintedCanvas) {
    return null;
  }
  return {
    baseCanvas: analysis.baseCanvas,
    tintedCanvas
  };
}

export const baseTileCoords = {
  SAND: { row: 0, col: 0 },
  GRASS: { row: 0, col: 1 },
  BADLANDS: { row: 1, col: 2 },
  MINE: { row: 1, col: 3 },
  MARSH: { row: 4, col: 2 },
  SNOW: { row: 2, col: 3 },
  TREE: { row: 1, col: 0 },
  TREE_LONE: { row: 5, col: 6 },
  TREE_SNOW: { row: 1, col: 1 },
  JUNGLE_TREE: { row: 3, col: 0 },
  CUT_TREES: { row: 6, col: 1 },
  AMBIENT_LUMBER_MILL: { row: 6, col: 0 },
  WATER: { row: 1, col: 4 },
  MOUNTAIN: { row: 0, col: 3 },
  MOUNTAIN_TOP_A: { row: 0, col: 4 },
  MOUNTAIN_TOP_B: { row: 0, col: 5 },
  MOUNTAIN_BOTTOM_A: { row: 0, col: 7 },
  MOUNTAIN_BOTTOM_B: { row: 0, col: 8 },
  DAM: { row: 1, col: 8 },
  MOUNTAIN_PEAK: { row: 0, col: 10 },
  STONE: { row: 0, col: 2 },
  DWARFHOLD: { row: 2, col: 9 },
  ABANDONED_DWARFHOLD: { row: 2, col: 8 },
  GREAT_DWARFHOLD: { row: 0, col: 6 },
  DARK_DWARFHOLD: { row: 0, col: 17 },
  HILLHOLD: { row: 4, col: 7 },
  CAVE: { row: 1, col: 5 },
  TOWER: { row: 1, col: 6 },
  EVIL_WIZARDS_TOWER: { row: 3, col: 3 },
  WOOD_ELF_GROVES: { row: 2, col: 4 },
  WOOD_ELF_GROVES_LARGE: { row: 2, col: 5 },
  WOOD_ELF_GROVES_GRAND: { row: 2, col: 6 },
  HILLS: { row: 3, col: 1 },
  HILLS_BADLANDS: { row: 4, col: 1 },
  HILLS_VARIANT_A: { row: 4, col: 4 },
  HILLS_VARIANT_B: { row: 5, col: 2 },
  HILLS_SNOW: { row: 3, col: 2 },
  TOWN: { row: 2, col: 1 },
  PORT_TOWN: { row: 4, col: 5 },
  CASTLE: { row: 4, col: 6 },
  ROADSIDE_TAVERN: { row: 1, col: 12 },
  HAMLET: { row: 1, col: 16 },
  ACTIVE_VOLCANO: { row: 2, col: 12 },
  VOLCANO: { row: 2, col: 13 },
  LAVA: { row: 2, col: 14 },
  OASIS: { row: 0, col: 12 },
  HAMLET_SNOW: { row: 0, col: 13 },
  AMBIENT_SLEEPING_DRAGON: { row: 0, col: 14 },
  AMBIENT_HUNTING_LODGE: { row: 0, col: 16 },
  AMBIENT_HOMESTEAD: { row: 1, col: 13 },
  AMBIENT_MOONWELL: { row: 6, col: 2 },
  AMBIENT_FARM: { row: 1, col: 15 },
  FARM_CROPS: { row: 0, col: 15 },
  AMBIENT_FARM_VARIANT: { row: 0, col: 15 },
  AMBIENT_GREAT_TREE: { row: 1, col: 14 },
  AMBIENT_GREAT_TREE_ALT: { row: 2, col: 14 },
  LIZARDMEN_CITY: { row: 2, col: 11 },
  SAINT_SHRINE: { row: 1, col: 11 },
  MONASTERY: { row: 2, col: 2 },
  ORC_CAMP: { row: 3, col: 11 },
  GNOLL_CAMP: { row: 5, col: 1 },
  TROLL_CAMP: { row: 5, col: 1 },
  OGRE_CAMP: { row: 5, col: 1 },
  BANDIT_CAMP: { row: 5, col: 1 },
  TRAVELERS_CAMP: { row: 5, col: 1 },
  DUNGEON: { row: 2, col: 7 },
  CENTAUR_ENCAMPMENT: { row: 2, col: 10 }
};

export const ROAD_DIRECTION_BITS = {
  NORTH: 1,
  EAST: 2,
  SOUTH: 4,
  WEST: 8
};

export const roadTileSpriteDefinitions = (() => {
  const sheet = tileSheets.base;
  if (!sheet) {
    return null;
  }
  const tileSize = sheet.tileSize;
  const row = 4;
  const makeDefinition = (column) => ({
    sheetKey: sheet.key,
    sx: column * tileSize,
    sy: row * tileSize,
    size: tileSize
  });

  return {
    isolated: makeDefinition(18),
    deadEndWest: makeDefinition(21),
    straightEastWest: makeDefinition(8),
    cornerNorthEast: makeDefinition(11),
    cornerSouthEast: makeDefinition(9),
    cornerSouthWest: makeDefinition(10),
    cornerNorthWest: makeDefinition(12),
    teeMissingWest: makeDefinition(13),
    teeMissingEast: makeDefinition(16),
    teeMissingNorth: makeDefinition(14),
    teeMissingSouth: makeDefinition(15),
    cross: makeDefinition(17)
  };
})();

export const riverTileCoords = {
  RIVER_NS: { row: 4, col: 0 },
  RIVER_WE: { row: 4, col: 1 },
  RIVER_SE: { row: 4, col: 2 },
  RIVER_SW: { row: 4, col: 3 },
  RIVER_NE: { row: 4, col: 4 },
  RIVER_NW: { row: 4, col: 5 },
  RIVER_NSE: { row: 4, col: 6 },
  RIVER_SWE: { row: 4, col: 7 },
  RIVER_NWE: { row: 4, col: 8 },
  RIVER_NSW: { row: 4, col: 9 },
  RIVER_NSWE: { row: 4, col: 10 },
  RIVER_0: { row: 4, col: 11 },
  RIVER_N: { row: 4, col: 12 },
  RIVER_S: { row: 4, col: 13 },
  RIVER_W: { row: 4, col: 14 },
  RIVER_E: { row: 4, col: 15 },
  RIVER_MAJOR_NS: { row: 5, col: 0 },
  RIVER_MAJOR_WE: { row: 5, col: 1 },
  RIVER_MAJOR_SE: { row: 5, col: 2 },
  RIVER_MAJOR_SW: { row: 5, col: 3 },
  RIVER_MAJOR_NE: { row: 5, col: 4 },
  RIVER_MAJOR_NW: { row: 5, col: 5 },
  RIVER_MAJOR_NSE: { row: 5, col: 6 },
  RIVER_MAJOR_SWE: { row: 5, col: 7 },
  RIVER_MAJOR_NWE: { row: 5, col: 8 },
  RIVER_MAJOR_NSW: { row: 5, col: 9 },
  RIVER_MAJOR_NSWE: { row: 5, col: 10 },
  RIVER_MAJOR_0: { row: 5, col: 11 },
  RIVER_MAJOR_N: { row: 5, col: 12 },
  RIVER_MAJOR_S: { row: 5, col: 13 },
  RIVER_MAJOR_W: { row: 5, col: 14 },
  RIVER_MAJOR_E: { row: 5, col: 15 },
  RIVER_MOUTH_NARROW_N: { row: 7, col: 12 },
  RIVER_MOUTH_NARROW_S: { row: 7, col: 13 },
  RIVER_MOUTH_NARROW_W: { row: 7, col: 14 },
  RIVER_MOUTH_NARROW_E: { row: 7, col: 15 },
  RIVER_MAJOR_MOUTH_NARROW_N: { row: 8, col: 12 },
  RIVER_MAJOR_MOUTH_NARROW_S: { row: 8, col: 13 },
  RIVER_MAJOR_MOUTH_NARROW_W: { row: 8, col: 14 },
  RIVER_MAJOR_MOUTH_NARROW_E: { row: 8, col: 15 }
};

const icebergTileOptions = [
  { row: 3, col: 4 },
  { row: 3, col: 5 }
];

export const icebergTileCoords = (() => {
  const keys = ['ICEBERG_SURROUND_1', 'ICEBERG_SURROUND_2'];
  return keys.reduce((coords, key, index) => {
    const option = icebergTileOptions[index % icebergTileOptions.length];
    coords[key] = { ...option };
    return coords;
  }, {});
})();

export const tileLookup = new Map();

export function registerTiles(sheetKey, coordMap) {
  const sheet = tileSheets[sheetKey];
  if (!sheet) {
    return;
  }
  Object.entries(coordMap).forEach(([name, coords]) => {
    tileLookup.set(name, {
      sheet: sheetKey,
      sx: coords.col * sheet.tileSize,
      sy: coords.row * sheet.tileSize,
      size: sheet.tileSize
    });
  });
}

export function registerCustomStructure(key, drawFn) {
  if (!key || typeof drawFn !== 'function') {
    return;
  }
  if (tileLookup.has(key)) {
    return;
  }
  tileLookup.set(key, {
    sheet: null,
    sx: 0,
    sy: 0,
    size: tileSheets.base?.tileSize || 32,
    draw: drawFn
  });
}
