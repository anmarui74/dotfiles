"use strict";

class Provider extends AI.Provider {
    constructor() {
        super("OpenCode Local", "http://localhost:4001", "lm-studio", "v1");
    }
}
