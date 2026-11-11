| Feature | Behavior |
|---|---|
| Data width / depth | Positive `DATA_WIDTH` and `DEPTH` parameters (default 8 bits / 8 entries) |
| Clock | All operations occur on the rising edge |
| Reset | Synchronous, active high; clears pointers, count and output |
| Write accepted | `wr_en && !full` |
| Read accepted | `rd_en && !empty` |
| Read output | Registered; updates after an accepted read and otherwise holds |
| Both enabled, partially filled | Accept both; occupancy stays unchanged |
| Both enabled, empty | Accept write only; no direct forwarding |
| Both enabled, full | Accept read only; write is rejected |
| Invalid operation | Ignore it; preserve stored data |
