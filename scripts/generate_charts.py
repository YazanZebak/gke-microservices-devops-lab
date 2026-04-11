import matplotlib.pyplot as plt
import matplotlib.ticker as ticker

# Aggregated results from locust_stats.csv across all runs
data = {
    "users":  [10,  50,  100, 200],
    "p50":    [25,  31,  70,  260],
    "p95":    [73,  130, 290, 830],
    "p99":    [110, 220, 820, 1300],
    "rps":    [2.18, 10.97, 21.58, 41.32],
}

# ── Chart 1: Latency percentiles ──────────────────────────────────────────────
fig, ax = plt.subplots(figsize=(8, 5))

ax.plot(data["users"], data["p50"], marker="o", linewidth=2, label="p50")
ax.plot(data["users"], data["p95"], marker="o", linewidth=2, label="p95")
ax.plot(data["users"], data["p99"], marker="o", linewidth=2, label="p99")

ax.axvspan(100, 200, alpha=0.08, color="red", label="Saturation zone")

ax.set_xlabel("Concurrent Users")
ax.set_ylabel("Response Time (ms)")
ax.set_title("Response Time vs Load")
ax.set_xticks(data["users"])
ax.yaxis.set_minor_locator(ticker.AutoMinorLocator())
ax.grid(axis="y", linestyle="--", alpha=0.4)
ax.legend()

fig.tight_layout()
fig.savefig("docs/charts/latency_vs_load.png", dpi=150)
plt.close()
print("Saved: docs/charts/latency_vs_load.png")

# ── Chart 2: Throughput ───────────────────────────────────────────────────────
fig, ax = plt.subplots(figsize=(8, 5))

ax.plot(data["users"], data["rps"], marker="o", linewidth=2, color="steelblue")
ax.axvspan(100, 200, alpha=0.08, color="red")

ax.set_xlabel("Concurrent Users")
ax.set_ylabel("Requests per Second")
ax.set_title("Throughput vs Load")
ax.set_xticks(data["users"])
ax.grid(axis="y", linestyle="--", alpha=0.4)

fig.tight_layout()
fig.savefig("docs/charts/throughput_vs_load.png", dpi=150)
plt.close()
print("Saved: docs/charts/throughput_vs_load.png")

# ── Chart 3: Per-endpoint p95 ─────────────────────────────────────────────────
endpoints = {
    "GET /":             [70,  190, 380,  1100],
    "GET /cart":         [54,  120, 290,  810],
    "POST /cart":        [100, 170, 280,  910],
    "POST /checkout":    [95,  130, 200,  680],
    "POST /setCurrency": [74,  160, 310,  740],
}

fig, ax = plt.subplots(figsize=(8, 5))

for name, values in endpoints.items():
    ax.plot(data["users"], values, marker="o", linewidth=2, label=name)

ax.axvspan(100, 200, alpha=0.08, color="red", label="Saturation zone")

ax.set_xlabel("Concurrent Users")
ax.set_ylabel("p95 Response Time (ms)")
ax.set_title("p95 Latency per Endpoint vs Load")
ax.set_xticks(data["users"])
ax.grid(axis="y", linestyle="--", alpha=0.4)
ax.legend(fontsize=8)

fig.tight_layout()
fig.savefig("docs/charts/p95_per_endpoint.png", dpi=150)
plt.close()
print("Saved: docs/charts/p95_per_endpoint.png")
