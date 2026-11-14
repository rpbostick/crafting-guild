import denyGuard from "./deny-guard.js";
import runEvents from "./run-events.js";

// V2 loads a configured plugin path as one module (its index.js), so a builder's two plugins share this one
// definition: each setup is called with the same context and their cleanups are released together.
export default {
  id: "cg.builder-plugins",
  async setup(ctx) {
    const cleanups = [];
    for (const plugin of [denyGuard, runEvents]) {
      const cleanup = await plugin.setup(ctx);
      if (typeof cleanup === "function") cleanups.push(cleanup);
    }
    return () => {
      for (const cleanup of cleanups) cleanup();
    };
  },
};
