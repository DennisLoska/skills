---
name: codebase-design
description: Use when designing a module interface, building deep modules, finding deepening opportunities, deciding where a seam goes, making code testable, or needing architecture vocabulary.
---

# Codebase Design

Design **deep modules**: much behavior behind a small interface, placed at a clean seam, testable through that interface. Aim: leverage for callers, locality for maintainers, testability for everyone.

## Glossary

Use these terms exactly when discussing module interfaces in this skill. No substitutes: never "component", "service", "API", or "boundary" for Module, Interface, or Seam. Other skills may use ordinary words.

- **Module:** anything with an interface and an implementation. Scale-agnostic: function, class, package, or tier-spanning slice.
- **Interface:** everything a caller must know: signature plus invariants, ordering constraints, error modes, config, performance. More than the type surface.
- **Implementation:** what is inside the module. Distinct from Adapter: a small adapter can wrap a large implementation (Postgres repo) and vice versa (in-memory fake).
- **Depth:** leverage at the interface. Behavior per unit of interface learned. **Deep** is much behavior behind a small interface; **shallow** is an interface nearly as complex as its body.
- **Seam:** where you can alter behavior without editing in place; the location of a module's interface. Placing the seam is its own decision.
- **Adapter:** the concrete thing satisfying an interface at a seam. Names a role, not substance.
- **Leverage:** what callers get from depth. One implementation pays back across N call sites and M tests.
- **Locality:** what maintainers get from depth. Change, bugs, and verification concentrate in one place. Fix once, fixed everywhere.

## Deep versus shallow

Deep: small interface, large hidden body.

```
+-------------------+
|  Small Interface  |  <- few methods, simple params
+-------------------+
|                   |
| Deep Impl         |  <- complexity hidden inside
|                   |
+-------------------+
```

Shallow (avoid): large interface, thin pass-through body.

```
+-----------------------------------+
|  Large Interface  |  <- many methods, complex params
+-----------------------------------+
|  Thin Impl        |  <- just passes through
+-----------------------------------+
```

Ask: fewer methods? Simpler params? More complexity hidden inside?

## Principles

- **Depth is an interface property.** Internals may be small, mockable, swappable parts; they stay out of the interface. Internal seams are private; the external seam is the interface.
- **The deletion test.** Delete the module in your head. Complexity vanishes: pass-through, cut it. Complexity reappears across N callers: it earns its keep.
- **The interface is the test surface.** Callers and tests cross the same seam. Testing past the interface means the shape is wrong.
- **One adapter is a hypothetical seam; two make it real.** No variation across the seam, no seam.

## Design for testability

1. **Accept dependencies, never create them.** Inject the gateway; do not `new` it inside.
2. **Return results, avoid side effects.** Return the Discount; do not mutate the cart.
3. **Keep a small surface.** Fewer methods, fewer tests. Fewer params, simpler setup.

## Going deeper

- Dependencies and seam discipline: [DEEPENING.md](./DEEPENING.md).
- Alternative interfaces via parallel drafts: [DESIGN-IT-TWICE.md](./DESIGN-IT-TWICE.md).

Adapted from mattpocock/skills (MIT).
