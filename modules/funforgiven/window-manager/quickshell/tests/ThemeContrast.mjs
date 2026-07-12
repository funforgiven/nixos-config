import fs from "node:fs";
import path from "node:path";

const shellRoot = process.argv[2];
const materialPalettePath = process.argv[3];
if (!shellRoot || !materialPalettePath) {
    throw new Error("usage: ThemeContrast.mjs SHELL_CONFIG MATERIAL_PALETTE");
}

const themePath = path.join(shellRoot, "generated", "Theme.qml");
const theme = fs.readFileSync(themePath, "utf8");
const materialDocument = JSON.parse(fs.readFileSync(materialPalettePath, "utf8"));
const material = Object.fromEntries(Object.entries(materialDocument.colors)
    .map(([name, variants]) => [name, variants.dark]));
const colors = Object.create(null);
const numbers = Object.create(null);

for (const match of theme.matchAll(/readonly property color\s+([A-Za-z][A-Za-z0-9]*):\s*["'](#[0-9A-Fa-f]{6})["']/g)) {
    colors[match[1]] = match[2];
}
for (const match of theme.matchAll(/readonly property (?:int|real)\s+([A-Za-z][A-Za-z0-9]*):\s*([0-9]+(?:\.[0-9]+)?)/g)) {
    numbers[match[1]] = Number(match[2]);
}

function rgb(hex) {
    return hex.slice(1).match(/../g).map(component => Number.parseInt(component, 16) / 255);
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

function hue(hex) {
    const [red, green, blue] = rgb(hex);
    const maximum = Math.max(red, green, blue);
    const minimum = Math.min(red, green, blue);
    const delta = maximum - minimum;
    if (delta === 0)
        return 0;

    let sector;
    if (maximum === red)
        sector = ((green - blue) / delta) % 6;
    else if (maximum === green)
        sector = (blue - red) / delta + 2;
    else
        sector = (red - green) / delta + 4;
    return (sector * 60 + 360) % 360;
}

function hueDistance(first, second) {
    const distance = Math.abs(first - second) % 360;
    return Math.min(distance, 360 - distance);
}

const failures = [];
const materialMappings = {
    baseSurface: "surface",
    elevatedSurface: "surface_container_low",
    raisedSurface: "surface_container",
    hoverSurface: "surface_container_high",
    pressedSurface: "surface_container_highest",
    selectedSurface: "primary_container",
    primaryText: "on_surface",
    secondaryText: "on_surface_variant",
    tertiaryText: "outline",
    disabledText: "outline_variant",
    outline: "outline_variant",
    outlineStrong: "outline",
    error: "error",
    errorText: "on_error_container",
    errorSurface: "error_container",
    warning: "primary",
    warningText: "on_primary_container",
    warningSurface: "primary_container",
    systemAccent: "primary",
    accentText: "on_primary"
};
for (const [token, role] of Object.entries(materialMappings)) {
    if (!material[role]) {
        failures.push(`Matugen output is missing ${role}`);
    } else if (colors[token]?.toLowerCase() !== material[role].toLowerCase()) {
        failures.push(`Theme.${token} must map directly to Matugen ${role}`);
    }
}

const textRoles = ["primaryText", "secondaryText", "tertiaryText", "errorText", "warningText", "successText"];
const surfaces = ["baseSurface", "elevatedSurface", "raisedSurface"];
const tonalLadder = [...surfaces, "hoverSurface", "pressedSurface"];
const semantics = ["error", "warning", "success"];
const channelAccents = ["systemAccent", "gameAccent", "voiceAccent", "musicAccent"];
const accents = [...semantics, ...channelAccents];
const supportingColors = [
    "selectedSurface",
    "outline",
    "outlineStrong",
    "border",
    "disabledText",
    "errorSurface",
    "warningSurface",
    "successSurface",
    "accentText"
];

for (const name of [...textRoles, ...tonalLadder, ...accents, ...supportingColors]) {
    if (!colors[name]) {
        failures.push(`Theme.${name} is not a literal generated color token`);
    }
}

for (const foreground of textRoles) {
    for (const background of surfaces) {
        if (!colors[foreground] || !colors[background])
            continue;
        const ratio = contrast(colors[foreground], colors[background]);
        if (ratio < 4.5)
            failures.push(`${foreground}/${background} contrast is ${ratio.toFixed(2)}:1, expected at least 4.5:1`);
    }
}

for (const foreground of ["primaryText", "secondaryText"]) {
    for (const background of ["selectedSurface", "hoverSurface", "pressedSurface"]) {
        if (!colors[foreground] || !colors[background])
            continue;
        const ratio = contrast(colors[foreground], colors[background]);
        if (ratio < 4.5)
            failures.push(`${foreground}/${background} contrast is ${ratio.toFixed(2)}:1, expected at least 4.5:1`);
    }
}

for (const semantic of semantics) {
    const foreground = `${semantic}Text`;
    const background = `${semantic}Surface`;
    if (!colors[foreground] || !colors[background])
        continue;
    const ratio = contrast(colors[foreground], colors[background]);
    if (ratio < 4.5)
        failures.push(`${foreground}/${background} contrast is ${ratio.toFixed(2)}:1, expected at least 4.5:1`);
}

for (const background of accents) {
    if (!colors.accentText || !colors[background])
        continue;
    const ratio = contrast(colors.accentText, colors[background]);
    if (ratio < 4.5)
        failures.push(`accentText/${background} contrast is ${ratio.toFixed(2)}:1, expected at least 4.5:1`);
}

for (let index = 1; index < tonalLadder.length; index += 1) {
    const previous = tonalLadder[index - 1];
    const current = tonalLadder[index];
    if (!colors[previous] || !colors[current])
        continue;
    if (luminance(colors[current]) <= luminance(colors[previous]))
        failures.push(`${current} must be lighter than ${previous}`);
    if (hueDistance(hue(colors.baseSurface), hue(colors[current])) > 5)
        failures.push(`${current} must remain within the Material surface hue family`);
}

if (colors.baseSurface && colors.pressedSurface) {
    const ratio = contrast(colors.baseSurface, colors.pressedSurface);
    if (ratio > 1.75)
        failures.push(`tonal surface ladder spans ${ratio.toFixed(2)}:1, expected at most 1.75:1`);
}

if (colors.outline && colors.outlineStrong && colors.baseSurface) {
    const outlineRatio = contrast(colors.outline, colors.baseSurface);
    const strongRatio = contrast(colors.outlineStrong, colors.baseSurface);
    if (outlineRatio < 1.5 || outlineRatio > 2.5)
        failures.push(`outline/baseSurface contrast is ${outlineRatio.toFixed(2)}:1, expected 1.5-2.5:1`);
    if (strongRatio <= outlineRatio || strongRatio > 7.5)
        failures.push(`outlineStrong/baseSurface contrast is ${strongRatio.toFixed(2)}:1, expected above outline and at most 7.5:1`);
}

if (colors.outline && colors.elevatedSurface) {
    const trackRatio = contrast(colors.outline, colors.elevatedSurface);
    if (trackRatio < 1.5)
        failures.push(`outline/elevatedSurface slider-track contrast is ${trackRatio.toFixed(2)}:1, expected at least 1.5:1`);
}
for (const accent of channelAccents) {
    if (!colors[accent] || !colors.outline)
        continue;
    const ratio = contrast(colors[accent], colors.outline);
    if (ratio < 3)
        failures.push(`${accent}/outline slider-fill contrast is ${ratio.toFixed(2)}:1, expected at least 3:1`);
}

if (colors.primaryText && colors.secondaryText && colors.tertiaryText && colors.disabledText) {
    const hierarchy = ["primaryText", "secondaryText", "tertiaryText", "disabledText"];
    for (let index = 1; index < hierarchy.length; index += 1) {
        if (luminance(colors[hierarchy[index]]) >= luminance(colors[hierarchy[index - 1]]))
            failures.push(`${hierarchy[index]} must be visibly quieter than ${hierarchy[index - 1]}`);
    }
}

const aliases = [
    ["border", "outline"]
];
for (const [alias, source] of aliases) {
    if (colors[alias] && colors[source] && colors[alias].toLowerCase() !== colors[source].toLowerCase())
        failures.push(`${alias} must remain a compatibility alias of ${source}`);
}

const semanticHueRanges = {
    error: [[340, 360], [0, 20]],
    warning: [[25, 55]],
    success: [[130, 175]]
};
for (const [name, ranges] of Object.entries(semanticHueRanges)) {
    if (!colors[name])
        continue;
    const actual = hue(colors[name]);
    if (!ranges.some(([minimum, maximum]) => actual >= minimum && actual <= maximum))
        failures.push(`${name} hue is ${actual.toFixed(1)}°, expected ${ranges.map(range => range.join("-")).join("° or ")}°`);
}

for (let first = 0; first < channelAccents.length; first += 1) {
    for (let second = first + 1; second < channelAccents.length; second += 1) {
        if (!colors[channelAccents[first]] || !colors[channelAccents[second]])
            continue;
        const distance = hueDistance(hue(colors[channelAccents[first]]), hue(colors[channelAccents[second]]));
        if (distance < 45)
            failures.push(`${channelAccents[first]} and ${channelAccents[second]} are only ${distance.toFixed(1)}° apart`);
    }
}

const requiredNumbers = [
    "captionFontSize", "bodyFontSize", "labelFontSize", "titleFontSize", "displayFontSize",
    "radiusXSmall", "radiusSmall", "radiusMedium", "radiusLarge", "radiusPill",
    "spacingXSmall", "spacingSmall", "spacingMedium", "spacingLarge", "spacingXLarge",
    "controlCompactSize", "controlSize", "controlLargeSize",
    "iconSmallSize", "iconMediumSize", "iconLargeSize",
    "outlineWidth", "focusRingWidth",
    "animationFast", "animationNormal", "animationSlow",
    "subtleOverlayOpacity", "selectedOverlayOpacity", "pressedOverlayOpacity", "disabledOpacity",
    "pressedScale"
];
for (const name of requiredNumbers) {
    if (!Number.isFinite(numbers[name]))
        failures.push(`Theme.${name} is not a literal generated numeric token`);
}

function strictlyAscending(names) {
    for (let index = 1; index < names.length; index += 1) {
        if (Number.isFinite(numbers[names[index - 1]]) && Number.isFinite(numbers[names[index]])
                && numbers[names[index]] <= numbers[names[index - 1]]) {
            failures.push(`${names.join(" < ")} must be strictly ascending`);
            return;
        }
    }
}

strictlyAscending(["captionFontSize", "bodyFontSize", "titleFontSize", "displayFontSize"]);
strictlyAscending(["radiusXSmall", "radiusSmall", "radiusMedium", "radiusLarge", "radiusPill"]);
strictlyAscending(["spacingXSmall", "spacingSmall", "spacingMedium", "spacingLarge", "spacingXLarge"]);
strictlyAscending(["controlCompactSize", "controlSize", "controlLargeSize"]);
strictlyAscending(["iconSmallSize", "iconMediumSize", "iconLargeSize"]);
strictlyAscending(["animationFast", "animationNormal", "animationSlow"]);

if (numbers.captionFontSize < 11 || numbers.bodyFontSize < 12 || numbers.labelFontSize < 12)
    failures.push("caption/body/label font tokens must not recreate sub-11px metadata");
if (numbers.controlCompactSize < 36 || numbers.controlSize < 40 || numbers.controlLargeSize < 44)
    failures.push("control tokens must preserve 36/40/44px minimum targets");
if (numbers.animationSlow > 300)
    failures.push("ordinary shell motion must remain at or below 300ms");
if (!(numbers.subtleOverlayOpacity > 0 && numbers.subtleOverlayOpacity < numbers.selectedOverlayOpacity
        && numbers.selectedOverlayOpacity < numbers.pressedOverlayOpacity
        && numbers.pressedOverlayOpacity < numbers.disabledOpacity && numbers.disabledOpacity < 1)) {
    failures.push("subtle/selected/pressed/disabled opacity tokens must be ordered within 0-1");
}
if (!(numbers.pressedScale >= 0.9 && numbers.pressedScale < 1))
    failures.push("pressedScale must provide a restrained 0.9-1.0 press response");

function matchingBrace(source, opening) {
    let depth = 0;
    let quote = "";
    let lineComment = false;
    let blockComment = false;
    let escaped = false;

    for (let index = opening; index < source.length; index += 1) {
        const character = source[index];
        const next = source[index + 1] || "";

        if (lineComment) {
            if (character === "\n")
                lineComment = false;
            continue;
        }
        if (blockComment) {
            if (character === "*" && next === "/") {
                blockComment = false;
                index += 1;
            }
            continue;
        }
        if (quote) {
            if (escaped) {
                escaped = false;
            } else if (character === "\\") {
                escaped = true;
            } else if (character === quote) {
                quote = "";
            }
            continue;
        }
        if (character === "/" && next === "/") {
            lineComment = true;
            index += 1;
            continue;
        }
        if (character === "/" && next === "*") {
            blockComment = true;
            index += 1;
            continue;
        }
        if (character === '"' || character === "'" || character === "`") {
            quote = character;
            continue;
        }
        if (character === "{")
            depth += 1;
        else if (character === "}" && --depth === 0)
            return index;
    }
    return -1;
}

function qmlFiles(directory) {
    return fs.readdirSync(directory, { withFileTypes: true }).flatMap(entry => {
        const candidate = path.join(directory, entry.name);
        if (entry.isDirectory()) {
            return ["fixtures", "test", "testdata", "tests"].includes(entry.name)
                ? []
                : qmlFiles(candidate);
        }
        return entry.isFile() && entry.name.endsWith(".qml") ? [candidate] : [];
    });
}

const unsafeTextColor = /\b(?:Shell\.Theme\.(?:error|warning|success|systemAccent|gameAccent|voiceAccent|musicAccent)|root\.accent)\b/;
for (const file of qmlFiles(shellRoot)) {
    const source = fs.readFileSync(file, "utf8");
    const textBlock = /\bText\s*\{/g;
    for (let match = textBlock.exec(source); match; match = textBlock.exec(source)) {
        const opening = source.indexOf("{", match.index);
        const closing = matchingBrace(source, opening);
        if (closing < 0) {
            failures.push(`${path.relative(shellRoot, file)} has an unterminated Text block`);
            break;
        }
        const block = source.slice(opening + 1, closing);
        const color = block.match(/(?:^|\n)\s*color\s*:\s*([^\n;]+)/);
        if (color && unsafeTextColor.test(color[1])) {
            const line = source.slice(0, opening).split("\n").length;
            failures.push(`${path.relative(shellRoot, file)}:${line} uses a decorative accent as text color: ${color[1].trim()}`);
        }
        textBlock.lastIndex = closing + 1;
    }
}

if (failures.length > 0) {
    throw new Error(`Theme contrast contract failed:\n- ${failures.join("\n- ")}`);
}

console.log("Theme contrast contract passed");
