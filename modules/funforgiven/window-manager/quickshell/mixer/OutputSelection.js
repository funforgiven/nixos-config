function text(value) {
    return value === null || value === undefined ? "" : String(value);
}

function outputKey(output) {
    if (!output || output.id === null || output.id === undefined || output.serial === null || output.serial === undefined)
        return "";
    return JSON.stringify([text(output.id), text(output.serial)]);
}

function indexForKey(outputs, key) {
    if (!Array.isArray(outputs) || key === "")
        return -1;
    for (var index = 0; index < outputs.length; index += 1) {
        if (outputKey(outputs[index]) === key)
            return index;
    }
    return -1;
}

function fallbackIndex(outputs, currentOutput) {
    if (!Array.isArray(outputs) || outputs.length === 0)
        return -1;

    var currentIndex = indexForKey(outputs, outputKey(currentOutput));
    if (currentIndex >= 0)
        return currentIndex;

    for (var index = 0; index < outputs.length; index += 1) {
        if (outputs[index] && outputs[index].available === true)
            return index;
    }
    return 0;
}

function selectionAt(outputs, index, rehomed) {
    if (!Array.isArray(outputs) || index < 0 || index >= outputs.length) {
        return {
            index: -1,
            key: "",
            rehomed: rehomed === true
        };
    }
    return {
        index: index,
        key: outputKey(outputs[index]),
        rehomed: rehomed === true
    };
}

function initialSelection(outputs, currentOutput) {
    return selectionAt(outputs, fallbackIndex(outputs, currentOutput), false);
}

function reconcileSelection(outputs, rememberedKey, currentOutput) {
    rememberedKey = text(rememberedKey);
    var rememberedIndex = indexForKey(outputs, rememberedKey);
    if (rememberedIndex >= 0)
        return selectionAt(outputs, rememberedIndex, false);
    return selectionAt(outputs, fallbackIndex(outputs, currentOutput), true);
}

if (typeof module !== "undefined" && module.exports) {
    module.exports = {
        fallbackIndex: fallbackIndex,
        indexForKey: indexForKey,
        initialSelection: initialSelection,
        outputKey: outputKey,
        reconcileSelection: reconcileSelection
    };
}
