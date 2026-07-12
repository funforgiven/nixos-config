function text(value) {
    if (value === null || value === undefined) {
        return "";
    }
    return String(value).trim();
}

function systemctl(executable, action) {
    var binary = text(executable);
    if (binary.length === 0) {
        throw new Error("systemctl executable is empty");
    }
    if (!binary.startsWith("/")) {
        throw new Error("systemctl executable must be absolute");
    }
    if (action !== "reboot" && action !== "poweroff") {
        throw new Error("unsupported system action: " + text(action));
    }

    return [binary, "--check-inhibitors=yes", action];
}

if (typeof module !== "undefined" && module.exports) {
    module.exports = {
        systemctl: systemctl
    };
}
