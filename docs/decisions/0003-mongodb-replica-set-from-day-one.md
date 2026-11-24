# 0003: MongoDB as a single-member replica set
**Decision:** Run MongoDB with a replica-set name and keyFile from the start, even with one member.
**Why:** Adding secondaries later becomes an `rs.add()` instead of a migration, and change-stream and oplog features are available.
**Consequences:** Slightly more initial setup; failover still requires additional members.
