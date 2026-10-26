"""A Synthexis culture's growth (the user, 2026-10-25: "I want to see the sigmoid"), from the farm scenario's growth mix
(growth.jsonl, a record a minute): its incubators and technicians over time, and what it drank and spent a minute.

Run: uv run --with matplotlib python3 -I scripts/growth_plot.py <growth.jsonl> <out.png>
"""
import json
import sys

import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt


def main():
    rows = [json.loads(l) for l in open(sys.argv[1]) if l.strip()]
    m = [r["minute"] for r in rows]
    fig, (a, b) = plt.subplots(2, 1, figsize=(8, 6.4), dpi=110, sharex=True)
    a.plot(m, [r["pens"] for r in rows], color="#8a9e00", lw=2, label="incubators")
    a.plot(m, [r["techs"] for r in rows], color="#5a2a86", lw=2, label="technicians")
    a.plot(m, [r["tumors"] for r in rows], color="#999999", lw=1, ls=":", label="tumors")
    a.set_ylabel("count", fontsize=9)
    a.legend(fontsize=8, loc="upper left")
    a.set_title("A Synthexis culture's growth (farm scenario, growth mix)", fontsize=10)

    def rate(key):
        out = [0]
        for i in range(1, len(rows)):
            out.append((rows[i].get(key) or 0) - (rows[i - 1].get(key) or 0))
        return out
    income = [d + t for d, t in zip(rate("drunk"), rate("trickled"))]
    b.plot(m, income, color="#2e8b3a", lw=1.5, label="biomass earned a minute (drunk and trickled)")
    b.plot(m, rate("spent"), color="#c0392b", lw=1.5, label="biomass spent a minute")
    b.set_ylabel("biomass a minute", fontsize=9)
    b.set_xlabel("minute", fontsize=9)
    b.legend(fontsize=8, loc="upper left")
    for ax in (a, b):
        ax.tick_params(labelsize=8)
        ax.grid(alpha=0.25)
    fig.tight_layout()
    fig.savefig(sys.argv[2])
    print(f"wrote {sys.argv[2]}: {len(rows)} minutes")


if __name__ == "__main__":
    main()
