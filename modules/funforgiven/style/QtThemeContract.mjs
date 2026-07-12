import fs from "node:fs";

const [materialPath, qtctPath, kdePath, kvantumConfigPath, kvantumSvgPath] = process.argv.slice(2);
if (!kvantumSvgPath) {
    throw new Error("usage: QtThemeContract.mjs MATERIAL QTCT KDE KVCONFIG KVSVG");
}

const materialDocument = JSON.parse(fs.readFileSync(materialPath, "utf8"));
const material = Object.fromEntries(Object.entries(materialDocument.colors)
    .map(([name, variants]) => [name, variants.dark.toLowerCase()]));
const qtct = parseIni(fs.readFileSync(qtctPath, "utf8"));
const kde = parseIni(fs.readFileSync(kdePath, "utf8"));
const kvantum = parseIni(fs.readFileSync(kvantumConfigPath, "utf8"));
const kvantumSvg = fs.readFileSync(kvantumSvgPath, "utf8");
const failures = [];

function parseIni(source) {
    const result = Object.create(null);
    let section = "";

    for (const rawLine of source.split("\n")) {
        const line = rawLine.trim();
        if (line === "" || line.startsWith("#") || line.startsWith(";"))
            continue;
        if (line.startsWith("[") && line.endsWith("]")) {
            section = line.slice(1, -1);
            result[section] ??= Object.create(null);
            continue;
        }

        const separator = line.indexOf("=");
        if (separator < 1 || section === "")
            continue;
        result[section][line.slice(0, separator)] = line.slice(separator + 1);
    }

    return result;
}

function expect(actual, expected, label) {
    if (actual?.toLowerCase() !== expected?.toLowerCase())
        failures.push(`${label}: got ${actual ?? "missing"}, expected ${expected}`);
}

function rgb(hex) {
    return hex.slice(1).match(/../g).map(component => Number.parseInt(component, 16) / 255);
}

function csv(hex) {
    return hex.slice(1).match(/../g).map(component => Number.parseInt(component, 16)).join(",");
}

function luminance(hex) {
    const components = rgb(hex).map(component => component <= 0.04045
        ? component / 12.92
        : ((component + 0.055) / 1.055) ** 2.4);
    return 0.2126 * components[0] + 0.7152 * components[1] + 0.0722 * components[2];
}

function contrast(foreground, background) {
    const first = luminance(foreground);
    const second = luminance(background);
    return (Math.max(first, second) + 0.05) / (Math.min(first, second) + 0.05);
}

function expectContrast(foreground, background, label) {
    const ratio = contrast(foreground, background);
    if (ratio < 4.5)
        failures.push(`${label} contrast is ${ratio.toFixed(2)}:1, expected at least 4.5:1`);
}

const active = qtct.ColorScheme?.active_colors?.split(",").map(color => color.trim()) ?? [];
if (active.length !== 22)
    failures.push(`qtct active palette has ${active.length} roles, expected 22`);
else {
    const qtMappings = new Map([
        [0, "on_surface"],
        [6, "on_surface"],
        [9, "surface"],
        [10, "surface"],
        [12, "primary"],
        [13, "on_primary"],
        [18, "surface_container_high"],
        [19, "on_surface"],
        [20, "on_surface_variant"],
        [21, "primary"]
    ]);
    for (const [index, role] of qtMappings)
        expect(active[index], material[role], `qtct role ${index}/${role}`);

    expectContrast(active[6], active[9], "qtct Text/Base");
    expectContrast(active[0], active[10], "qtct WindowText/Window");
    expectContrast(active[13], active[12], "qtct HighlightedText/Highlight");
    expectContrast(active[19], active[18], "qtct ToolTipText/ToolTipBase");
}

const kdeMappings = [
    ["Colors:View", "ForegroundNormal", "on_surface"],
    ["Colors:View", "BackgroundNormal", "surface"],
    ["Colors:Window", "ForegroundNormal", "on_surface"],
    ["Colors:Window", "BackgroundNormal", "surface"],
    ["Colors:Header][Inactive", "ForegroundNormal", "on_surface"],
    ["Colors:Header][Inactive", "BackgroundNormal", "surface"],
    ["Colors:Selection", "ForegroundNormal", "on_primary"],
    ["Colors:Selection", "BackgroundNormal", "primary"]
];
for (const [section, key, role] of kdeMappings)
    expect(kde[section]?.[key], csv(material[role]), `KColorScheme ${section}/${key}`);

expectContrast(material.on_surface, material.surface, "KColorScheme View text/background");
expectContrast(material.on_primary, material.primary, "KColorScheme selected text/background");

expect(kvantum.ItemView?.["text.press.color"], material.surface, "Kvantum pressed ItemView text");
expect(kvantum.ItemView?.["text.toggle.color"], material.surface, "Kvantum toggled ItemView text");

for (const state of ["pressed", "toggled"]) {
    const match = kvantumSvg.match(new RegExp(`id="itemview-${state}"[^>]*style="[^"]*fill:(#[0-9a-fA-F]{6})`));
    if (!match) {
        failures.push(`Kvantum ${state} ItemView fill is missing`);
        continue;
    }
    expect(match[1], material.on_surface_variant, `Kvantum ${state} ItemView fill`);
    expectContrast(material.surface, match[1], `Kvantum ${state} ItemView text/fill`);
}

if (failures.length > 0)
    throw new Error(failures.join("\n"));
