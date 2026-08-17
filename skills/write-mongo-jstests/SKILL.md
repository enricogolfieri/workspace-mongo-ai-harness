---
name: write-mongo-jstests
description: Write focused MongoDB jstests with explicit mocha cases, small mechanical topology helpers, purposeful comments, robust teardown, and correct ownership. Use when authoring or restructuring a test under jstests/ or src/mongo/**/jstests/.
user-invocable: true
---

# Writing MongoDB jstests

Apply these rules when creating or restructuring a MongoDB JavaScript test.

## 1. Explicit Scenarios

Use mocha-style `describe` and `it` from `jstests/libs/mochalite.js`.

Each independently meaningful scenario gets its own `it`. Do not hide scenarios in a table, loop, or
generic operation matrix. Do not put multiple operations under test in one case when each operation
has a separate requirement.


## 2. Helpers

Keep helpers minimal. Stay as explicit as possible and use helpers only for repetitive task that include several operations. 


## 3. Comments And Spacing

Comments must explain non-obvious topology intent or mark the three meaningful phases of a case.
Keep comments short. Every phase comment must have a blank line before it, and the next phase must be
separated by a blank line after the preceding assertion. Use this exact visual structure in every
positive case:

```js
// Setup is above this section.

// Drop the sessions collection on the new first shard.
assert.commandWorked(configDB.runCommand({drop: "system.sessions"}));
assert.eq(null, configDB.collections.findOne({_id: kSessionsNs}));

// Run the transaction after the drop.
session.startTransaction();
// ... operation and assertion ...

// Verify the sessions collection remains available.
assertSessionsCollectionTracked();
```
