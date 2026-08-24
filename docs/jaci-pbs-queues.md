# JACI PBS queue limits

This page records the PBS queue limits observed on JACI on 24 August 2026.
The scheduler configuration is authoritative and may change independently of
this repository. Always query PBS before changing queue or walltime defaults.

## Current queue limits

The following values were obtained with `qstat -Qf`:

| Queue | Maximum walltime | Enabled | Started | MONAN-JEDI placement |
|---|---:|:---:|:---:|---|
| `workq` | not reported | no | no | not applicable |
| `aux` | 24:00:00 | yes | yes | shared; documented exception |
| `pesqextra` | 08:00:00 | yes | yes | exclusive |
| `pesqhigh` | 06:00:00 | yes | yes | exclusive |
| `pesqmidi` | 02:00:00 | yes | yes | exclusive |
| `pesqmini` | 00:30:00 | yes | yes | exclusive |
| `oper` | 08:00:00 | yes | yes | exclusive |
| `preoper` | 08:00:00 | yes | yes | exclusive |
| `longtime` | 168:00:00 | yes | yes | exclusive |
| `COIDS-SysAdmin` | 72:00:00 | no | no | not applicable |

A listed limit does not by itself grant permission to use a queue. Operational,
pre-operational and administrative queues must only be used by authorized
workloads. Follow current JACI/SESUP allocation and priority guidance when
choosing among enabled research queues.

## MONAN-JEDI defaults

The complete configured JEDI/MPAS-JEDI suite currently contains approximately
2294 tests after the configured exclusions. A serial run reached only test 696
when `pesqmini` terminated it at its 30-minute limit. For that reason, the JACI
default for `test-pbs` is:

```yaml
pbs:
  queue: pesqmidi
  ncpus: 64
  walltime: "02:00:00"
```

Two hours is the maximum accepted by `pesqmidi`, not a guarantee that every
future suite will finish. If the inventory or runtime grows beyond this limit,
select an authorized longer research queue and document the reason rather than
requesting an invalid walltime from `pesqmidi`.

## Exclusive-node policy

JACI requires exclusive placement for jobs submitted to compute-node queues:

```text
#PBS -l place=excl
```

The `aux` queue is the documented sharing exception and does not receive this
directive. MONAN-JEDI adds or omits the directive automatically and validates
the generated PBS script before `qsub`.

## Verify the live scheduler configuration

List queue summaries:

```bash
qstat -Q
```

Show the relevant limits and state:

```bash
qstat -Qf | grep -E \
  'Queue:|resources_max.walltime|resources_default.walltime|enabled|started'
```

Inspect one queue in full:

```bash
qstat -Qf pesqmidi
```

When diagnosing a submitted job, inspect its terminal scheduler record:

```bash
qstat -xf JOB_ID | grep -E \
  'job_state|Exit_status|comment|resources_used.walltime'
```

An `Exit_status` of `-29` accompanied by an exceeded-walltime comment means
PBS terminated the job before CTest could write its final summary. The
`test-pbs-result` command recognizes and reports this as `TIMEOUT`.
