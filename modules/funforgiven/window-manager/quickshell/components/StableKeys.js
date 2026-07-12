function text(value) {
    return value === null || value === undefined ? "" : String(value);
}

function project(values, keyFor) {
    values = Array.isArray(values) ? values : [];
    var keys = [];
    var seen = Object.create(null);
    for (var index = 0; index < values.length; index += 1) {
        var key = text(keyFor(values[index], index));
        if (key.length === 0)
            throw new Error("stable model key is empty at index " + index);
        if (seen[key])
            throw new Error("duplicate stable model key: " + key);
        seen[key] = true;
        keys.push(key);
    }
    return keys;
}

function same(left, right) {
    if (!Array.isArray(left) || !Array.isArray(right) || left.length !== right.length)
        return false;
    for (var index = 0; index < left.length; index += 1) {
        if (String(left[index]) !== String(right[index]))
            return false;
    }
    return true;
}

function reconcile(previous, values, keyFor) {
    var next = project(values, keyFor);
    return same(previous, next) ? previous : next;
}

function find(values, key, keyFor) {
    values = Array.isArray(values) ? values : [];
    var wanted = text(key);
    for (var index = 0; index < values.length; index += 1) {
        if (text(keyFor(values[index], index)) === wanted)
            return values[index];
    }
    return null;
}

if (typeof module !== "undefined" && module.exports) {
    module.exports = {
        find: find,
        project: project,
        reconcile: reconcile,
        same: same
    };
}
