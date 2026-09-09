// Test plugin for MiMoCode
export default {
  id: "test-plugin",
  tui: async (api, options) => {
    const { kv } = api;
    const logger = await import("./lib/logger.js").then(m => m.createLogger(api.client)).catch(() => ({ log: () => {} }));
    console.log("TEST PLUGIN: tui called");
    logger?.log?.("plugin", "TEST PLUGIN: Initializing", "debug");
  },
};
