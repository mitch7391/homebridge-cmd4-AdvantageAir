# Legacy MyZone selection backend

This increment adds no HomeKit accessory or simulator scenario.

## Eligibility and identity

Selection is available only when valid controller data already reports an
installer-configured MyZone: a positive, unambiguous reference to a
temperature-controlled zone. Zero never enables MyZone.

Requests carry existing stable aircon and zone identities. Fresh discovery
resolves current aircon addressing; the zone's reported number supplies
info.myZone. Numbers are never inferred from keys or names. Existing discovery
includes zone keys in zone identity; changed keys are not guessed to be the same
zone. Missing identities, invalid capabilities and ambiguous reference numbers
prevent dispatch.

There is no disable or selector-Off command.

## Ordered operation

The coordinator uses its existing queue and serialized client transport:

1. Read fresh data; open the chosen zone if necessary and confirm it.
2. Read fresh data; select its reported number if necessary and confirm it.
3. Read fresh data; copy its current target to the main target if necessary and
   confirm it.

Each step is sent at most once. A step already satisfied by fresh observations
needs no write. Previous confirmed conditions must remain satisfied before
progression; they are not automatically reasserted if external changes undo them.
The reported number is bound once transmission begins.

An open step confirms open state. Selection confirms the number and open state.
Target synchronization confirms the number, open state and exact main target;
a zone-target change during that write prevents confirmation. Airflow reaching
100 percent or measured-temperature changes are not confirmation requirements.

## Fractional targets

A finite existing zone target from 16 through 32 C is copied unchanged, including
fractional values. Thermostat whole-degree input normalization is separate.
Controller-side exact target alignment can make the final write unnecessary.

No undocumented rounding or relaxed equality is applied. If firmware reports a
different main target, synchronization fails visibly without retry or rollback.
Simulator results cannot establish real MyZone firmware normalization.

## Partial outcomes and concurrency

Valid readbacks are published before request-specific confirmation checks.
A zone may remain open after selection fails. A newly selected MyZone remains
the authoritative observed reference after target synchronization fails.
No automatic rollback is attempted and no old snapshot is restored.

Pending selection reads reflect the latest admitted selection. When it finishes
or fails, reads return the actual observed selection rather than faulting a known
reference merely because target synchronization failed.

Progress events distinguish open, select and target steps. Confirmed/already
satisfied steps are debug logs; dispatch remains normal logging. Failure warnings
identify the failed step and earlier confirmed writes where available. Full
success is emitted only after the complete operation.

Unsent selections coalesce per aircon. A transmitted operation reconciles before
a later selection executes. Thermostat temperature requests remain independent
queue entries and replan against the selection observed when their turn arrives.
Other controls retain existing queue order.

Explicit rejection fails. Ambiguous delivery is reconciled by reading without
resending. Existing cancellation of queued work after an unreconciled write is
retained; independent observed state is not reverted.

## Bounds and validation limits

Admission retains the 90-second observation-freshness limit and 30-second intent
lifetime. The existing 15-second execution budget covers the entire ordered
selection, including preflights and confirmations. It is not reset for each step.
HTTP requests retain their existing limit and cancellation signal.

A slow multi-step operation can therefore finish partially. These budgets are
engineering limits, not manufacturer guarantees. Shutdown prevents later writes,
progress publication and confirmation.

Automated tests cover planning, exact transport, queue interactions, partial
outcomes, ambiguous delivery, fractional mismatch, deadlines and shutdown.
Real installer-enabled MyZone hardware is still needed to validate firmware
normalization and the suitability of the total execution budget.
