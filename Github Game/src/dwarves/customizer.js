const dwarfBeardRows = {
  clean: null,
  short: 24,
  full: 26,
  braided: 29,
  forked: 23,
  mutton: 21,
  stubble: null,
  trimmed: null,
  goatee: null,
  imperial: null,
  wizard: null,
  ringed: null,
  default: 26
};

const dwarfHairColorToFrame = {
  obsidian: { column: 2 },
  umber: { column: 6 },
  auburn: { column: 3 },
  copper: { column: 5, tint: '#b56a33' },
  golden: { column: 4 },
  ashen: { column: 1, tint: '#c0c6d1' },
  white: { column: 1 }
};

const dwarfBaseBodyTint = '#5b473c';

const dwarfPortraitBaseFrames = {
  male: {
    sheet: 'body',
    col: 0,
    row: 0,
    tint: dwarfBaseBodyTint,
    offsetY: 4,
    sourceTileSize: 64,
    destTileSize: 64
  },
  female: {
    sheet: 'body',
    col: 0,
    row: 1,
    tint: dwarfBaseBodyTint,
    offsetY: 4,
    sourceTileSize: 64,
    destTileSize: 64
  }
};

const dwarfPortraitConfig = {
  tileSize: 64,
  scale: 2,
  baseFrame: dwarfPortraitBaseFrames.male,
  baseFrames: dwarfPortraitBaseFrames,
  head: {
    sheet: 'head',
    rows: { male: 0, female: 1 },
    row: 0,
    offsetY: -1
  },
  hairOffsetY: -4,
  beardOffsetY: 8,
  eyePositions: [
    { x: 27.5, y: 30 },
    { x: 33.5, y: 30 }
  ],
  eyeSize: 1
};

const bodyPanelPortraitScaleMultiplier = 1.6;

const dwarfPortraitState = {
  canvas: null,
  ctx: null
};

const dwarfBodyPortraitState = {
  canvas: null,
  ctx: null
};

const dwarfTraitAttributeDefinitions = [
  {
    key: 'beardless',
    label: 'Beardless',
    description:
      'You are the shame of your clan and the disgrace of your holdfast. Without a beard a dwarf is nothing, consider this path to be one that will lead to scorn and ridicule among your peers.',
    icon: 'tilesheet/beardless.png',
    isActive: (dwarf) => {
      if (dwarf?.gender !== 'male') {
        return false;
      }
      const beardValue = dwarf?.beard || 'clean';
      const hasBeardConfig = Object.prototype.hasOwnProperty.call(dwarfBeardRows, beardValue);
      const row = hasBeardConfig ? dwarfBeardRows[beardValue] : dwarfBeardRows.default;
      return row === null || row === undefined;
    }
  },
  {
    key: 'dark-dwarf',
    label: 'Dark Dwarf Heritage',
    description:
      'Your soot colored skin indicates that you hail from the ash covered lands of Dun Mortis. You are known by your ivory skinned cousins as the Dark Dwarves, a race cast away from the light of the All-father into the refuse bin of Stonebeard’s furnace. You are hated by your kin as an oathbreaker by virtue of your birthright and if you attempt to enter into their holds will likely be killed on sight.',
    icon: 'tilesheet/darkdwarf.png',
    isActive: (dwarf) => dwarf?.skin === 'umber' || dwarf?.skin === 'coal'
  },
  {
    key: 'banker-profession',
    label: 'Banker',
    description:
      'Among men you would be in a respected profession, among dwarves it’s the opposite; expect your increased income to be met with glaring judgments and disdain from your peers who think your very livelihood to be undwarflike.',
    icon: 'tilesheet/banker.png',
    isActive: (dwarf) => dwarf?.profession === 'banker'
  },
  {
    key: 'grey-dwarf',
    label: 'Grey Dwarf Heritage',
    description:
      'Your skin is the colour of ashes and your heart is that of steel. Known as a Duergar you may not be as despised as the dark dwarves are yet the kinship you have with the rest of Dwarfdom is strained. Your ancestors were followers of the Lawgiver and Forgebearers of the Forgotten Era who preached a strain of total dwarven separatism and supremacy that led your people to form holds far away from your homeland. You may be welcomed into any dwarf hold but not well liked and the races you hunt as slaves will attack you on sight.',
    monogram: 'GD',
    isActive: (dwarf) => dwarf?.skin === 'ashen'
  }
];

const ensureDocument = () => (typeof document !== 'undefined' ? document : null);

const getOption = (resolver, category, value) =>
  typeof resolver === 'function' ? resolver(category, value) : null;

const getLabel = (resolver, category, value) =>
  typeof resolver === 'function' ? resolver(category, value) : value;

const getHairSummary = (deps, dwarf) =>
  typeof deps?.getHairSummaryPhrase === 'function' ? deps.getHairSummaryPhrase(dwarf) : 'hair';

const getBaseBodyFrame = (dwarf) => {
  const frames = dwarfPortraitConfig.baseFrames;
  const gender = dwarf?.gender;
  if (gender && frames && Object.prototype.hasOwnProperty.call(frames, gender)) {
    return frames[gender];
  }
  return dwarfPortraitConfig.baseFrame || null;
};

const ensurePortraitContext = (elements) => {
  const canvas = elements?.dwarfPortraitCanvas || null;
  if (!canvas) {
    dwarfPortraitState.canvas = null;
    dwarfPortraitState.ctx = null;
    return null;
  }
  if (canvas !== dwarfPortraitState.canvas) {
    const context = canvas.getContext('2d');
    if (!context) {
      dwarfPortraitState.canvas = null;
      dwarfPortraitState.ctx = null;
      return null;
    }
    context.imageSmoothingEnabled = false;
    dwarfPortraitState.canvas = canvas;
    dwarfPortraitState.ctx = context;
  }
  return dwarfPortraitState.ctx;
};

const ensureBodyPortraitContext = (elements) => {
  const canvas = elements?.dwarfBodyPortraitCanvas || null;
  if (!canvas) {
    dwarfBodyPortraitState.canvas = null;
    dwarfBodyPortraitState.ctx = null;
    return null;
  }
  if (canvas !== dwarfBodyPortraitState.canvas) {
    const context = canvas.getContext('2d');
    if (!context) {
      dwarfBodyPortraitState.canvas = null;
      dwarfBodyPortraitState.ctx = null;
      return null;
    }
    context.imageSmoothingEnabled = false;
    dwarfBodyPortraitState.canvas = canvas;
    dwarfBodyPortraitState.ctx = context;
  }
  return dwarfBodyPortraitState.ctx;
};

const drawTintedSprite = (ctx, sheetKey, frame, baseX, baseY, scale, tint, deps = {}) => {
  if (!frame || !sheetKey) {
    return;
  }
  const sheet = deps.dwarfSpriteSheets?.[sheetKey];
  if (!sheet?.image) {
    return;
  }
  const tileSize = frame.destTileSize || dwarfPortraitConfig.tileSize;
  const sx = (frame.col || 0) * tileSize;
  const sy = (frame.row || 0) * tileSize;
  const sw = tileSize;
  const sh = tileSize;
  const destX = baseX;
  const destY = baseY + (frame.offsetY || 0) * (scale || 1);
  const destW = sw * (scale || 1);
  const destH = sh * (scale || 1);

  const offscreen = document.createElement('canvas');
  offscreen.width = sw;
  offscreen.height = sh;
  const offscreenCtx = offscreen.getContext('2d');
  if (!offscreenCtx) {
    return;
  }
  offscreenCtx.imageSmoothingEnabled = false;
  offscreenCtx.drawImage(sheet.image, sx, sy, sw, sh, 0, 0, sw, sh);
  if (tint) {
    offscreenCtx.globalCompositeOperation = 'source-atop';
    offscreenCtx.fillStyle = tint;
    offscreenCtx.globalAlpha = 0.9;
    offscreenCtx.fillRect(0, 0, sw, sh);
    offscreenCtx.globalAlpha = 1;
    offscreenCtx.globalCompositeOperation = 'source-over';
  }
  ctx.drawImage(offscreen, 0, 0, sw, sh, destX, destY, destW, destH);
};

const getHeadFrame = (dwarf, headValue, deps = {}) => {
  const headConfig = dwarfPortraitConfig.head;
  const resolvedValue =
    typeof deps.resolveHeadTypeValue === 'function'
      ? deps.resolveHeadTypeValue(headValue)
      : headValue;
  const headType = deps.dwarfHeadTypes?.[resolvedValue];
  if (!headConfig || !headType) {
    return null;
  }
  const sheet = headConfig.sheet;
  const sheetConfig = deps.dwarfSpriteSheets?.[sheet];
  const sourceTileSize =
    typeof sheetConfig?.tileSize === 'number' ? sheetConfig.tileSize : dwarfPortraitConfig.tileSize;
  const genderRow =
    headConfig.rows && Object.prototype.hasOwnProperty.call(headConfig.rows, dwarf?.gender)
      ? headConfig.rows[dwarf?.gender]
      : undefined;
  const row = typeof genderRow === 'number' ? genderRow : headConfig.row || 0;
  return {
    sheet,
    col: headType.column,
    row,
    offsetY: headConfig.offsetY ?? 0,
    sourceTileSize,
    destTileSize: dwarfPortraitConfig.tileSize
  };
};

const getHairFrame = (dwarf, hairOption, hairStyleValue, deps = {}) => {
  const styleConfig =
    typeof deps.getHairStyleConfig === 'function'
      ? deps.getHairStyleConfig(hairStyleValue ?? dwarf?.hairStyle)
      : null;
  const rows = styleConfig?.rows || {};
  const genderRow = rows[dwarf?.gender];
  const row = typeof genderRow === 'number' ? genderRow : rows.default;
  const mapping = dwarfHairColorToFrame[hairOption?.value] || dwarfHairColorToFrame.obsidian;
  if (typeof row !== 'number' || !mapping || typeof mapping.column !== 'number') {
    return null;
  }
  return {
    sheet: styleConfig?.sheet || 'hair',
    col: mapping.column,
    row,
    tint: mapping.tint || null,
    offsetY: styleConfig?.offsetY ?? dwarfPortraitConfig.hairOffsetY,
    destTileSize: dwarfPortraitConfig.tileSize
  };
};

const getBeardFrame = (dwarf, hairOption) => {
  if (!dwarf || dwarf.gender === 'female') {
    return null;
  }
  const beardValue = dwarf.beard || 'clean';
  const hasBeardConfig = Object.prototype.hasOwnProperty.call(dwarfBeardRows, beardValue);
  const row = hasBeardConfig ? dwarfBeardRows[beardValue] : dwarfBeardRows.default;
  if (row === null || row === undefined) {
    return null;
  }
  const mapping = dwarfHairColorToFrame[hairOption?.value] || dwarfHairColorToFrame.obsidian;
  if (!mapping || typeof mapping.column !== 'number') {
    return null;
  }
  return {
    sheet: 'hair',
    col: mapping.column,
    row,
    tint: mapping.tint || null,
    offsetY: dwarfPortraitConfig.beardOffsetY,
    destTileSize: dwarfPortraitConfig.tileSize
  };
};

const shouldUseCharacterCreatorPortrait = (dwarf, deps) => {
  if (!dwarf) {
    return false;
  }
  const gender = dwarf.gender === 'female' ? 'female' : 'male';
  const bodyKey = gender === 'female' ? 'femaleBody' : 'maleBody';
  const bodyImage = deps.characterCreatorPortraitAssets?.[bodyKey]?.image || null;
  const headImage = deps.characterCreatorPortraitAssets?.headDefault?.image || null;
  return Boolean(bodyImage && headImage);
};

const getCharacterCreatorHairAssetKey = (dwarf, deps) => {
  if (!dwarf) {
    return null;
  }
  const resolvedStyle =
    typeof deps.resolveHairStyleValue === 'function'
      ? deps.resolveHairStyleValue(dwarf.hairStyle)
      : dwarf?.hairStyle;
  const category = deps.characterCreatorHairStyleCategoryMap?.[resolvedStyle];
  if (!category) {
    return null;
  }
  return deps.characterCreatorHairAssetMap?.[category] || null;
};

const getCharacterCreatorBeardAssetKey = (dwarf, deps) => {
  if (!dwarf || dwarf.gender === 'female') {
    return null;
  }
  return deps.characterCreatorBeardAssetMap?.[dwarf.beard] || null;
};

const getCharacterCreatorBeardImage = (dwarf, deps) => {
  const assetKey = getCharacterCreatorBeardAssetKey(dwarf, deps);
  return assetKey ? deps.characterCreatorPortraitAssets?.[assetKey]?.image || null : null;
};

const renderCharacterCreatorPortrait = (ctx, canvas, dwarf, appearance, deps) => {
  const gender = dwarf?.gender === 'female' ? 'female' : 'male';
  const bodyKey = gender === 'female' ? 'femaleBody' : 'maleBody';
  const bodyImage = deps.characterCreatorPortraitAssets?.[bodyKey]?.image;
  const headImage = deps.characterCreatorPortraitAssets?.headDefault?.image;
  if (!bodyImage || !headImage) {
    return;
  }
  ctx.imageSmoothingEnabled = false;
  const scale = Math.min(canvas.width / bodyImage.width, canvas.height / bodyImage.height);
  const drawWidth = bodyImage.width * scale;
  const drawHeight = bodyImage.height * scale;
  const offsetX = Math.floor((canvas.width - drawWidth) / 2);
  const offsetY = Math.floor((canvas.height - drawHeight) / 2);
  const skinColor =
    appearance.skin?.color || deps.characterCreatorDefaultSkinColor || '#c59b7d';
  const bodyLayers =
    typeof deps.getCharacterCreatorSkinTintLayers === 'function'
      ? deps.getCharacterCreatorSkinTintLayers(bodyKey, skinColor)
      : null;
  if (bodyLayers) {
    ctx.drawImage(bodyLayers.baseCanvas, offsetX, offsetY, drawWidth, drawHeight);
    ctx.drawImage(bodyLayers.tintedCanvas, offsetX, offsetY, drawWidth, drawHeight);
  } else {
    ctx.drawImage(bodyImage, offsetX, offsetY, drawWidth, drawHeight);
  }

  const shouldRenderHead = gender !== 'female';
  if (shouldRenderHead) {
    const headLayers =
      typeof deps.getCharacterCreatorSkinTintLayers === 'function'
        ? deps.getCharacterCreatorSkinTintLayers('headDefault', skinColor)
        : null;
    if (headLayers) {
      ctx.drawImage(headLayers.baseCanvas, offsetX, offsetY, drawWidth, drawHeight);
      ctx.drawImage(headLayers.tintedCanvas, offsetX, offsetY, drawWidth, drawHeight);
    } else {
      ctx.drawImage(headImage, offsetX, offsetY, drawWidth, drawHeight);
    }
  }

  const hairAssetKey = getCharacterCreatorHairAssetKey(dwarf, deps);
  if (hairAssetKey) {
    const hairTintLayers =
      typeof deps.getCharacterCreatorHairTintLayers === 'function'
        ? deps.getCharacterCreatorHairTintLayers(
            hairAssetKey,
            appearance.hair?.color || deps.characterCreatorDefaultHairColor
          )
        : null;
    if (hairTintLayers) {
      ctx.drawImage(hairTintLayers.baseCanvas, offsetX, offsetY, drawWidth, drawHeight);
      ctx.drawImage(hairTintLayers.tintedCanvas, offsetX, offsetY, drawWidth, drawHeight);
    } else {
      const hairImage = deps.characterCreatorPortraitAssets?.[hairAssetKey]?.image || null;
      if (hairImage) {
        ctx.drawImage(hairImage, offsetX, offsetY, drawWidth, drawHeight);
      }
    }
  }

  const beardAssetKey = getCharacterCreatorBeardAssetKey(dwarf, deps);
  if (beardAssetKey) {
    const beardTintLayers =
      typeof deps.getCharacterCreatorHairTintLayers === 'function'
        ? deps.getCharacterCreatorHairTintLayers(
            beardAssetKey,
            appearance.hair?.color || deps.characterCreatorDefaultHairColor
          )
        : null;
    if (beardTintLayers) {
      ctx.drawImage(beardTintLayers.baseCanvas, offsetX, offsetY, drawWidth, drawHeight);
      ctx.drawImage(beardTintLayers.tintedCanvas, offsetX, offsetY, drawWidth, drawHeight);
    } else {
      const beardImage = deps.characterCreatorPortraitAssets?.[beardAssetKey]?.image || null;
      if (beardImage) {
        ctx.drawImage(beardImage, offsetX, offsetY, drawWidth, drawHeight);
      }
    }
  }

  const shouldRenderNose = gender !== 'female';
  const noseImage = shouldRenderNose ? deps.characterCreatorPortraitAssets?.nose?.image : null;
  if (noseImage) {
    ctx.drawImage(noseImage, offsetX, offsetY, drawWidth, drawHeight);
  }
};

const renderTilesheetPortrait = (ctx, canvas, dwarf, appearance, options = {}, deps = {}) => {
  const { skin, hair, eyes, hairStyle, head } = appearance;
  const { tileSize, scale: baseScale, head: headConfig, eyePositions, eyeSize } = dwarfPortraitConfig;
  const scaleMultiplier = typeof options.scaleMultiplier === 'number' ? options.scaleMultiplier : 1;
  const scale = typeof options.scale === 'number' ? options.scale : baseScale * scaleMultiplier;
  const destSize = tileSize * scale;
  const baseX = Math.floor((canvas.width - destSize) / 2);
  const baseY = Math.floor((canvas.height - destSize) / 2);

  const baseFrame = getBaseBodyFrame(dwarf);
  if (baseFrame) {
    drawTintedSprite(ctx, baseFrame.sheet, baseFrame, baseX, baseY, scale, baseFrame.tint, deps);
  }

  if (headConfig) {
    const headFrame = getHeadFrame(dwarf, head?.value ?? dwarf?.head, deps);
    if (headFrame) {
      const skinColor = skin?.color || '#c59b7d';
      drawTintedSprite(ctx, headFrame.sheet, headFrame, baseX, baseY, scale, skinColor, deps);
    }
  }

  const resolveHairStyle =
    typeof deps.resolveHairStyleValue === 'function' ? deps.resolveHairStyleValue : (value) => value;
  const hairStyleValue = resolveHairStyle(hairStyle?.value ?? dwarf?.hairStyle);
  const hairFrame = getHairFrame(dwarf, hair, hairStyleValue, deps);
  if (hairFrame) {
    drawTintedSprite(ctx, hairFrame.sheet, hairFrame, baseX, baseY, scale, hairFrame.tint, deps);
  }

  const beardFrame = getBeardFrame(dwarf, hair);
  if (beardFrame) {
    drawTintedSprite(ctx, beardFrame.sheet, beardFrame, baseX, baseY, scale, beardFrame.tint, deps);
  }

  const eyeColor = eyes?.color || '#604a2b';
  ctx.fillStyle = eyeColor;
  eyePositions.forEach(({ x, y }) => {
    ctx.fillRect(baseX + Math.round(x * scale), baseY + Math.round(y * scale), eyeSize * scale, eyeSize * scale);
  });

  ctx.fillStyle = 'rgba(255, 255, 255, 0.78)';
  eyePositions.forEach(({ x, y }) => {
    const highlightSize = Math.max(1, Math.floor(scale / 2));
    ctx.fillRect(
      baseX + Math.round((x + 0.5) * scale),
      baseY + Math.round((y + 0.5) * scale),
      highlightSize,
      highlightSize
    );
  });
};

const renderPrimaryPortrait = (dwarf, appearance, deps) => {
  const ctx = ensurePortraitContext(deps.elements);
  if (!ctx) {
    return;
  }
  const canvas = dwarfPortraitState.canvas;
  if (!canvas) {
    return;
  }
  ctx.clearRect(0, 0, canvas.width, canvas.height);
  if (shouldUseCharacterCreatorPortrait(dwarf, deps)) {
    renderCharacterCreatorPortrait(ctx, canvas, dwarf, appearance, deps);
    return;
  }
  renderTilesheetPortrait(ctx, canvas, dwarf, appearance, {}, deps);
};

const renderBodyPortrait = (dwarf, appearance, deps) => {
  const ctx = ensureBodyPortraitContext(deps.elements);
  if (!ctx) {
    return;
  }
  const canvas = dwarfBodyPortraitState.canvas;
  if (!canvas) {
    return;
  }
  ctx.clearRect(0, 0, canvas.width, canvas.height);
  renderTilesheetPortrait(
    ctx,
    canvas,
    dwarf,
    appearance,
    { scaleMultiplier: bodyPanelPortraitScaleMultiplier },
    deps
  );
};

const getDwarfDisplayName = (dwarf) => {
  if (!dwarf) {
    return 'Unnamed Founder';
  }
  const trimmed = (dwarf.name || '').trim();
  return trimmed || 'Unnamed Founder';
};

const buildDwarfSummary = (dwarf, deps) => {
  if (!dwarf) {
    return '';
  }
  const genderLabel = getLabel(deps.getOptionLabel, 'gender', dwarf.gender);
  const skinLabel = getLabel(deps.getOptionLabel, 'skin', dwarf.skin).toLowerCase();
  const eyeLabel = getLabel(deps.getOptionLabel, 'eyes', dwarf.eyes).toLowerCase();
  const hairPhrase = getHairSummary(deps, dwarf);
  const beardLabel = getLabel(deps.getOptionLabel, 'beard', dwarf.beard).toLowerCase();
  const headLabel = getLabel(deps.getOptionLabel, 'head', dwarf.head).toLowerCase();
  const clanLabel = getLabel(deps.getOptionLabel, 'clan', dwarf.clan);
  const guildLabel = getLabel(deps.getOptionLabel, 'guild', dwarf.guild);
  const professionLabel = getLabel(deps.getOptionLabel, 'profession', dwarf.profession);
  let summary = `${genderLabel} dwarf with ${headLabel} features, ${skinLabel} skin, ${hairPhrase}, ${eyeLabel} eyes, and ${beardLabel}.`;
  const affiliationSentences = [];
  if (clanLabel) {
    affiliationSentences.push(`Member of the ${clanLabel} clan`);
  }
  if (professionLabel && guildLabel) {
    affiliationSentences.push(`${professionLabel} of the ${guildLabel}`);
  } else if (professionLabel) {
    affiliationSentences.push(professionLabel);
  } else if (guildLabel) {
    affiliationSentences.push(`Of the ${guildLabel}`);
  }
  if (affiliationSentences.length > 0) {
    summary += ` ${affiliationSentences.join('. ')}.`;
  }
  return summary;
};

const getActiveTraitAttributes = (dwarf) => {
  if (!dwarf) {
    return [];
  }
  return dwarfTraitAttributeDefinitions.filter((attribute) => {
    try {
      return typeof attribute.isActive === 'function' ? attribute.isActive(dwarf) : false;
    } catch (_error) {
      return false;
    }
  });
};

const createTraitAttributeElement = (attribute) => {
  const doc = ensureDocument();
  if (!doc) {
    return null;
  }
  const item = doc.createElement('div');
  item.className = 'trait-attribute';
  item.setAttribute('role', 'listitem');
  item.setAttribute('tabindex', '0');
  item.setAttribute('aria-label', attribute.label);

  if (attribute.icon) {
    const icon = doc.createElement('img');
    icon.className = 'trait-attribute__icon';
    icon.src = attribute.icon;
    icon.alt = attribute.label;
    icon.loading = 'lazy';
    item.appendChild(icon);
  } else {
    const monogram = doc.createElement('span');
    monogram.className = 'trait-attribute__icon trait-attribute__icon--monogram';
    const fallback = attribute.monogram || attribute.label || '';
    monogram.textContent = fallback
      .split(/\s+/)
      .filter(Boolean)
      .map((part) => part[0])
      .slice(0, 2)
      .join('')
      .toUpperCase();
    item.appendChild(monogram);
  }

  const content = doc.createElement('div');
  content.className = 'trait-attribute__tooltip';
  const title = doc.createElement('p');
  title.className = 'trait-attribute__tooltip-title';
  title.textContent = attribute.label;
  const description = doc.createElement('p');
  description.className = 'trait-attribute__tooltip-description';
  description.textContent = attribute.description;
  content.appendChild(title);
  content.appendChild(description);
  item.appendChild(content);
  return item;
};

const updateDwarfTraitAttributes = (deps, dwarf = null) => {
  const container = deps?.elements?.dwarfTraitAttributes || null;
  if (!container) {
    return;
  }
  const doc = ensureDocument();
  if (!doc) {
    return;
  }
  const activeAttributes = getActiveTraitAttributes(dwarf);
  const fragment = doc.createDocumentFragment();
  activeAttributes.forEach((attribute) => {
    const element = createTraitAttributeElement(attribute);
    if (element) {
      fragment.appendChild(element);
    }
  });
  container.innerHTML = '';
  if (activeAttributes.length > 0) {
    container.setAttribute('role', 'list');
    container.appendChild(fragment);
  } else {
    container.removeAttribute('role');
  }
};

export const updateDwarfPortrait = (dwarf, deps = {}) => {
  if (!dwarf || !deps?.elements?.dwarfPortrait) {
    return;
  }
  const getOptionByValue = deps.getOptionByValue;
  if (typeof getOptionByValue !== 'function') {
    return;
  }
  const appearance = {
    skin: getOptionByValue('skin', dwarf.skin),
    hair: getOptionByValue('hair', dwarf.hair),
    eyes: getOptionByValue('eyes', dwarf.eyes),
    hairStyle: getOptionByValue('hairStyle', dwarf.hairStyle),
    head: getOptionByValue('head', dwarf.head)
  };

  renderPrimaryPortrait(dwarf, appearance, deps);
  renderBodyPortrait(dwarf, appearance, deps);

  const beardValue = dwarf.beard || 'clean';
  const genderLabel = getLabel(deps.getOptionLabel, 'gender', dwarf.gender);
  const skinLabel = getLabel(deps.getOptionLabel, 'skin', dwarf.skin).toLowerCase();
  const hairPhrase = getHairSummary(deps, dwarf);
  const eyeLabel = getLabel(deps.getOptionLabel, 'eyes', dwarf.eyes).toLowerCase();
  const beardLabel = getLabel(deps.getOptionLabel, 'beard', beardValue).toLowerCase();
  const headLabel = getLabel(deps.getOptionLabel, 'head', dwarf.head).toLowerCase();
  const clanLabel = getLabel(deps.getOptionLabel, 'clan', dwarf.clan);
  const guildLabel = getLabel(deps.getOptionLabel, 'guild', dwarf.guild);
  const professionLabel = getLabel(deps.getOptionLabel, 'profession', dwarf.profession);
  const affiliationParts = [];
  if (clanLabel) {
    affiliationParts.push(`member of the ${clanLabel} clan`);
  }
  if (professionLabel && guildLabel) {
    affiliationParts.push(`${professionLabel.toLowerCase()} of the ${guildLabel}`);
  } else if (professionLabel) {
    affiliationParts.push(professionLabel.toLowerCase());
  } else if (guildLabel) {
    affiliationParts.push(`of the ${guildLabel}`);
  }
  let ariaDescription = `${genderLabel} dwarf with ${headLabel} features, ${skinLabel} skin, ${hairPhrase}, ${eyeLabel} eyes, and ${beardLabel}.`;
  if (affiliationParts.length > 0) {
    ariaDescription += ` ${affiliationParts.join(', ')}.`;
  }
  const displayName = getDwarfDisplayName(dwarf);
  deps.elements.dwarfPortrait.setAttribute('aria-label', `${displayName}: ${ariaDescription}`);
};

export const updateDwarfTraitSummary = (deps = {}) => {
  const dwarf = typeof deps.getActiveDwarf === 'function' ? deps.getActiveDwarf() : null;
  if (deps.elements?.dwarfTraitSummary) {
    deps.elements.dwarfTraitSummary.textContent = buildDwarfSummary(dwarf, deps);
  }
  updateDwarfTraitAttributes(deps, dwarf);
};

export const updateRosterList = (deps = {}) => {
  const list = deps.elements?.dwarfRosterList;
  const party = deps.state?.dwarfParty;
  if (!list || !party || !Array.isArray(party.dwarves)) {
    return;
  }
  const doc = ensureDocument();
  if (!doc) {
    return;
  }
  const { dwarves, activeIndex } = party;
  const fragment = doc.createDocumentFragment();
  const bullet = ` \u2022 `;

  dwarves.forEach((dwarf, index) => {
    const item = doc.createElement('li');
    item.classList.toggle('active', index === activeIndex);
    item.setAttribute('role', 'button');
    item.setAttribute('tabindex', '0');
    item.setAttribute('aria-pressed', index === activeIndex ? 'true' : 'false');
    item.dataset.index = index.toString();

    const name = doc.createElement('p');
    name.className = 'dwarf-roster-name';
    name.textContent = getDwarfDisplayName(dwarf);

    const traits = doc.createElement('p');
    traits.className = 'dwarf-roster-traits';
    const genderLabel = getLabel(deps.getOptionLabel, 'gender', dwarf.gender);
    const headLabel = getLabel(deps.getOptionLabel, 'head', dwarf.head);
    const hairStyleLabel = getLabel(deps.getOptionLabel, 'hairStyle', dwarf.hairStyle);
    const hairLabel = getLabel(deps.getOptionLabel, 'hair', dwarf.hair);
    const beardLabel = getLabel(deps.getOptionLabel, 'beard', dwarf.beard);
    traits.textContent = [genderLabel, headLabel, hairStyleLabel, hairLabel, beardLabel]
      .filter(Boolean)
      .join(bullet);

    const affiliations = doc.createElement('p');
    affiliations.className = 'dwarf-roster-traits dwarf-roster-affiliations';
    const affiliationParts = [];
    const clanLabel = getLabel(deps.getOptionLabel, 'clan', dwarf.clan);
    const guildLabel = getLabel(deps.getOptionLabel, 'guild', dwarf.guild);
    const professionLabel = getLabel(deps.getOptionLabel, 'profession', dwarf.profession);
    if (clanLabel) {
      affiliationParts.push(`${clanLabel} Clan`);
    }
    if (guildLabel) {
      affiliationParts.push(guildLabel);
    }
    if (professionLabel) {
      affiliationParts.push(professionLabel);
    }
    affiliations.textContent = affiliationParts.join(bullet);

    item.appendChild(name);
    item.appendChild(traits);
    if (affiliationParts.length > 0) {
      item.appendChild(affiliations);
    }

    if (typeof deps.setActiveDwarf === 'function') {
      item.addEventListener('click', () => {
        deps.setActiveDwarf(index);
      });

      item.addEventListener('keydown', (event) => {
        if (event.key === 'Enter' || event.key === ' ') {
          event.preventDefault();
          deps.setActiveDwarf(index);
        }
      });
    }

    fragment.appendChild(item);
  });

  list.replaceChildren(fragment);
};
