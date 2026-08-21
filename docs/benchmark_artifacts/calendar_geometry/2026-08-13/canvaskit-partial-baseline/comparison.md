# Calendar boundary benchmark comparison

Reference: `fd1d6ed-canvaskit-partial`  
Candidate: `5ff6600-canvaskit-partial`  
Platform: `web`  
Repetitions: `5`  
Refresh rate: `60.00 Hz`  
Frame budget: `16.667 ms`  
Hard gate: **FAIL**

| Scenario | Build p95 | Raster p95 | Jank | Anchor max | Handoff b/r | Collector s/c | Handoff body b/l/p | Probe p95 effect |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| compact_empty | 5.00 [4.80, 5.30] ms → 5.00 [4.90, 5.20] ms | 13.20 [12.50, 13.80] ms → 11.50 [10.90, 13.00] ms | 3.64% → 3.04% | 0.000 → 0.000 px | 13.50/21.70 ms | 0.0/0.0 | 0/0/4 | -3.9%/+1.8% |
| compact_event_heavy | 5.60 [5.40, 5.70] ms → 5.20 [5.20, 5.80] ms | 16.30 [14.50, 16.60] ms → 15.50 [14.80, 16.60] ms | 5.00% → 4.37% | 0.000 → 0.000 px | 4.50/28.00 ms | 0.0/0.0 | 0/0/4 | -3.7%/-3.3% |
| details_empty | 5.30 [5.20, 5.40] ms → 5.00 [4.90, 5.20] ms | 11.10 [10.00, 11.80] ms → 10.70 [10.50, 11.10] ms | 2.97% → 2.99% | 0.000 → 0.000 px | 5.70/12.20 ms | 0.0/0.0 | 0/0/3 | +1.9%/+3.6% |
| details_event_heavy | 5.10 [5.00, 5.20] ms → 5.20 [5.10, 5.30] ms | 15.00 [14.00, 16.00] ms → 14.50 [14.10, 14.70] ms | 3.33% → 3.08% | 0.000 → 0.000 px | 5.20/13.50 ms | 0.0/0.0 | 0/0/1 | -3.8%/-2.8% |

## Today

| Scenario | Build p95 | Raster p95 | Jank | Reached | A→B max | B→C max | Probe build/raster p95 effect |
| --- | ---: | ---: | ---: | :---: | ---: | ---: | ---: |
| far_past | 116.80 [112.10, 126.20] ms → 112.10 [107.60, 118.50] ms | 52.30 [44.70, 59.20] ms → 47.50 [46.20, 63.40] ms | 40.00% → 40.00% | yes | 0.000 px | 0.000 px | +7.6%/-7.6% |
| near_target | 111.70 [106.50, 118.20] ms → 106.10 [105.70, 108.00] ms | 36.50 [33.80, 37.90] ms → 35.00 [33.20, 38.20] ms | 50.00% → 30.00% | yes | 0.000 px | 0.000 px | +0.8%/+1.1% |
| unhydrated_early | 153.00 [148.70, 159.30] ms → 161.30 [153.70, 175.70] ms | 50.70 [49.10, 73.80] ms → 78.90 [52.60, 85.80] ms | 37.50% → 37.50% | no | 0.000 px | 0.000 px | -7.2%/-33.7% |
| unhydrated_late | 148.10 [144.90, 157.40] ms → 154.40 [151.80, 163.50] ms | 48.60 [47.00, 72.80] ms → 60.60 [49.20, 66.70] ms | 50.00% → 66.67% | no | 0.000 px | 0.000 px | -4.7%/+6.3% |

Today arrival contract: **FAIL**

Hard regressions:
- details_event_heavy: build_p99_ms candidate range is 7.30 ms slower than the reference range
- today/unhydrated_early: raster_p95_ms_change_percent=55.62%
- today/unhydrated_late: raster_p95_ms_change_percent=24.69%
- today/unhydrated_late: janky_frame_percentage_delta=16.67 points
