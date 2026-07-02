function getElementById(id) {
  if (typeof document === 'undefined') {
    return null;
  }
  return document.getElementById(id);
}

function queryAll(selector) {
  if (typeof document === 'undefined') {
    return [];
  }
  return Array.from(document.querySelectorAll(selector));
}

const elementInitialisers = {
  startButton: () => getElementById('start-button'),
  titleScreen: () => getElementById('title-screen'),
  gameContainer: () => getElementById('game-container'),
  loadingScreen: () => getElementById('loading-screen'),
  loadingPanel: () => (typeof document === 'undefined' ? null : document.querySelector('#loading-screen .loading-panel')),
  loadingProgressBar: () => getElementById('loading-progress'),
  loadingProgressFill: () => getElementById('loading-progress-fill'),
  loadingStatus: () => getElementById('loading-status'),
  optionsButton: () => getElementById('title-options-button'),
  inGameOptions: () => getElementById('in-game-options'),
  optionsScreen: () => getElementById('options-screen'),
  closeOptions: () => getElementById('close-options'),
  optionsForm: () => getElementById('options-form'),
  regenerate: () => getElementById('regenerate-button'),
  canvas: () => getElementById('world-canvas'),
  canvasWrapper: () => (typeof document === 'undefined' ? null : document.querySelector('.canvas-wrapper')),
  structureContextMenu: () => getElementById('structure-context-menu'),
  structureContextMenuBegin: () => getElementById('structure-context-menu-begin'),
  structureContextMenuMoreInfo: () => getElementById('structure-context-menu-more-info'),
  localMapPanel: () => getElementById('local-map-panel'),
  localMapCanvas: () => getElementById('local-map-canvas'),
  localMapTitle: () => getElementById('local-map-title'),
  localMapSubtitle: () => getElementById('local-map-subtitle'),
  localMapCoordinates: () => getElementById('local-map-coordinates'),
  localMapClose: () => getElementById('local-map-close'),
  localMapZoomIn: () => getElementById('local-map-zoom-in'),
  localMapZoomOut: () => getElementById('local-map-zoom-out'),
  localMapZoomReset: () => getElementById('local-map-zoom-reset'),
  localMapDetails: () => getElementById('local-map-details'),
  dwarfholdScreen: () => getElementById('dwarfhold-screen'),
  dwarfholdCanvas: () => getElementById('dwarfhold-canvas'),
  dwarfholdTitle: () => getElementById('dwarfhold-title'),
  dwarfholdSubtitle: () => getElementById('dwarfhold-subtitle'),
  dwarfholdDescription: () => getElementById('dwarfhold-description'),
  dwarfholdFeatures: () => getElementById('dwarfhold-features'),
  dwarfholdLegend: () => getElementById('dwarfhold-legend'),
  dwarfholdExit: () => getElementById('dwarfhold-exit'),
  dwarfholdCoordinates: () => getElementById('dwarfhold-coordinates'),
  dwarfholdNpcs: () => getElementById('dwarfhold-npcs'),
  dwarfholdNpcsSection: () => getElementById('dwarfhold-npcs-section'),
  structureDetailsPanel: () => getElementById('structure-details'),
  structureDetailsTitle: () => getElementById('structure-details-title'),
  structureDetailsSubtitle: () => getElementById('structure-details-subtitle'),
  structureDetailsContent: () => getElementById('structure-details-content'),
  structureDetailsTabs: () => queryAll('.structure-details-tab'),
  structureDetailsClose: () => getElementById('structure-details-close'),
  seedDisplay: () => (typeof document === 'undefined' ? null : document.querySelector('.seed-display')),
  politicalBordersToggle: () => getElementById('toggle-political-borders'),
  politicalInfluenceToggle: () => getElementById('toggle-political-influence'),
  elevationToggle: () => getElementById('toggle-elevation'),
  biomeToggle: () => getElementById('toggle-biomes'),
  temperatureToggle: () => getElementById('toggle-temperature'),
  locationLabelToggle: () => getElementById('toggle-location-labels'),
  structureHighlightToggle: () => getElementById('toggle-structure-highlights'),
  structureHighlightMenu: () => getElementById('structure-highlight-menu'),
  mapEditorToggle: () => getElementById('toggle-map-editor'),
  mapEditorPanel: () => getElementById('map-editor'),
  mapEditorClose: () => getElementById('map-editor-close'),
  mapEditorTerrainInput: () => getElementById('map-editor-terrain'),
  mapEditorStructureInput: () => getElementById('map-editor-structure'),
  mapEditorApplyTerrain: () => getElementById('map-editor-apply-terrain'),
  mapEditorApplyStructure: () => getElementById('map-editor-apply-structure'),
  mapEditorBrushSizeInput: () => getElementById('map-editor-brush-size'),
  mapEditorClearStructure: () => getElementById('map-editor-clear-structure'),
  mapEditorTerrainOptions: () => getElementById('map-editor-terrain-options'),
  mapEditorStructureOptions: () => getElementById('map-editor-structure-options'),
  mapSizeSelect: () => getElementById('map-size'),
  worldGenerationTypeSelect: () => getElementById('world-generation-type'),
  seedInput: () => getElementById('world-seed'),
  worldMapSizeSelect: () => getElementById('world-map-size-select'),
  worldSeedInput: () => getElementById('world-seed-input'),
  forestFrequencyInput: () => getElementById('forest-frequency'),
  forestFrequencyValue: () => getElementById('forest-frequency-value'),
  mountainFrequencyInput: () => getElementById('mountain-frequency'),
  mountainFrequencyValue: () => getElementById('mountain-frequency-value'),
  riverFrequencyInput: () => getElementById('river-frequency'),
  riverFrequencyValue: () => getElementById('river-frequency-value'),
  humanSettlementFrequencyInput: () => getElementById('human-settlement-frequency'),
  humanSettlementFrequencyValue: () => getElementById('human-settlement-frequency-value'),
  dwarfSettlementFrequencyInput: () => getElementById('dwarf-settlement-frequency'),
  dwarfSettlementFrequencyValue: () => getElementById('dwarf-settlement-frequency-value'),
  woodElfSettlementFrequencyInput: () => getElementById('wood-elf-settlement-frequency'),
  woodElfSettlementFrequencyValue: () => getElementById('wood-elf-settlement-frequency-value'),
  lizardmenSettlementFrequencyInput: () => getElementById('lizardmen-settlement-frequency'),
  lizardmenSettlementFrequencyValue: () => getElementById('lizardmen-settlement-frequency-value'),
  musicToggle: () => getElementById('music-toggle'),
  musicVolume: () => getElementById('music-volume'),
  musicNowPlaying: () => getElementById('music-now-playing'),
  musicToggleGame: () => getElementById('music-toggle-game'),
  musicVolumeGame: () => getElementById('music-volume-game'),
  musicNowPlayingGame: () => getElementById('music-now-playing-game'),
  sfxToggle: () => getElementById('sfx-toggle'),
  sfxVolume: () => getElementById('sfx-volume'),
  audioElement: () => getElementById('background-music'),
  structureAmbienceAudio: () => getElementById('structure-ambience'),
  worldInfoModal: () => getElementById('world-info'),
  worldInfoForm: () => getElementById('world-info-form'),
  worldInfoSize: () => getElementById('world-info-size'),
  worldInfoGenerationType: () => getElementById('world-info-generation-type'),
  worldInfoSeed: () => getElementById('world-info-seed'),
  worldInfoChronology: () => getElementById('world-info-chronology'),
  worldYearInput: () => getElementById('world-year-input'),
  worldAgeInput: () => getElementById('world-age-input'),
  worldChronologyRandom: () => getElementById('world-chronology-random'),
  worldInfoGenerationTypeSelect: () => getElementById('world-generation-type-select'),
  worldNameInput: () => getElementById('world-name-input'),
  worldNameRandom: () => getElementById('world-name-random'),
  worldInfoCancel: () => getElementById('world-info-cancel'),
  dwarfCustomizer: () => getElementById('dwarf-customizer'),
  dwarfCustomizerForm: () => getElementById('dwarf-customizer-form'),
  dwarfRosterList: () => getElementById('dwarf-roster-list'),
  dwarfPrev: () => getElementById('dwarf-prev'),
  dwarfNext: () => getElementById('dwarf-next'),
  dwarfSlotLabel: () => getElementById('dwarf-slot-label'),
  dwarfNameInput: () => getElementById('dwarf-name-input'),
  dwarfGenderButtons: () => getElementById('dwarf-gender-buttons'),
  dwarfClanSelect: () => getElementById('dwarf-clan-select'),
  dwarfProfessionSelect: () => getElementById('dwarf-profession-select'),
  dwarfSkinSlider: () => getElementById('dwarf-skin-slider'),
  dwarfSkinSliderValue: () => getElementById('dwarf-skin-slider-value'),
  dwarfEyeSlider: () => getElementById('dwarf-eye-slider'),
  dwarfEyeSliderValue: () => getElementById('dwarf-eye-slider-value'),
  dwarfHairStyleSlider: () => getElementById('dwarf-hair-style-slider'),
  dwarfHairStyleSliderValue: () => getElementById('dwarf-hair-style-slider-value'),
  dwarfHairSlider: () => getElementById('dwarf-hair-slider'),
  dwarfHairSliderValue: () => getElementById('dwarf-hair-slider-value'),
  dwarfBeardSlider: () => getElementById('dwarf-beard-slider'),
  dwarfBeardSliderValue: () => getElementById('dwarf-beard-slider-value'),
  dwarfBeardFieldGroup: () => getElementById('dwarf-beard-field-group'),
  dwarfRandomise: () => getElementById('dwarf-randomise'),
  dwarfBack: () => getElementById('dwarf-back'),
  dwarfPortrait: () => getElementById('dwarf-portrait'),
  dwarfPortraitCanvas: () => getElementById('dwarf-portrait-canvas'),
  dwarfBodyPortraitCanvas: () => getElementById('dwarf-body-portrait-canvas'),
  dwarfTraitSummary: () => getElementById('dwarf-trait-summary'),
  dwarfTraitAttributes: () => getElementById('dwarf-trait-attributes')
};

export const elements = {};

export function hydrateElements() {
  Object.entries(elementInitialisers).forEach(([key, initialise]) => {
    try {
      const value = initialise();
      if (value === undefined) {
        elements[key] = key === 'structureDetailsTabs' ? [] : null;
      } else {
        elements[key] = value;
      }
    } catch (error) {
      elements[key] = key === 'structureDetailsTabs' ? [] : null;
    }
  });
  return elements;
}

hydrateElements();

export function getMusicToggleElements() {
  return [elements.musicToggle, elements.musicToggleGame].filter(Boolean);
}

export function getMusicVolumeInputs() {
  return [elements.musicVolume, elements.musicVolumeGame].filter(Boolean);
}

export function getMusicNowPlayingDisplays() {
  return [elements.musicNowPlaying, elements.musicNowPlayingGame].filter(Boolean);
}
