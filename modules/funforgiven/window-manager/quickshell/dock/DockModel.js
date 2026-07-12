function key(group) {
    return group && group.key !== null && group.key !== undefined ? String(group.key) : "";
}

function compareGroupKey(left, right) {
    var leftKey = key(left);
    var rightKey = key(right);
    return leftKey < rightKey ? -1 : (leftKey > rightKey ? 1 : 0);
}

function orderUnpinned(groups) {
    return (Array.isArray(groups) ? groups.slice() : []).sort(compareGroupKey);
}

if (typeof module !== "undefined" && module.exports) {
    module.exports = {
        compareGroupKey: compareGroupKey,
        orderUnpinned: orderUnpinned
    };
}
