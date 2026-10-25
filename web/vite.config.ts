import react from "@vitejs/plugin-react";
import { defineConfig } from "vitest/config";

// The console talks to the Rails API on the same origin: proxied in development, served from
// Rails' public/ in production (the Dockerfile builds it there).
export default defineConfig({
  plugins: [react()],
  server: { port: 5173, proxy: { "/api": process.env.API_URL ?? "http://localhost:3000" } },
  build: { outDir: "dist", sourcemap: false },
  test: { environment: "jsdom", globals: true, setupFiles: ["./src/test/setup.ts"], css: { modules: { classNameStrategy: "non-scoped" } } },
});
