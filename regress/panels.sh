#!/bin/sh

PATH=/bin:/usr/bin
TERM=screen
LC_ALL=C.UTF-8
export TERM LC_ALL

[ -z "$TEST_TMUX" ] && TEST_TMUX=$(readlink -f ../tmux)
OUTER="$TEST_TMUX -LpanelsA$$ -f/dev/null"
INNER="$TEST_TMUX -LpanelsB$$ -f/dev/null"
TMP=$(mktemp)
COUNT=$(mktemp)
trap 'rm -f "$TMP" "$COUNT"; $OUTER kill-server 2>/dev/null; $INNER kill-server 2>/dev/null' 0 1 15

fail() { echo "$*" >&2; exit 1; }
check() {
	$OUTER capturep -p >"$TMP" || fail "capture failed"
	if ! grep -q "$1" "$TMP"; then
		cat "$TMP" >&2
		fail "missing $1"
	fi
}

$OUTER new -d -x40 -y14 || exit 1
$OUTER set -g status off || exit 1
$INNER new -d -x40 -y14 "sh -c 'printf PANE; exec sleep 100'" || exit 1
$INNER set -g status off || exit 1
$INNER set -g panel-position[0] left || exit 1
$INNER set -g panel-size[0] 4 || exit 1
$INNER set -g panel-format[0] L0 || exit 1
$INNER set -g panel-position[1] left || exit 1
$INNER set -g panel-size[1] 4 || exit 1
$INNER set -g panel-format[1] L1 || exit 1
$INNER set -g panel-position[2] right || exit 1
$INNER set -g panel-size[2] 4 || exit 1
$INNER set -g panel-format[2] '#[range=user|foo]R0#[norange]' || exit 1
$INNER set -g panel-position[3] top || exit 1
$INNER set -g panel-size[3] 2 || exit 1
$INNER set -g panel-format[3] TOP || exit 1
$INNER set -g panel-position[4] bottom || exit 1
$INNER set -g panel-format[4] BOTTOM || exit 1
$OUTER send-keys "exec $TEST_TMUX -LpanelsB$$ -f/dev/null attach" Enter || exit 1
sleep 2
check TOP
check PANE
check L0
check L1
check R0
check BOTTOM
[ "$($INNER display -p '#{window_width}x#{window_height}')" = '28x11' ] ||
    fail "wrong window size"

$INNER set -g panel-enabled[1] off || exit 1
sleep 1
$OUTER capturep -p >"$TMP" || exit 1
if grep -q L1 "$TMP"; then fail "disabled panel still visible"; fi
[ "$($INNER display -p '#{window_width}')" = 32 ] || fail "toggle did not resize"
$INNER set -g panel-enabled[1] on || exit 1
sleep 1
check L1

$INNER set -g status on || exit 1
sleep 1
[ "$($INNER display -p '#{window_height}')" = 10 ] ||
    fail "status did not reserve a row"
check BOTTOM

$INNER set -g mouse on || exit 1
$INNER bind -n MouseDown1StatusDefault run-shell \
    "$INNER set -g @panel-hit '#{mouse_panel}:#{mouse_x}:#{mouse_y}'" || exit 1
seq=$(printf '\033[<0;1;3M\033[<0;1;3m')
$OUTER send-keys -l "$seq" || exit 1
sleep 1
[ "$($INNER show -gv @panel-hit)" = '0:0:0' ] ||
    fail "mouse did not hit first left panel"
$INNER bind -n MouseDown1Status run-shell \
    "$INNER set -g @panel-range '#{mouse_panel}:#{mouse_status_range}:#{mouse_x}'" || exit 1
seq=$(printf '\033[<0;38;3M\033[<0;38;3m')
$OUTER send-keys -l "$seq" || exit 1
sleep 1
[ "$($INNER show -gv @panel-range)" = '2:foo:1' ] ||
    fail "right panel range or coordinates were incorrect"

$INNER set -g panel-position[5] right || exit 1
$INNER set -g panel-size[5] 4 || exit 1
$INNER set -g panel-format[5] R1 || exit 1
$INNER set -g panel-position[6] top || exit 1
$INNER set -g panel-format[6] TOP2 || exit 1
$INNER set -g panel-position[7] bottom || exit 1
$INNER set -g panel-format[7] BOT2 || exit 1
sleep 1
check R1
check TOP2
check BOT2
[ "$($INNER display -p '#{window_width}x#{window_height}')" = '24x8' ] ||
    fail "multiple panels per edge did not resize the window"
$OUTER set -g window-size manual || exit 1
$OUTER resizew -x12 -y8 || exit 1
sleep 1
[ "$($INNER display -p '#{window_width}x#{window_height}')" = '4x2' ] ||
    fail "small client did not hide panels that exceed available space"
$OUTER resizew -x40 -y14 || exit 1
sleep 1
[ "$($INNER display -p '#{window_width}x#{window_height}')" = '24x8' ] ||
    fail "panels did not return when the terminal grew"
$INNER set -g side-status right || exit 1
sleep 1
[ "$($INNER display -p '#{window_width}')" = 10 ] ||
    fail "legacy side status did not share the panel layout"
$INNER set -g side-status off || exit 1
$INNER set -g status-position top || exit 1
sleep 1
$OUTER capturep -p >"$TMP" || exit 1
sed -n '2p' "$TMP" | grep -q TOP ||
    fail "top custom panel did not follow the top status line"
$INNER set -g status-position bottom || exit 1

if $INNER set -g panel-size[8] invalid 2>/dev/null; then
	fail "invalid size accepted"
fi
if $INNER set -g panel-position[nope] left 2>/dev/null; then
	fail "nonnumeric index accepted"
fi
if $INNER set -g panel-position[8] diagonal 2>/dev/null; then
	fail "invalid edge accepted"
fi
if $INNER set -g panel-position diagonal 2>/dev/null; then
	fail "invalid unindexed edge accepted"
fi
[ "$($INNER show -gv panel-position[0])" = left ] ||
    fail "invalid assignment removed existing panels"

$INNER set -g status off || exit 1
for index in 1 2 3 4 5 6 7; do
	$INNER set -g panel-enabled[$index] off || exit 1
done
$INNER set -g status-interval 1 || exit 1
$INNER set -g panel-format[0] "#(printf x >>$COUNT; printf TICK)" || exit 1
sleep 2
before=$(wc -c <"$COUNT")
sleep 3
after=$(wc -c <"$COUNT")
[ $((after - before)) -ge 2 ] || fail "panel did not refresh by itself"

exit 0
