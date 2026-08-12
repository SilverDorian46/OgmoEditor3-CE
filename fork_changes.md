## Changes in this fork of Ogmo Editor 3

### General
- refactored some code (by renaming fields, replacing methods...)
- fixed a few bugs

### Project settings
- General:
  - added "Def. Level Size" setting alongside the "Min. Level Size" and "Max. Level Size" settings
  - added "Screen Size" setting
- Layers:
  - add options to import or export layer templates
  - Grid Layer:
    - added "Overlaying Tile Layer" setting (see Autotiler)
    - added a setting for each grid characters to reference an autotiler definition (see Autotiler)
  - Decal Layer:
    - added "Colorable", "Include Alpha", and "Include #" settings
- Entities:
  - added "Colorable", "Include Alpha", and "Include #" settings colour
  - added "Minimum #" setting for node limits
  - added "Draw Points" setting for drawing nodes
- Tilesets:
  - added "Duplicate" option in the right-click menu on tileset definitions
- Autotiler (new):
  - implemented Autotiler panel for defining autotiler definitions
  - in the Editor, automatically generates a visual of tiles for grid layers where the autotiler definitions are referenced
  - when the grid layer's "Overlaying Tile Layer" value references a valid tile layer, then the generated tiles may be overlaid (i.e. replaced) by tiles from the referenced tile layer

### Value settings
- Color:
  - added "Include Alpha" and "Include #" settings, for whether to include the alpha (RRGGBB**AA**) and/or the starting hashtag (**#**RRGGBB)
- Float, Integer:
  - replaced "Clamp" setting with separate "Clamp Min" and "Clamp Max" settings
- String:
  - made "Trim Whitespace" and "Max Len." settings actually work

### Editor
- made camera and currently selected layer independent of level
- added a visual warning if a level's size is smaller than the project's "screen size" setting
- Level map (new):
  - added functionality for editing a level map (a collection of related levels in a folder)
  - added ability to reposition levels (changing their offset)
- Tools:
  - improved pixel snapping
  - Entity tools:
    - node selection now prioritises nodes over the root entity in case of overlap
  - Decal tools:
    - rotating decals should now snap the rotation value to the unit degree
- Celeste Backdrop Preview (new):
  - added functionality for previewing Celeste-style backdrops (available on .json files with a Style object)

### Level data
- Decals:
  - the texture path value should now be normalised (`\` replaced with `/`)

### Rendering
- added variable color to texture shader
- entity name and ID are now displayed alongside values on entity placements within the editor canvas
- Atlas and Subtextures (new):
  - implemented texture atlas (generated on loading the project) for better performance in the editor
  - replaced many textures with subtextures for use within the editor canvas
