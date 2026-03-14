# Solid Queue Maintenance

This document explains how to maintain and troubleshoot Solid Queue background jobs in the stem_app application.

## Orphaned Jobs Issue

### What are Orphaned Jobs?

Orphaned jobs are background jobs that exist in the `solid_queue_jobs` table but don't have corresponding execution records (`scheduled_executions`, `ready_executions`, or `claimed_executions`). This can happen when:

- The database transaction is interrupted during job creation
- The dispatcher crashes between creating the job and execution records
- Multiple Solid Queue instances are competing with stale data
- Server restarts or deployments during job scheduling

### Symptoms

- Audio files stuck in "uploaded" status
- Jobs visible in database but not processing
- Workers running but no jobs being executed

### Prevention

The application includes **automated prevention** via:

1. **Recurring Cleanup Job**: `SolidQueueCleanupJob` runs automatically:
   - **Development**: Every 30 minutes
   - **Production**: Every 15 minutes

2. **Automatic Recovery**: The cleanup job will:
   - Detect orphaned jobs (>5 minutes old without execution records)
   - Delete orphaned job records
   - Re-enqueue jobs for AudioFiles still needing processing
   - Skip jobs for deleted or completed AudioFiles

## Manual Maintenance Tasks

### Check Queue Health

```bash
bin/rails solid_queue:health_check
```

This will show:
- Active workers and dispatchers
- Job queue status
- Potential orphaned jobs
- Stuck jobs (running >30 minutes)

### Clean Up Orphaned Jobs

```bash
bin/rails solid_queue:cleanup_orphaned_jobs
```

This will:
- Find all orphaned jobs
- Show details about each orphaned job
- Clean up and re-enqueue where appropriate
- Provide a summary of actions taken

### Clean Up Old Completed Jobs

```bash
bin/rails solid_queue:cleanup_old_jobs
```

Removes completed/failed job records older than 7 days to keep the database clean.

## Monitoring

### View Active Jobs

```ruby
# In Rails console
SolidQueue::Job.where(finished_at: nil).count
SolidQueue::ReadyExecution.count
SolidQueue::ClaimedExecution.count
```

### View Worker Status

```bash
ps aux | grep solid-queue
```

Should show:
- `solid-queue-supervisor`: Manages worker processes
- `solid-queue-dispatcher`: Dispatches jobs to workers
- `solid-queue-worker`: Executes jobs

### Check Logs

```bash
tail -f log/development.log | grep -i "solid\|worker"
```

## Troubleshooting

### Jobs Not Processing

1. **Check if workers are running**:
   ```bash
   ps aux | grep solid-queue
   ```

2. **If no workers, ensure bin/dev is running**:
   ```bash
   bin/dev
   ```

3. **Check for orphaned jobs**:
   ```bash
   bin/rails solid_queue:health_check
   ```

4. **Clean up if needed**:
   ```bash
   bin/rails solid_queue:cleanup_orphaned_jobs
   ```

### Stuck Jobs

If jobs are stuck in "claimed" status for >30 minutes:

1. **Check the worker logs** for errors
2. **Restart Solid Queue** (stop and start `bin/dev`)
3. **Run health check** to assess the situation
4. **Consider manual intervention**:
   ```ruby
   # In Rails console
   stuck_job = SolidQueue::ClaimedExecution.where('created_at < ?', 30.minutes.ago).first
   stuck_job&.job&.delete  # Remove stuck job
   ```

### Multiple Old Worker Processes

Sometimes old worker processes persist after crashes:

```bash
# Find old solid-queue processes
ps aux | grep solid-queue

# Kill specific processes (replace PID with actual process ID)
kill -9 PID
```

Then restart with `bin/dev`.

## Configuration Files

- **Queue Config**: `config/queue.yml` - Worker and dispatcher settings
- **Recurring Jobs**: `config/recurring.yml` - Scheduled maintenance tasks
- **Cleanup Job**: `app/jobs/solid_queue_cleanup_job.rb`
- **Rake Tasks**: `lib/tasks/solid_queue.rake`

## Best Practices

1. **Always run via `bin/dev`** in development to ensure all processes start
2. **Monitor the health check** periodically in production
3. **Review logs** after deployments to catch any issues early
4. **Let the automated cleanup run** - it's designed to handle most issues
5. **For production**, consider setting up alerting when orphaned jobs exceed a threshold
