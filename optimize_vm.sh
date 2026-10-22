#!/usr/bin/env bash
# VM Memory Optimization & Watchdog Script
# Automatically tunes Linux kernel, manages swap, cleans bloat, and prevents OOM crashes
#
# Usage:
#   ./optimize_vm.sh          — Full optimization (default on boot)
#   ./optimize_vm.sh --watch  — Memory pressure watchdog (runs in background)
#   ./optimize_vm.sh --quick  — Fast cleanup (no swap, no disk scan)

set -uo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROFILE_DIR="$DIR/profile"
CACHE_DIR="${HOME:-/root}/.cache"

# ─────────────────────────────────────────────────────────────
# Memory pressure watchdog mode
# Polls every 15s, takes escalating action as memory drops
# ─────────────────────────────────────────────────────────────
if [[ "${1:-}" == "--watch" ]]; then
    echo "[watchdog] Starting memory pressure watchdog (PID $$)..."
    CONSECUTIVE_CRITICAL=0

    while true; do
        AVAIL_MB=$(awk '/MemAvailable/ {printf "%d", $2/1024}' /proc/meminfo 2>/dev/null || echo 2048)
        TIMESTAMP=$(date '+%H:%M:%S')

        if [[ "$AVAIL_MB" -lt 200 ]]; then
            # EMERGENCY: Under 200MB — drop caches and trim excess renderers
            CONSECUTIVE_CRITICAL=$((CONSECUTIVE_CRITICAL + 1))
            echo "$TIMESTAMP 🚨 EMERGENCY: ${AVAIL_MB}MB avail (streak: $CONSECUTIVE_CRITICAL)"

            # Drop ALL caches immediately
            sudo sh -c 'sync; echo 3 > /proc/sys/vm/drop_caches' 2>/dev/null || true

            # Kill old Chrome renderers beyond the newest one
            RENDERER_PIDS=$(pgrep -f 'chrome.*--type=renderer' 2>/dev/null | head -n -1 || true)
            for pid in $RENDERER_PIDS; do
                echo "$TIMESTAMP   Trimming idle renderer PID $pid"
                kill -9 "$pid" 2>/dev/null || true
            done

            # Flush temporary Chrome disk caches
            rm -rf /tmp/chrome-cache/* 2>/dev/null || true

            # If 3+ consecutive critical events, restart Chrome GPU process
            if [[ "$CONSECUTIVE_CRITICAL" -ge 3 ]]; then
                echo "$TIMESTAMP   Recycling Chrome GPU process (3+ consecutive critical)"
                pkill -9 -f 'chrome.*--type=gpu' 2>/dev/null || true
            fi

            sleep 5

        elif [[ "$AVAIL_MB" -lt 500 ]]; then
            CONSECUTIVE_CRITICAL=0
            echo "$TIMESTAMP ⚠️  LOW: ${AVAIL_MB}MB avail — dropping page+dentry caches"
            sudo sh -c 'sync; echo 3 > /proc/sys/vm/drop_caches' 2>/dev/null || true

            # Mark any new Chrome renderers as deprioritized
            for pid in $(pgrep -f 'chrome.*--type=renderer' 2>/dev/null); do
                sudo sh -c "echo 300 > /proc/$pid/oom_score_adj" 2>/dev/null || true
            done

            sleep 10

        elif [[ "$AVAIL_MB" -lt 1000 ]]; then
            CONSECUTIVE_CRITICAL=0
            # Moderate pressure — drop pagecache
            sudo sh -c 'sync; echo 1 > /proc/sys/vm/drop_caches' 2>/dev/null || true
            sleep 15

        else
            CONSECUTIVE_CRITICAL=0
            sleep 20
        fi
    done
    exit 0
fi

# ─────────────────────────────────────────────────────────────
# Quick cleanup mode (skip swap + disk scan)
# ─────────────────────────────────────────────────────────────
QUICK=false
if [[ "${1:-}" == "--quick" ]]; then
    QUICK=true
fi

echo "🔧 VM Memory Optimization"
echo "========================="

# 1. Create swap if not present
if ! swapon --show 2>/dev/null | grep -q swap; then
    echo "📦 Checking swap space..."
    # /tmp is typically ext4/ext3; fall back to dd if fallocate fails on overlayfs
    if sudo fallocate -l 2G /tmp/swapfile 2>/dev/null || sudo dd if=/dev/zero of=/tmp/swapfile bs=1M count=2048 status=none 2>/dev/null; then
        sudo chmod 600 /tmp/swapfile 2>/dev/null || true
        sudo mkswap /tmp/swapfile >/dev/null 2>&1 || true
        if sudo swapon /tmp/swapfile 2>/dev/null; then
            echo "   ✅ Swap enabled (2GB at /tmp/swapfile)"
        else
            echo "   ⚠️  Swap activation skipped (container restricted)"
        fi
    fi
else
    echo "   ✅ Swap already active"
fi

# 2. Kernel tuning — high-efficiency parameters for virtual workstation
echo "⚙️  Tuning kernel parameters..."
sudo sysctl -q vm.swappiness=10                 2>/dev/null || true
sudo sysctl -q vm.vfs_cache_pressure=200         2>/dev/null || true
sudo sysctl -q vm.dirty_ratio=10                 2>/dev/null || true
sudo sysctl -q vm.dirty_background_ratio=5       2>/dev/null || true
sudo sysctl -q vm.dirty_expire_centisecs=500     2>/dev/null || true
sudo sysctl -q vm.overcommit_memory=1            2>/dev/null || true
sudo sysctl -q vm.min_free_kbytes=65536          2>/dev/null || true
sudo sysctl -q vm.oom_kill_allocating_task=1     2>/dev/null || true
sudo sysctl -q kernel.panic_on_oom=0             2>/dev/null || true
sudo sysctl -q vm.watermark_boost_factor=0       2>/dev/null || true
sudo sysctl -q vm.compaction_proactiveness=50    2>/dev/null || true
echo "   ✅ Kernel tuned (overcommit=1, min_free=64MB, oom_kill_allocating=1)"

# 3. Cache cleanup
echo "🧹 Cleaning caches..."
FREED=0

# Playwright / Headless caches if present
for cache_path in "$CACHE_DIR/ms-playwright" "$CACHE_DIR/google-chrome-headless" "$CACHE_DIR/selenium"; do
    if [ -d "$cache_path" ]; then
        SIZE=$(du -sm "$cache_path" 2>/dev/null | awk '{print $1}')
        rm -rf "$cache_path" 2>/dev/null || true
        FREED=$((FREED + ${SIZE:-0}))
    fi
done

# npm & pip cache
command -v npm &>/dev/null && npm cache clean --force >/dev/null 2>&1 && echo "   🗑️  npm cache" || true
command -v pip &>/dev/null && pip cache purge >/dev/null 2>&1 && echo "   🗑️  pip cache" || true

# Chrome disk cache
if [ -d /tmp/chrome-cache ]; then
    SIZE=$(du -sm /tmp/chrome-cache 2>/dev/null | awk '{print $1}')
    rm -rf /tmp/chrome-cache/* 2>/dev/null || true
    FREED=$((FREED + ${SIZE:-0}))
    [ "${SIZE:-0}" -gt 0 ] 2>/dev/null && echo "   🗑️  Chrome disk cache: ${SIZE}MB"
fi

# Chrome profile bloat (non-essential data stores)
if [ -d "$PROFILE_DIR" ]; then
    for dir in component_crx_cache WasmTtsEngine WidevineCdm "Safe Browsing" \
               OnDeviceHeadSuggestModel BrowserMetrics extensions_crx_cache \
               "Crowd Deny" ZxcvbnData CertificateRevocation hyphen-data \
               segmentation_platform OptimizationHints "Subresource Filter" \
               PKIMetadata SafetyTips optimization_guide_model_store MEIPreload \
               GraphiteDawnCache SSLErrorAssistant GPUPersistentCache ActorSafetyLists; do
        if [ -d "$PROFILE_DIR/$dir" ]; then
            SIZE=$(du -sm "$PROFILE_DIR/$dir" 2>/dev/null | awk '{print $1}')
            rm -rf "$PROFILE_DIR/$dir" 2>/dev/null || true
            FREED=$((FREED + ${SIZE:-0}))
        fi
    done

    # Per-profile render caches
    for profile in "Default" "Profile 1"; do
        for cache in "Cache" "Code Cache" "GPUCache" "DawnWebGPUCache" "DawnGraphiteCache" \
                     "Service Worker/CacheStorage" "Shared Dictionary" "Sessions" "WebStorage"; do
            rm -rf "$PROFILE_DIR/$profile/$cache" 2>/dev/null || true
        done
    done
    echo "   🗑️  Chrome profile bloat cleared"
fi

# Python bytecode
if [[ "$QUICK" == "false" ]]; then
    find "$DIR" -name __pycache__ -type d -exec rm -rf {} + 2>/dev/null || true
fi

# 4. Drop page cache + dentries + inodes
sudo sh -c 'sync; echo 3 > /proc/sys/vm/drop_caches' 2>/dev/null || true

# 5. Protect VM infrastructure processes from OOM killer
for pid in $(pgrep Xvnc 2>/dev/null); do sudo sh -c "echo -800 > /proc/$pid/oom_score_adj" 2>/dev/null || true; done
for pid in $(pgrep -f gateway.js 2>/dev/null); do sudo sh -c "echo -800 > /proc/$pid/oom_score_adj" 2>/dev/null || true; done
for pid in $(pgrep cloudflared 2>/dev/null); do sudo sh -c "echo -800 > /proc/$pid/oom_score_adj" 2>/dev/null || true; done
for pid in $(pgrep openbox 2>/dev/null); do sudo sh -c "echo -500 > /proc/$pid/oom_score_adj" 2>/dev/null || true; done
for pid in $(pgrep tint2 2>/dev/null); do sudo sh -c "echo -500 > /proc/$pid/oom_score_adj" 2>/dev/null || true; done
for pid in $(pgrep autocutsel 2>/dev/null); do sudo sh -c "echo -500 > /proc/$pid/oom_score_adj" 2>/dev/null || true; done

# Chrome renderers and utilities
for pid in $(pgrep -f 'chrome.*--type=renderer' 2>/dev/null); do sudo sh -c "echo 300 > /proc/$pid/oom_score_adj" 2>/dev/null || true; done
for pid in $(pgrep -f 'chrome.*--type=utility' 2>/dev/null); do sudo sh -c "echo 200 > /proc/$pid/oom_score_adj" 2>/dev/null || true; done

echo ""
echo "📊 Results:"
echo "   Disk freed: ~${FREED}MB"
free -h 2>/dev/null | awk 'NR==2{printf "   RAM: %s total, %s used, %s available\n", $2, $3, $7}' || true
swapon --show 2>/dev/null | tail -1 | awk '{printf "   Swap: %s (used: %s)\n", $3, $4}' || true
echo ""
echo "✅ Optimization complete"
