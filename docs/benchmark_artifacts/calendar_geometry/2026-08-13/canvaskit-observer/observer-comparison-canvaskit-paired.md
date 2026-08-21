# Calendar dormant-harness observer check

Harness reverted: `harness-reverted-canvaskit`  
Harness present/inactive: `harness-present-canvaskit`  
Result: **PASS**

| Metric | Reverted | Present/inactive | Change |
| --- | ---: | ---: | ---: |
| build p95_ms | 5.600 ms | 5.500 ms | -1.79% |
| build p99_ms | 106.800 ms | 104.300 ms | -2.34% |
| raster p95_ms | 15.300 ms | 17.401 ms | +13.73% |
| raster p99_ms | 44.600 ms | 43.700 ms | -2.02% |
| janky frames | 5.12% | 7.09% | +1.97 pp |

Paired-median gate statistics: build p95 +0.00%, raster p95 -1.73%, jank +0.38 pp.
