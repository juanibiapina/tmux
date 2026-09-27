# Developing tmux in this checkout

## Start here

- Read `README` for dependencies and build instructions, `tmux.1` for user-visible behavior, and `.github/CONTRIBUTING.md` before preparing an issue or contribution.
- This checkout's `multi-side-panels` branch starts at PR #5468 (`ad40c090`), which adds the side status line. Keep tests and implementation decisions grounded in this branch's behavior.
- `options-table.c` defines public option types, defaults, and descriptions. `options.c` implements storage and change propagation. `status.c` renders client status areas; `resize.c`, `screen-redraw.c`, `tty.c`, `screen-write.c`, and `server-client.c` handle window geometry, drawing, and input coordinates. Check all of these when changing status area dimensions.

## Build on macOS

The following setup built this branch on Apple Silicon with AddressSanitizer and utf8proc:

```sh
brew install autoconf automake bison libevent ncurses pkg-config make utf8proc
sh autogen.sh
./configure --enable-asan --enable-utf8proc
gmake -j8
./tmux -V
```

`README` covers other platforms and a release tarball build. Homebrew installs GNU Make as `gmake`. Build outputs and generated Autotools files are ignored by Git.

## Run regressions

Run focused tests from the repository root:

```sh
gmake -C regress panels.sh side-status.sh side-status-refresh.sh screen-redraw-status.sh screen-redraw-floating.sh
```

Run the complete suite with `gmake -C regress -j8`. `regress/Makefile` runs each `*.sh` test with a minimal environment, reports results, and retains failure traces in `regress/logs/<test>.log`. It clears old traces at the start of each invocation, so inspect or save a failure log before running another test. Scene tests use an inner tmux attached through an outer tmux and compare captures with checked-in results. Their scripts document how to regenerate results; review any resulting changes.

On this macOS host, `screen-redraw-menus.sh` has failed at `menu-over-split` in parallel runs and passed when run alone. Inspect its failure log before rerunning it; the standalone pass does not establish why the parallel comparison differed.

## Isolate manual checks

Use the built binary with a distinct socket and an empty configuration, as described in `.github/CONTRIBUTING.md`:

```sh
./tmux -Lpanel-dev -f/dev/null new
```

Use the same `-L` name for subsequent commands and kill that server when finished. This keeps a local test away from the user's regular tmux server. Use `-v` or `-vv` to produce server, client, and terminal output logs when debugging.

## Status area changes

- PR #5468 adds `format_draw_lines`, `#[nl]`, row-aware style ranges, side status options, and `regress/side-status*.sh`. Preserve the existing horizontal status options and their behavior when extending the layout.
- The current side area has its own client screen and reserves columns; the horizontal status line remains full terminal width. Option changes invalidate scenes and refresh client status. The status timer also runs when only side status is enabled.
- Window sizing, direct tty output, cursor placement, mouse targeting, menus, and scene rendering have separate coordinate paths. Test both left/right and top/bottom status placement, narrow terminals, two client sizes, prompts, floating panes, and mouse interactions when changing geometry.
- Session array options replace the entire inherited array when overridden. Setting a single session entry does not merge it with global entries. `options_array_set` accepts string array values without scalar option validation; validate any new structured array values explicitly.

Keep changes to `tmux.1` aligned with the shipped options and add focused regression scenes or behavior tests for visible changes.
