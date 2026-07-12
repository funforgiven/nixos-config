function screenName(screen) {
    if (screen === null || screen === undefined || typeof screen.name !== "string") {
        return "";
    }
    return screen.name;
}

function screenForName(screens, name) {
    if (!screens || typeof screens.length !== "number" || typeof name !== "string") {
        return null;
    }

    for (var index = 0; index < screens.length; index += 1) {
        if (screenName(screens[index]) === name) {
            return screens[index];
        }
    }
    return null;
}

function firstScreen(screens) {
    if (!screens || typeof screens.length !== "number") {
        return null;
    }

    for (var index = 0; index < screens.length; index += 1) {
        if (screenName(screens[index]).length > 0) {
            return screens[index];
        }
    }
    return null;
}

function focusedScreen(workspaces, screens) {
    var focusedOutput = "";
    var focusedCount = 0;

    if (Array.isArray(workspaces)) {
        for (var index = 0; index < workspaces.length; index += 1) {
            var workspace = workspaces[index];
            if (workspace
                && workspace.is_focused === true
                && typeof workspace.output === "string"
                && workspace.output.length > 0
                && screenForName(screens, workspace.output) !== null) {
                focusedOutput = workspace.output;
                focusedCount += 1;
            }
        }
    }

    if (focusedCount === 1) {
        return screenForName(screens, focusedOutput);
    }
    return firstScreen(screens);
}

if (typeof module !== "undefined" && module.exports) {
    module.exports = {
        firstScreen: firstScreen,
        focusedScreen: focusedScreen,
        screenForName: screenForName
    };
}
