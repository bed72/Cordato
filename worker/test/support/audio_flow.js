const fs = require("node:fs");
const path = require("node:path");
const vm = require("node:vm");
const { randomBytes } = require("node:crypto");

const functionIds = Object.freeze({
    receive: "c0da700000000102",
    authenticated: "c0da700000000104",
    interpreted: "c0da700000000106",
    persisted: "c0da700000000108",
    caught: "c0da700000000112",
    audit: "c0da700000000113",
});

function loadAudioFlow() {
    return JSON.parse(fs.readFileSync(path.join(__dirname, "../../flows/audio/flows.json"), "utf8"));
}

function compileAudioFlow(nodes = loadAudioFlow(), context) {
    const functions = {};
    for (const [name, id] of Object.entries(functionIds)) {
        const node = nodes.find(entry => entry.id === id);
        if (!node || node.type !== "function") {
            throw new Error("Missing audio function: " + name);
        }
        const execute = vm.compileFunction(node.func, ["msg", "env", "node", "RED", "require", "module", "process", "global"], { parsingContext: context });
        functions[name] = (msg, dependency) => execute(
            msg,
            name === "audit" ? undefined : dependency,
            name === "audit" ? dependency : undefined,
            { util: { generateId: () => randomBytes(8).toString("hex") } },
        );
    }
    return functions;
}

module.exports = Object.freeze({ loadAudioFlow, compileAudioFlow, functionIds });
