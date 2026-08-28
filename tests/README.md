# SQL test suite

The portfolio version includes executable SQL Server smoke and regression tests.

## Execution order

Run the database scripts first:

1. `database/01-create-database.sql`
2. `database/02-schema.sql`
3. `database/03-seed-data.sql`
4. `database/04-functions.sql`
5. `database/05-stored-procedures.sql`
6. `database/06-triggers.sql`

Then execute the tests:

1. `tests/01-functions-smoke-tests.sql`
2. `tests/02-stored-procedures-smoke-tests.sql`
3. `tests/03-trigger-smoke-tests.sql`
4. `tests/04-end-to-end-regression-tests.sql`

Each test script ends with an explicit `OK - ... passed.` message when successful.

## What is covered

### Functions

- email validation;
- document validation;
- service-number formatting;
- ticket state transitions;
- age calculation;
- effective resolution time;
- SLA compliance.

### Stored procedures

- person creation and duplicate-document validation;
- prospect modification;
- service creation and person-state promotion;
- service validation rules;
- ticket creation and initial history;
- activity creation;
- ticket reassignment;
- owner-only ticket operations;
- legal ticket state progression;
- resolution and closure timestamps;
- service deactivation and person-state demotion.

### Trigger

- no notification on ticket creation;
- notification on real ticket state changes;
- no notification on unrelated updates;
- no notification for same-state assignment;
- multi-row UPDATE support.

### End-to-end and integrity regression

- complete customer/service/ticket lifecycle;
- history and notification counts;
- composite ticket/service ownership foreign key;
- person-document uniqueness;
- positive SLA check;
- ticket date consistency;
- service/typology compatibility;
- seeded SLA regression scenario.

## Transaction behavior

Test-created entity rows are rolled back.

SQL Server sequences are not transactional, so `dbo.Seq_NumeroServicio` can advance during tests. Gaps in generated service numbers are therefore expected and are not considered test failures.
