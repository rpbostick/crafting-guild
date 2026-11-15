import coldStart from "./cold-start-2x.js";
import replyLog from "./reply-log-2x.js";

// V2 loads a configured plugin path as one module, its index.js, so the session names this directory and gets both
// plugins through this one definition: each setup sees the same context. Only the reply log returns a cleanup, which
// is released here; cold-start registers its hooks and returns none.
export default {
  id: "cg.orchestrator-plugins",
  async setup(ctx) {
    const cleanups = [];
    for (const plugin of [coldStart, replyLog]) {
      const cleanup = await plugin.setup(ctx);
      if (typeof cleanup === "function") cleanups.push(cleanup);
    }
    return () => {
      for (const cleanup of cleanups) cleanup();
    };
  },
};
