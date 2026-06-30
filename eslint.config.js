export default [
  {
    ignores: ["_site/**", "node_modules/**", "**/*.min.js", "**/*.pkgd.*"],
  },
  {
    rules: {
      complexity: ["error", 4],
    },
  },
];
