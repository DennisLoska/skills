# Deepening

How to deepen a cluster of shallow modules safely, given its dependencies. Assumes the [SKILL.md](./SKILL.md) vocabulary: Module, Interface, Seam, Adapter.

## Dependency categories

Classify before deepening. The category sets how the deepened module is tested.

1. **In-process.** Pure computation, in-memory state, no I/O. Always deepenable: merge and test through the new interface directly. No adapter needed.
2. **Local-substitutable.** A local stand-in exists (PGLite for Postgres, in-memory filesystem). Deepenable if the stand-in exists; the seam stays internal, no port on the external interface.
3. **Remote but owned.** Your services across a network line. Define a port at the seam: logic stays in the deep module, transport is an injected adapter. Tests use in-memory, production uses HTTP/gRPC/queue.
4. **True external.** Third-party services you do not control. Inject the dependency as a port; tests supply a mock adapter.

## Seam discipline

- **One adapter is hypothetical; two make it real.** No port without at least two justified adapters (usually production plus test). A single-adapter seam is indirection.
- **Internal versus external seams.** Internal seams serve the module's own tests and stay private. Never expose them through the interface.

## Testing strategy: replace, do not layer

- Delete old unit tests on the shallow modules once interface tests exist.
- Write new tests at the deepened interface. The interface is the test surface.
- Assert observable outcomes through the interface, never internal state.
- Tests must survive internal refactors. A test that breaks on an internal change tests past the interface.

Adapted from mattpocock/skills (MIT).
