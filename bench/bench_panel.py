"""Concurrency panel benchmark: the Python side of the comparison.

Runs the identical 8-indicator panel over the same 16 deterministic
series as bench/bench_panel.exs, three ways: sequentially, with a
thread pool (the GIL story) and with a process pool (the IPC story).
Workers rebuild their series from the seed and return a small summary,
so process IPC carries no arrays.

    python bench_panel.py [series-count]
"""

import math
import os
import statistics
import sys
import time
from concurrent.futures import ProcessPoolExecutor, ThreadPoolExecutor

import numpy as np
import talib

series_count = int(sys.argv[1]) if len(sys.argv) > 1 else 16
size = 100_000
idx = np.arange(size)


def make_series(s):
    return np.array(
        [100 + 50 * math.sin(i * 0.03 + s) + (i + s) % 13 * 0.7 + i * 0.001 for i in range(size)],
        dtype=np.double,
    )


def panel(prices):
    talib.SMA(prices, 20)
    talib.EMA(prices, 20)
    talib.RSI(prices, 14)
    talib.MACDFIX(prices, 9)
    talib.BBANDS(prices, 20, 2.0, 2.0)
    high = prices + 1 + (idx % 5) * 0.3
    low = prices - 1 - ((idx + 2) % 4) * 0.25
    talib.ATR(high, low, prices, 14)
    talib.HT_TRENDLINE(prices)
    talib.MAMA(prices, 0.5, 0.05)


def worker(s):
    prices = make_series(s)
    panel(prices)
    return float(prices[-1])


seeds = list(range(1, series_count + 1))
workers = os.cpu_count()

for s in seeds:
    worker(s)  # warmup


def timed(name, run):
    times = []
    for _ in range(3):
        start = time.perf_counter()
        run()
        times.append((time.perf_counter() - start) * 1000)
    return name, statistics.median(times)


results = [
    timed("panel-sequential", lambda: [worker(s) for s in seeds]),
    timed(
        "panel-threads",
        lambda: list(ThreadPoolExecutor(max_workers=workers).map(worker, seeds)),
    ),
]

with ProcessPoolExecutor(max_workers=workers) as pool:
    list(pool.map(worker, seeds))  # warm the pool
    results.append(timed("panel-processes", lambda: list(pool.map(worker, seeds))))

seq = results[0][1]
for name, ms in results:
    print(f"{name}\t{series_count}x{size}\t{round(ms, 1)}")
print(f"workers\t{workers}")
for name, ms in results[1:]:
    print(f"speedup-{name}\t{round(seq / ms, 2)}")
