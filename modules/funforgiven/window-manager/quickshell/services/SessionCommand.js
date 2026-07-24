function text(value) {
    if (value === null || value === undefined) {
        return "";
    }
    return String(value).trim();
}

function sessionAction(executable, actionUnits, action) {
    var binary = text(executable);
    if (binary.length === 0) {
        throw new Error("systemctl executable is empty");
    }
    if (!binary.startsWith("/")) {
        throw new Error("systemctl executable must be absolute");
    }
    if (action !== "logout" && action !== "reboot" && action !== "poweroff") {
        throw new Error("unsupported system action: " + text(action));
    }

    if (actionUnits === null || typeof actionUnits !== "object") {
        throw new Error("session action unit map is missing");
    }

    var expectedUnit = "funforgiven-session-" + action + ".service";
    var unit = text(actionUnits[action]);
    if (unit !== expectedUnit) {
        throw new Error("invalid session action unit for " + action);
    }

    return [binary, "--user", "start", unit];
}

if (typeof module !== "undefined" && module.exports) {
    module.exports = {
        sessionAction: sessionAction
    };
}
