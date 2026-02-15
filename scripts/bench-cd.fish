#!/usr/bin/env fish
# Benchmark cd performance: times N alternating cd calls across a project boundary.
# Usage: fish scripts/bench-cd.fish [iterations]
#        fish scripts/bench-cd.fish 20 /project/a /project/b
#
# Reports per-cd median and P95 in milliseconds.
# Run inside a live Fish shell (not fish -c) for realistic hook timing.

set -l iterations (math (string match -r '\d+' -- "$argv[1]"; or echo 10))
set -l dir_a (test -n "$argv[2]"; and echo "$argv[2]"; or echo "$HOME")
set -l dir_b (test -n "$argv[3]"; and echo "$argv[3]"; or echo /tmp)

if not test -d "$dir_a"
    echo "error: $dir_a is not a directory" >&2
    exit 1
end
if not test -d "$dir_b"
    echo "error: $dir_b is not a directory" >&2
    exit 1
end

echo "Benchmarking cd: $iterations iterations between"
echo "  A: $dir_a"
echo "  B: $dir_b"
echo ""

set -l times

# Warm up caches (first cd is always slower due to init guards)
builtin cd "$dir_a" 2>/dev/null
builtin cd "$dir_b" 2>/dev/null
builtin cd "$dir_a" 2>/dev/null

for i in (seq $iterations)
    set -l start (date +%s%3N)
    cd "$dir_b"
    set -l mid (date +%s%3N)
    cd "$dir_a"
    set -l end_time (date +%s%3N)

    set -l t1 (math "$mid - $start")
    set -l t2 (math "$end_time - $mid")
    set -a times $t1
    set -a times $t2
end

# Sort times for percentile calculation
set -l sorted (printf '%s\n' $times | sort -n)
set -l count (count $sorted)
set -l median_idx (math "ceil($count / 2)")
set -l p95_idx (math "ceil($count * 0.95)")
set -l sum 0
for t in $sorted
    set sum (math "$sum + $t")
end
set -l avg (math "$sum / $count")

echo "Results ($count cd calls):"
echo "  Median: $sorted[$median_idx] ms"
echo "  P95:    $sorted[$p95_idx] ms"
echo "  Mean:   $avg ms"
echo "  Min:    $sorted[1] ms"
echo "  Max:    $sorted[$count] ms"
echo ""
echo "All times (ms): $sorted"
