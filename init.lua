--- === SpaceMan ===
---
--- TODO: Write overview
local SpaceMan = {}
SpaceMan.__index = SpaceMan

-- Metadata
SpaceMan.name = "SpaceMan"
SpaceMan.version = "1.0.0"
SpaceMan.author = "Adam Miller <adam@adammiller.io>"
SpaceMan.homepage = "https://github.com/adammillerio/SpaceMan.spoon"
SpaceMan.license = "MIT - https://opensource.org/licenses/MIT"

-- Dependency Spoons
-- WindowCache is used for quick retrieval of windows when restoring/hiding.
WindowCache = spoon.WindowCache

--- SpaceMan.defaultHotkeys
--- Variable
--- Default hotkey to use for the space chooser,
--- when "hotkeys" = "default".
SpaceMan.defaultHotkeys = {space_chooser = {{"ctrl"}, "space"}}

--- SpaceMan.settingsKey
--- Constant
--- Key used for persisting space names between Hammerspoon launches via hs.settings.
SpaceMan.settingsKey = "SpaceManSpaces"

--- SpaceMan.focusedSettingsKey
--- Constant
--- Key used for persisting the currently focused space between Hammerspoon launches
--- via hs.settings
SpaceMan.focusedSettingsKey = "SpaceManFocusedSpace"

--- SpaceMan.menuBarAutosaveName
--- Constant
--- Autosave name used with macOS to save menu bar item position.
SpaceMan.menuBarAutosaveName = "SpaceManMenuBar"

--- SpaceMan.logger
--- Variable
--- Logger object used within the Spoon. Can be accessed to set the default log 
--- level for the messages coming from the Spoon.
SpaceMan.logger = nil

--- SpaceMan.logLevel
--- Variable
--- Spacer specific log level override, see hs.logger.setLogLevel for options.
SpaceMan.logLevel = nil

--- SpaceMan.menuBar
--- Variable
--- hs.menubar representing the menu bar for SpaceMan.
SpaceMan.menuBar = nil

--- SpaceMan.orderedSpaces
--- Variable
--- Table holding an ordered list of space IDs, which is used for positional
--- Space-control commands (ie move left/right).
SpaceMan.orderedSpaces = nil

SpaceMan.virtualSpaces = nil

--- SpaceMan.currentlyFocusedSpace
--- Variable
--- int with the position of the currently focused space.
SpaceMan.currentlyFocusedSpace = nil

SpaceMan.windowSpaceMap = nil

SpaceMan.spaceWindows = nil

SpaceMan.hiddenWindowPositions = nil

SpaceMan.windowCache = nil

--- SpaceMan.spaceChooser
--- Variable
--- hs.chooser object representing the Space chooser.
SpaceMan.spaceChooser = nil

SpaceMan.moveWindowToSpace = function(window, spaceID, force)
    return SpaceMan:moveWindowToVirtualSpace(window, spaceID)
end

SpaceMan.focusedSpace = function() return SpaceMan.currentlyFocusedSpace end

SpaceMan.spaceType = function(spaceID) return "user" end

function SpaceMan:getVirtualSpacesForWindow(window)
    local windowID = nil
    if type(window) == "number" then
        windowID = window
    else
        windowID = window:id()
    end

    local windowSpaceIDs = self.windowSpaceMap[windowID]
    if not windowSpaceIDs then return nil end

    local spaceIDs = {}
    for spaceID in pairs(windowSpaceIDs) do table.insert(spaceIDs, spaceID) end

    return spaceIDs
end

SpaceMan.windowSpaces = function(window)
    return SpaceMan:getVirtualSpacesForWindow(window)
end

function SpaceMan:moveWindowToVirtualSpace(window, spaceID)
    self:removeWindowFromVirtualSpace(window, spaceID)
    return self:addWindowToVirtualSpace(window, spaceID)
end

function SpaceMan:addWindowToVirtualSpace(window, spaceID)
    if not spaceID then spaceID = self.currentlyFocusedSpace end

    local windowID = nil
    if type(window) == "number" then
        window = WindowCache:getWindowByID(window)
    end

    windowID = window:id()

    local windowSpaceIDs = self.windowSpaceMap[windowID]
    if not windowSpaceIDs then
        windowSpaceIDs = {}
        self.windowSpaceMap[windowID] = windowSpaceIDs
    end

    windowSpaceIDs[spaceID] = true

    local spaceWindows = self.spaceWindows[spaceID]
    if not spaceWindows then
        spaceWindows = {}
        self.spaceWindows[spaceID] = spaceWindows
    end

    spaceWindows[windowID] = window

    return self:getVirtualSpacesForWindow(windowID)
end

function SpaceMan:removeWindowFromVirtualSpace(window, spaceID, destroyed)
    local windowID = nil
    if type(window) == "number" then
        windowID = window
    else
        windowID = window:id()
    end

    local spaceWindows = self.spaceWindows[spaceID]
    if not spaceWindows then
        self.logger.ef("Space with ID %s does not exist", spaceID)
        return
    end

    spaceWindows[windowID] = nil

    local windowSpaceIDs = self.windowSpaceMap[windowID]
    if not windowSpaceIDs then return end

    windowSpaceIDs[spaceID] = nil
    if next(windowSpaceIDs) == nil then
        if destroyed then
            -- Window is destroyed, remove space map entirely.
            self.windowSpaceMap[windowID] = nil
        else
            -- If this was the last Space the window was in, assign it to the current
            -- one.
            self.logger.vf(
                "Window %s belongs to no spaces, adding to currently focused space",
                windowID)
            self:addWindowToVirtualSpace(windowID)
        end
    end
end

function SpaceMan:hideSpace(spaceID)
    local spaceWindows = self.spaceWindows[spaceID]
    if not spaceWindows then
        self.logger.ef("Space with ID %s does not exist", spaceID)
        return
    end

    for _, window in pairs(spaceWindows) do self:hideWindow(window) end
end

function SpaceMan:restoreSpace(spaceID)
    local spaceWindows = self.spaceWindows[spaceID]
    if not spaceWindows then
        self.logger.ef("Space with ID %s does not exist", spaceID)
        return
    end

    for _, window in pairs(spaceWindows) do self:restoreWindow(window) end
end

function SpaceMan:goToSpace(spaceID)
    self:hideSpace(self.currentlyFocusedSpace)
    self:restoreSpace(spaceID)

    self.currentlyFocusedSpace = spaceID
end

function SpaceMan:hideWindow(window)
    if type(window) == "number" then
        window = WindowCache:getWindowByID(window)
    end

    local windowID = window:id()

    if self.hiddenWindowPositions[windowID] then
        self.logger.vf("Window %d is already hidden", windowID)
        return
    end

    self.logger.vf("Hiding window with ID %d", windowID)

    local windowFrame = window:frame()

    local screenFrame = hs.screen.mainScreen():fullFrame()
    local hiddenWindowFrame = hs.geometry.rect(screenFrame.w, screenFrame.h,
                                               windowFrame.w, windowFrame.h)

    window:move(hiddenWindowFrame, nil, nil, 0)

    self.hiddenWindowPositions[windowID] = windowFrame
end

function SpaceMan:restoreWindow(window)
    if type(window) == "number" then
        window = WindowCache:getWindowByID(window)
    end

    local windowID = window:id()

    local restoredWindowFrame = self.hiddenWindowPositions[windowID]
    if not restoredWindowFrame then
        self.logger.vf("Window %d is not hidden", windowID)
    end

    self.logger.vf("Restoring window with ID %d", windowID)

    window:move(restoredWindowFrame, nil, nil, 0)

    self.hiddenWindowPositions[windowID] = nil
end

-- Set the menu text of the Spacer menu bar item.
function SpaceMan:_setMenuText()
    self.menuBar:setTitle(self.currentlyFocusedSpace)
end

-- Handler for user clicking one of the SpaceMan menu bar menu items.
-- Inputs are the space ID, a table of modifiers and their state upon selection,
-- and the menuItem table.
function SpaceMan:_menuItemClicked(spacePos, spaceID, modifiers, menuItem)
    if modifiers['alt'] then
        -- Alt held, enter user space rename mode.
        _, inputSpaceName = hs.dialog.textPrompt("Input Space Name",
                                                 "Enter New Space Name")

        -- Rename space and update menu text.
        self:renameVirtualSpace(spaceID, inputSpaceName)
        self:_setMenuText()
    elseif modifiers["ctrl"] then
        self:removeVirtualSpace(spaceID)
    else
        if spacePos ~= self.currentlyFocusedSpace then
            -- Go to the selected space if it is not the current one.
            self:goToSpace(spaceID)
            self:_setMenuText()
        end
    end
end

function SpaceMan:_menuItemAdd()
    _, inputSpaceID = hs.dialog.textPrompt("Input Space ID",
                                           "Enter New Space ID")

    self:createVirtualSpace(inputSpaceID)
end

-- Utility method for having instance specific callbacks.
-- Inputs are the callback fn and any arguments to be applied after the instance
-- reference.
function SpaceMan:_instanceCallback(callback, ...)
    return hs.fnutils.partial(callback, self, ...)
end

function SpaceMan:createVirtualSpace(spaceID, skipWrite)
    -- Basically table.insert(self.orderedSpaces, spaceID), retaining the new index.
    local idx = #self.orderedSpaces + 1
    self.orderedSpaces[idx] = spaceID

    -- Store the ordered position of the space.
    self.virtualSpaces[spaceID] = idx

    if not skipWrite then self:_writeSpaceNames() end
end

function SpaceMan:renameVirtualSpace(spaceID, newSpaceID)
    local spacePos = self.virtualSpaces[spaceID]
    if not spacePos then
        self.logger.ef("Space with ID %s does not exist", spaceID)
        return
    end

    if self.virtualSpaces[newSpaceID] then
        self.logger.ef("Space with ID %s already exists", newSpaceID)
        return
    end

    -- Rename: Ordered space names
    self.orderedSpaces[spacePos] = newSpaceID

    -- Rename: Ordinal positions
    self.virtualSpaces[spaceID] = nil
    self.virtualSpaces[newSpaceID] = spacePos

    -- Rename: Currently focused space if this is it.
    if self.currentlyFocusedSpace == spaceID then
        self.currentlyFocusedSpace = newSpaceID
        self:_writeFocusedSpace()
    end

    -- Rename: Space -> Window collection.
    local spaceWindows = self.spaceWindows[spaceID]
    self.spaceWindows[spaceID] = nil
    self.spaceWindows[newSpaceID] = spaceWindows

    -- Rename: Window -> Space mappings.
    for window in pairs(spaceWindows) do
        local windowSpaces = self.windowSpaceMap[window]

        windowSpaces[spaceID] = nil
        windowSpaces[newSpaceID] = true
    end

    self:_writeSpaceNames()
end

function SpaceMan:removeVirtualSpace(spaceID)
    local spacePos = self.virtualSpaces[spaceID]
    if not spacePos then
        self.logger.ef("Space with ID %s does not exist", spaceID)
        return
    end

    if self.currentlyFocusedSpace == spaceID then
        self.logger.ef("Cannot remove currently focused space %s", spaceID)
        return
    end

    self.virtualSpaces[spaceID] = nil
    -- Remove and renumber ordered spaces.
    table.remove(self.orderedSpaces, spacePos)
    for i, spaceID in pairs(self.orderedSpaces) do
        self.virtualSpaces[spaceID] = i
    end

    local spaceWindows = self.spaceWindows[spaceID]
    self.spaceWindows[windowID] = nil

    for window in pairs(spaceWindows) do
        local windowSpaces = self.windowSpaceMap[window]

        windowSpaces[spaceID] = nil

        if next(windowSpaces) == nil then
            -- Window removed from last space, snap to the current space.
            self:addWindowToVirtualSpace(window)
        end
    end
end

-- Handler for creating the SpaceMan menu bar menu.
function SpaceMan:_menuHandler()
    -- Create table of menu items
    menuItems = {}

    -- Iterate through the ordered space IDs from left to right.
    for i, spaceID in ipairs(self.orderedSpaces) do
        menuItem = {}

        -- Set callback to handler for space being clicked.
        menuItem["fn"] = self:_instanceCallback(self._menuItemClicked, i,
                                                spaceID)

        -- Set menu item to the ID (name) of the Space.
        menuItem["title"] = spaceID

        table.insert(menuItems, menuItem)
    end

    addMenuItem = {}
    addMenuItem["fn"] = self:_instanceCallback(self._menuItemAdd)
    addMenuItem["title"] = "Add"
    table.insert(menuItems, addMenuItem)

    return menuItems
end

-- Rename a space, updating both the positional and by-ID value, and writing
-- back to hs.settings.
function SpaceMan:_renameSpace(spacePos, name)
    local existingName = self.orderedSpaces[spacePos]
    self.virtualSpaces[existingName] = nil

    self.orderedSpaces[spacePos] = name
    self.virtualSpaces[name] = true

    self:_writeSpaceNames()
end

-- Persist the current ordered set of space IDs back to hs.settings.
function SpaceMan:_writeSpaceNames()
    self.logger.vf("Writing space IDs to hs.settings at %s: %s",
                   self.settingsKey, hs.inspect(self.orderedSpaces))
    hs.settings.set(self.settingsKey, self.orderedSpaces)
end

-- Persist the currently focused space name back to hs.settings.
function SpaceMan:_writeFocusedSpace()
    self.logger.vf(
        "Writing currently focused space name to hs.settings at %s: %s",
        self.focusedSettingsKey, hs.inspect(self.currentlyFocusedSpace))
    hs.settings.set(self.focusedSettingsKey, self.currentlyFocusedSpace)
end

-- Retrieve the "name" of a fullscreen space.
-- This trudges through the internal data_managedDisplaySpaces structure to locate
-- and set the name of a fullscreen space, which is the app name of the first
-- "tile" in a tiled space.
function SpaceMan:_getFullScreenSpaceName(spaceID)
    spaceData = hs.spaces.data_managedDisplaySpaces()

    screenUUID = hs.screen.mainScreen():getUUID()

    for _, displaySpaces in ipairs(spaceData) do
        -- Find spaces for this screen.
        if displaySpaces["Display Identifier"] == screenUUID then
            for _, space in ipairs(displaySpaces["Spaces"]) do
                -- Find the space with this ID.
                if space["ManagedSpaceID"] == spaceID then
                    -- Retrieve and return tiled app name.
                    return
                        space["TileLayoutManager"]["TileSpaces"][1]["appName"] ..
                            " (F)"
                end
            end
        end
    end

    -- Could not find name.
    return nil
end

-- Perform an initial load of all space IDs and names. This will retrieve the
-- previously persisted ordinal space names from settings, and then initialize
-- the current set of retrieved space IDs against it before storing it in the
-- orderedSpaces and orderedSpaceNames tables respectively. This is intended to
-- be called once on startup, and then _reloadSpaceNames is used to reconcile
-- the in-memory state during Spacer related events.
function SpaceMan:_loadSpaceNames()
    self.logger.vf("Loading spaces from hs.settings key \"%s\"",
                   self.settingsKey)

    -- Load the persisted space names from the previous session if any.
    local orderedSpaces = hs.settings.get(self.settingsKey)

    if not orderedSpaces then
        -- Default to empty table.
        self.logger.v("No saved space names, initializing empty table")
        orderedSpaces = {"None"}
    end

    for _, spaceID in ipairs(orderedSpaces) do
        self:createVirtualSpace(spaceID, true)
    end

    self.logger.vf("Loaded space names: %s", hs.inspect(self.orderedSpaces))
end

function SpaceMan:_loadFocusedSpace()
    self.logger.vf("Loading focused space from hs.settings key \"%s\"",
                   self.focusedSettingsKey)

    -- Load the persisted space names from the previous session if any.
    self.currentlyFocusedSpace = hs.settings.get(self.focusedSettingsKey)

    if self.currentlyFocusedSpace == nil then
        -- Default to first Space.

        self.logger.v("No saved focused space, defaulting to first space")
        self.currentlyFocusedSpace = self.orderedSpaces[1]
    end

    self.logger.vf("Loaded currently focused space: %s",
                   hs.inspect(self.currentlyFocusedSpace))
end

-- Choice generator for Spacer Chooser.
function SpaceMan:_spaceChooserChoices()
    choices = {}

    --  Create a table of all space names in order from left-to-right.
    for i, spaceID in ipairs(self.orderedSpaces) do
        table.insert(choices, {
            text = spaceID,
            subText = nil,
            image = nil,
            valid = true,
            spaceID = spaceID
        })
    end

    return choices;
end

-- Completion function for space chooser, which switches to the selected space
-- unless it is the current one or nil.
-- Input is the table representing the choice from the Chooser.
function SpaceMan:_spaceChooserCompletion(choice)
    if choice == nil then
        self.logger.vf("No choice made, skipping")
        return
    elseif choice.spaceID == self.currentlyFocusedSpace then
        self.logger.vf("Choice is currently focused space, skipping")
        return
    end

    -- Go to the selected space.
    self:goToSpace(choice.spaceID)
end

-- Spacer space chooser.
-- Reloads spaces, then shows a Spotlight-like completion menu on screen for
-- selecting a space either by it's position, or by it's name.
function SpaceMan:_showSpaceChooser()
    if not self.spaceChooser:isVisible() then
        -- Update row count, clear previous input, refresh choices, and show chooser.
        self.spaceChooser:rows(#self.orderedSpaces)
        self.spaceChooser:query(nil)
        self.spaceChooser:refreshChoicesCallback()
        self.spaceChooser:show()
    else
        -- Hotkey pressed again while chooser is visible, so hide it. Mostly
        -- replicating Spotlight behavior.
        self.spaceChooser:hide()
    end
end

--- Spacer:init()
--- Method
--- Spoon initializer method for Spacer.
---
--- Parameters:
---  * None
---
--- Returns:
---  * None
function SpaceMan:init()
    self.orderedSpaces = {}
    self.virtualSpaces = {}
    self.windowSpaceMap = {}
    self.spaceWindows = {}
    self.hiddenWindowPositions = {}
end

--- Spacer:start()
--- Method
--- Spoon start method for Spacer. Creates/starts menu bar item and space watcher.
---
--- Parameters:
---  * None
---
--- Returns:
---  * None
function SpaceMan:start()
    -- Start logger, this has to be done in start because it relies on config.
    self.logger = hs.logger.new("SpaceMan")

    if self.logLevel ~= nil then self.logger.setLogLevel(self.logLevel) end

    self.logger.v("Starting SpaceMan")

    -- Load initial space names from settings or initialize new set.
    self:_loadSpaceNames()

    -- Load the currently focused space, if any.
    self:_loadFocusedSpace()

    self.logger.v("Creating menubar item")
    self.menuBar = hs.menubar.new()
    self.menuBar:autosaveName(self.menuBarAutosaveName)
    self.menuBar:setMenu(self:_instanceCallback(self._menuHandler))

    -- Create space chooser.
    self.logger.v("Creating space chooser")
    self.spaceChooser = hs.chooser.new(self:_instanceCallback(
                                           self._spaceChooserCompletion))
    self.spaceChooser:choices(self:_instanceCallback(self._spaceChooserChoices))

    -- Perform an initial text set for the current space.
    self:_setMenuText()
end

--- Spacer:stop()
--- Method
--- Spoon stop method for Spacer. Deletes menu bar item and stops space watcher.
---
--- Parameters:
---  * None
---
--- Returns:
---  * None
function SpaceMan:stop()
    self.logger.v("Deleting menubar item")
    self.menuBar:delete()

    -- Write space names back to settings.
    self:_writeSpaceNames()

    -- Write the currently focused space back to settings.
    self:_writeFocusedSpace()

    self.logger.v("Deleting space chooser")
    self.spaceChooser:delete()
end

function SpaceMan:bindHotkeys(mapping)
    -- Bind method for showing the space chooser with the desired hotkey,
    hs.spoons.bindHotkeysToSpec({
        space_chooser = self:_instanceCallback(self._showSpaceChooser)
    }, mapping)
end

return SpaceMan
