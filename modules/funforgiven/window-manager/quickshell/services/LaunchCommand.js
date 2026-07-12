function text(value) {
    if (value === null || value === undefined) {
        return "";
    }
    return String(value).trim();
}

function desktopEntryId(value) {
    var id = text(value);
    if (id.length === 0) {
        throw new Error("desktop entry ID is empty");
    }
    return id.endsWith(".desktop") ? id : id + ".desktop";
}

function app2unitService(launcher, id) {
    return [
        text(launcher),
        "-t",
        "service",
        "-s",
        "app-graphical.slice",
        "--",
        desktopEntryId(id)
    ];
}

if (typeof module !== "undefined" && module.exports) {
    module.exports = {
        app2unitService: app2unitService,
        desktopEntryId: desktopEntryId
    };
}
