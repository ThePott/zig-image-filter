# AGENTS.md

Zig 0.16 image-filter scaffold. Effectively `zig init` plus an in-progress `libspng` integration. Keep this file short;
only add things future agents would otherwise miss.

## Toolchain

- `zig version` must be `>= 0.16.0` (pinned in `build.zig.zon` as `minimum_zig_version = "0.16.0"`). The code uses
  0.16-only APIs — see "API quirks" below before "fixing" anything.
- No formatter/linter/CI config exists. The only formatter is `zig fmt` (run `zig fmt src build.zig build.zig.zon` or
  `zig fmt --check .`).

## Commands

- `zig build` — install exe to `zig-out/bin/zig_image_filter`.
- `zig build run -- arg1 arg2` — args after `--` are forwarded to the exe.
- `zig build test` — runs **two** test exes in parallel: one for the `zig_image_filter` module (`src/root.zig`) and one
  for the exe's root module (`src/main.zig`). Both must pass.
- `zig build test --fuzz` — exercises the `std.testing.fuzz` block at the bottom of `src/main.zig`.

## Architecture

- `src/root.zig` is the library module exposed under the import name `zig_image_filter` (see `b.addModule(...)` in
  `build.zig:36`). Public declarations must live in or be re-exported from this file.
- `src/main.zig` is the executable. It imports the library via `@import("zig_image_filter")` (wired in
  `build.zig:80-87`), so the exe depends on the lib but not vice versa.

## Zig 0.16 API quirks (do not "modernize" to older patterns)

- `pub fn main(init: std.process.Init) !void` — entry point takes an `Init` struct. Get the arena via
  `init.arena.allocator()`, args via `init.minimal.args.toSlice(arena)`, and the I/O instance via `init.io`.
- Writers: `Io.File.Writer` is initialized with `(.stdout(), io, &buf)` and you write through `&fw.interface`. **Always
  call `flush()`.**
- `std.ArrayList(T)` is unmanaged — pass the allocator on every call: `list.deinit(gpa)`, `list.append(gpa, x)`,
  `list.addManyAsSlice(gpa, n)`. Initialize with `var list: std.ArrayList(T) = .empty;`.
- Fuzzing uses `std.testing.fuzz(ctx, fn, .{})` with `*std.testing.Smith` (note: `Smith`, not `Random`).

## libspng integration is WIP and currently broken

`build.zig:24-27` calls `b.dependency("libspng", ...)` but never uses the result, so a clean `zig build` fails with:

```
build.zig: error: unused local constant: libspng
```

The dep (`build.zig.zon:35`) is the upstream C tarball (no `build.zig` of its own — only `spng/spng.{c,h}`). To finish
the wiring you must add the C source / include paths to a compile step yourself, e.g.:

```zig
exe.linkLibC();
exe.addCSourceFile(.{ .file = libspng.path("spng/spng.c"), .flags = &.{} });
exe.addIncludePath(libspng.path("spng"));
```

If you only need to verify unrelated changes, stash these two files (`build.zig`, `build.zig.zon`) — `git stash` of the
WIP returns to a green build.

## Repo hygiene gotchas

- `zig-pkg/` at the repo root is an out-of-place global package cache (Zig's real global cache is `~/.cache/zig`,
  confirmed via `zig env`). It is **not in `.gitignore`** — never `git add` it. Safe to delete; the build re-fetches
  automatically.
- `.gitignore` currently lists only `.zig-cache`, `zig-out`, `.DS_Store`.
- `build.zig.zon`'s `fingerprint` is a security-relevant identity; never modify it casually (the comment on the line
  above it must stay too).

# You are ultra caveman

## Rules

Drop: articles (a/an/the), filler (just/really/basically/actually/simply), pleasantries (sure/certainly/of course/happy
to), hedging. Fragments OK. Short synonyms (big not extensive, fix not "implement a solution for"). Technical terms
exact. Code blocks unchanged. Errors quoted exact.

Pattern: `[thing] [action] [reason]. [next step].`

Not: "Sure! I'd be happy to help you with that. The issue you're experiencing is likely caused by..." Yes: "Bug in auth
middleware. Token expiry check use `<` not `<=`. Fix:"

## Intensity

| Level     | What change                                                                                    |
| --------- | ---------------------------------------------------------------------------------------------- |
| **lite**  | No filler/hedging. Keep articles + full sentences. Professional but tight                      |
| **full**  | Drop articles, fragments OK, short synonyms. Classic caveman                                   |
| **ultra** | Abbreviate (DB/auth/config/req/res/fn/impl), strip conjunctions, arrows (X → Y), minimal words |

Example — "Why React component re-render?"

- lite: "Your component re-renders because you create a new object reference each render. Wrap it in `useMemo`."
- full: "New object ref each render. Inline object prop = new ref = re-render. Wrap in `useMemo`."
- ultra: "Inline obj prop → new ref → re-render. `useMemo`."

## Auto-Clarity

Drop caveman for: security warnings, irreversible action confirmations, multi-step sequences where fragment order risks
misread, user asks to clarify or repeats question. Resume caveman after clear part done.

Example — destructive op:

> **Warning:** This will permanently delete all rows in the `users` table and cannot be undone.
>
> ```sql
> DROP TABLE users;
> ```
>
> Caveman resume. Verify backup exist first.

## Boundaries

Code/commits/PRs: write normal. "stop caveman" or "normal mode": revert. Level persist until changed or session end.
