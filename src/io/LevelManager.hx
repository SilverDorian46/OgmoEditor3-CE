package io;

import level.editor.CelesteBackdropPreview;
import electron.Shell;
import util.Popup;
import js.node.Fs;
import js.node.Path;
import js.html.Exception;
import level.data.Level;

class LevelManager
{
	public var levels:Array<Level> = [];

	public function new () {}

	public function create(?onSuccess:Level->Void, ?earlyCallback:Level->Void):Void
	{
		//Okay enforce the limit and create a new one
		this.enforceLimit(function ()
		{
			EDITOR.levelManager.forceCreate(onSuccess, earlyCallback);
		});
	}

	public function loadLevel(onSuccess: Level -> Void) {
		// If no level in cache...
		forceCreate(onSuccess);
	}

	public function forceCreate(onSuccess: Level -> Void, ?earlyCallback: Level -> Void): Void
	{
		var level = new Level(OGMO.project);
		level.unsavedID = OGMO.project.getNextUnsavedLevelID();
		if (earlyCallback != null) earlyCallback(level);
		EDITOR.levelManager.levels.push(level);
		EDITOR.levelsPanel.refresh();
		EDITOR.setLevel(level, () -> { if (onSuccess != null) onSuccess(level); });
	}

	public function open(path:String, ?onSuccess:Level->Void, ?onError:String->Void):Void
	{
		this.trim();

		//Check if the level is already open
		var level = this.get(path);

		if (level != null)
		{
			this.moveToFront(level);
			EDITOR.setLevel(level, () ->
			{
				if (onSuccess != null)
					onSuccess(level);

				if (level.externallyModified)
					this.resolveModifiedLevel(level);
			});

			return;
		}

		//If the file doesn't exist, quit
		if (!FileSystem.exists(path))
			return;

		//Check if you can open it
		this.enforceLimit(function ()
		{
			//Open it
			try
			{
				level = Imports.level(path);
			}
			catch (e:Dynamic)
			{
				trace(e.stack);
				if (onError != null)
					onError(e.stack);
				return;
			}

			this.levels.push(level);
			EDITOR.setLevel(level, () -> { if (onSuccess != null) onSuccess(level); });
		});
	}

	public function close(level:Level, ?onSuccess: Void->Void):Void
	{
		EDITOR.setLevel(level, () ->
		{
			level.attemptClose(function ()
			{
				EDITOR.levelManager.forceClose(level, onSuccess);
			});
		});
	}

	public function forceClose(level: Level, onSuccess: Void -> Void):Void
	{
		var n = EDITOR.levelManager.levels.indexOf(level);
		if (n >= 0) EDITOR.levelManager.levels.splice(n, 1);

		if (EDITOR.currentLevel == level && EDITOR.levelManager.levels.length != 0)
			EDITOR.setLevel(EDITOR.levelManager.levels[EDITOR.levelManager.levels.length - 1], onSuccess);
		else
			EDITOR.setLevel(null, onSuccess);
	}

	public function closeAll(?onSuccess: Void->Void):Void
	{
		//First close all levels with unsaved changes
		for (level in EDITOR.levelManager.levels)
		{
			if (level.unsavedChanges)
			{
				EDITOR.levelManager.close(level, function ()
				{
					EDITOR.levelManager.closeAll(onSuccess);
				});
				return;
			}
		}

		//Now close the rest
		function recursiveClose()
		{
			if (EDITOR.levelManager.levels.length > 0)
				EDITOR.levelManager.forceClose(EDITOR.levelManager.levels[0], recursiveClose);
			else if (onSuccess != null)
				onSuccess();
		}

		recursiveClose();
	}

	public function get(path:String): Level
	{
		for (level in levels)
			if (level.managerPath == path)
				return level;

		return null;
	}

	public function moveToFront(level: Level):Void
	{
		this.levels.splice(this.levels.indexOf(level), 1);
		this.levels.push(level);
	}

	public function clear():Void
	{
		this.levels.resize(0);
	}

	public function isOpen(path:String):Bool
	{
		return this.get(path) != null;
	}

	public function getDisplayName(path:String):String
	{
		var level = this.get(path);
		if (level != null)
			return level.displayName;
		else
			return Path.basename(path);
	}

	public function delete(path:String):Void
	{
		var level = this.get(path);
		if (level != null)
		{
			EDITOR.onLevelDeleted(level);
			this.forceClose(level, () -> Shell.moveItemToTrash(path));
			return;
		}

		Shell.moveItemToTrash(path);
	}

	public function getUnsavedLevels(): Array<Level>
	{
		var levels: Array<Level> = [];

		for (level in this.levels)
			if (level.path == null)
				levels.push(level);

		return levels;
	}

	function trim():Void
	{
		if (EDITOR.isEditingMap)
			return;

		/*
			Levels are safe to close if they don't have unsaved changes
			or anything on their undo/redo stacks
		*/

		var i = 0;
		while (i < levels.length)
		{
			if (levels[i].safeToClose)
			{
				levels.splice(i, 1);
				i--;
			}
			i++;
		}
	}

	function savedTrim():Bool
	{
		/*
			Close the first level without unsaved changes
		*/

		for (level in levels)
		{
			if (!level.unsavedChanges)
			{
				levels.remove(level);
				return true;
			}
		}

		return false;
	}

	function enforceLimit(onSuccess:Void->Void):Void
	{
		if (EDITOR.isEditingMap)
		{
			onSuccess();
			return;
		}

		//First do a safe-to-close trim
		EDITOR.levelManager.trim();

		//Now try removing levels that don't have unsaved changes
		var trim = true;
		while (trim && EDITOR.levelManager.levels.length >= OGMO.settings.openLevelLimit)
			trim = EDITOR.levelManager.savedTrim();

		//Now we're forced to ask to close levels
		if (EDITOR.levelManager.levels.length >= OGMO.settings.openLevelLimit)
		{
			EDITOR.levelManager.close(EDITOR.levelManager.levels[0], function ()
			{
				EDITOR.levelManager.enforceLimit(onSuccess);
			});
		}
		else
			onSuccess();
	}

	function updateOpenLevelsFromEditor(): Void
	{
		for (mapLevel in EDITOR.levelMap)
			if (!levels.contains(mapLevel))
				levels.push(mapLevel);
	}

	/*
			FOCUS
	*/

	function resolveModifiedLevel(level: Level):Void
	{
		Popup.open("Level File Modified", "warning", "<span class='monospace'>" + level.displayNameNoStar + "</span> was modified externally!", ["Reload", "Keep Mine"], function (i)
		{
			if (i == 0)
			{
				Imports.levelInto(level.path, level);
				level.unsavedChanges = false;
				EDITOR.dirty();
			}
			else
				level.unsavedChanges = true;

			EDITOR.levelsPanel.refreshLabelsAndIcons();
			OGMO.updateWindowTitle();
		});
	}

	public function onGainFocus():Void
	{
		var level = EDITOR.currentLevel;
		if (level != null)
		{
			if (level.externallyDeleted)
			{
				level.deleted = true;
				level.unsavedChanges = true;
			}
			else if (level.externallyModified)
				this.resolveModifiedLevel(level);
		}

		if (EDITOR.backdropPreview != null)
		{
			if (EDITOR.backdropPreview.externallyDeleted)
			{
				EDITOR.backdropPreview = null;
				EDITOR.dirty();
			}
			else if (EDITOR.backdropPreview.externallyModified)
			{
				EDITOR.backdropPreview = CelesteBackdropPreview.loadFromPath(EDITOR.backdropPreview.path);
				EDITOR.dirty();
			}
		}
	}

	/*
		FILE OPS
	*/

	public function onFolderDelete(dir:String, onSuccess:Void->Void):Void
	{
		var toClose: Array<Level> = [];
		for (level in levels)
			if (level.path != null && level.path.indexOf(dir) == 0)
				toClose.push(level);

		function recursiveClose()
		{
			if (toClose.length > 0)
				this.forceClose(toClose.pop(), recursiveClose);
			else if (onSuccess != null)
				onSuccess();
		}

		recursiveClose();
	}

	public function onFolderRename(oldPath:String, newPath:String, onSuccess:Void->Void):Void
	{
		for (level in levels)
			if (level.path != null && level.path.indexOf(oldPath) == 0)
				level.path = newPath + level.path.substr(oldPath.length);

		if (EDITOR.mapDirectory == oldPath) EDITOR.loadLevelMap(newPath, onSuccess);
		else if (onSuccess != null) onSuccess();
	}

	public function onLevelRename(oldPath:String, newPath:String):Void
	{
		for (level in levels)
		{
			if (level.path == oldPath)
			{
				level.path = newPath;
				return;
			}
		}
	}

	/*
		DEBUG
	*/

	public function log():Void
	{
		if (levels.length == 0) trace("No levels are open!");
		else
		{
			trace("Open Levels:");
			for (level in levels)
			{
				if (level.path == null) trace("Unsaved Level");
				else trace(level.path);
			}
		}
	}
}
