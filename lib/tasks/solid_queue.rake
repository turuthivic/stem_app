namespace :solid_queue do
  desc "Clean up orphaned Solid Queue jobs (jobs without execution records)"
  task cleanup_orphaned_jobs: :environment do
    puts "Checking for orphaned Solid Queue jobs..."

    # Find jobs that:
    # 1. Haven't finished (finished_at is nil)
    # 2. Are past their scheduled time
    # 3. Don't have any execution records (scheduled/ready/claimed)
    orphaned_jobs = SolidQueue::Job.where(finished_at: nil)
                                    .where("scheduled_at <= ?", 5.minutes.ago)
                                    .select do |job|
      # Check if job has any execution records
      !SolidQueue::ScheduledExecution.exists?(job_id: job.id) &&
        !SolidQueue::ReadyExecution.exists?(job_id: job.id) &&
        !SolidQueue::ClaimedExecution.exists?(job_id: job.id)
    end

    if orphaned_jobs.empty?
      puts "✓ No orphaned jobs found!"
      next
    end

    puts "Found #{orphaned_jobs.count} orphaned job(s):"
    orphaned_jobs.each do |job|
      args = job.arguments["arguments"]&.first
      resource_info = if args.is_a?(Hash) && args["_aj_globalid"]
                        args["_aj_globalid"]
                      else
                        "Unknown resource"
                      end

      puts "  - Job #{job.id} (#{job.class_name}): #{resource_info}"
      puts "    Scheduled: #{job.scheduled_at}"
      puts "    Age: #{((Time.current - job.scheduled_at) / 60).round(1)} minutes ago"
    end

    puts "\nCleaning up orphaned jobs..."

    cleaned_count = 0
    re_enqueued_count = 0
    failed_count = 0

    orphaned_jobs.each do |job|
      begin
        # Try to extract the resource (AudioFile) from job arguments
        args = job.arguments["arguments"]&.first
        resource = nil

        if args.is_a?(Hash) && args["_aj_globalid"]
          # Parse GlobalID to get the model
          gid = GlobalID.parse(args["_aj_globalid"])
          resource = gid.find rescue nil
        end

        # Delete the orphaned job
        job.delete
        cleaned_count += 1

        # If the resource still exists and is in a state that needs processing, re-enqueue
        if resource.is_a?(AudioFile)
          if resource.uploaded? || resource.processing?
            # Check if there's already an active separation job
            active_jobs = resource.separation_jobs.active

            if active_jobs.empty?
              puts "  ✓ Re-enqueueing job for AudioFile ##{resource.id} (#{resource.title})"
              AudioSeparationJob.perform_later(resource)
              re_enqueued_count += 1
            else
              puts "  ✓ Skipped re-enqueueing for AudioFile ##{resource.id} (already has active job)"
            end
          else
            puts "  ✓ Cleaned job for AudioFile ##{resource.id} (status: #{resource.status})"
          end
        else
          puts "  ✓ Cleaned orphaned job (resource no longer exists)"
        end

      rescue => e
        puts "  ✗ Error cleaning job #{job.id}: #{e.message}"
        failed_count += 1
      end
    end

    puts "\n" + "=" * 60
    puts "Cleanup Summary:"
    puts "  Total orphaned jobs: #{orphaned_jobs.count}"
    puts "  Successfully cleaned: #{cleaned_count}"
    puts "  Re-enqueued: #{re_enqueued_count}"
    puts "  Failed: #{failed_count}"
    puts "=" * 60
  end

  desc "Check Solid Queue health and report any issues"
  task health_check: :environment do
    puts "Solid Queue Health Check"
    puts "=" * 60

    # Check workers
    active_workers = SolidQueue::Process.where(kind: "Worker")
                                        .where("last_heartbeat_at > ?", 1.minute.ago)
    puts "Active Workers: #{active_workers.count}"

    # Check dispatchers
    active_dispatchers = SolidQueue::Process.where(kind: "Dispatcher")
                                            .where("last_heartbeat_at > ?", 1.minute.ago)
    puts "Active Dispatchers: #{active_dispatchers.count}"

    # Check job queues
    total_jobs = SolidQueue::Job.where(finished_at: nil).count
    ready_jobs = SolidQueue::ReadyExecution.count
    claimed_jobs = SolidQueue::ClaimedExecution.count
    scheduled_jobs = SolidQueue::ScheduledExecution.count

    puts "\nJob Queue Status:"
    puts "  Total unfinished jobs: #{total_jobs}"
    puts "  Ready to run: #{ready_jobs}"
    puts "  Currently running: #{claimed_jobs}"
    puts "  Scheduled for later: #{scheduled_jobs}"

    # Check for potential orphans
    potential_orphans = total_jobs - (ready_jobs + claimed_jobs + scheduled_jobs)
    if potential_orphans > 0
      puts "\n⚠️  WARNING: #{potential_orphans} potential orphaned job(s) detected!"
      puts "   Run 'rails solid_queue:cleanup_orphaned_jobs' to clean up"
    else
      puts "\n✓ No orphaned jobs detected"
    end

    # Check for stuck jobs (claimed for more than 30 minutes)
    stuck_executions = SolidQueue::ClaimedExecution.where("created_at < ?", 30.minutes.ago)
    if stuck_executions.any?
      puts "\n⚠️  WARNING: #{stuck_executions.count} job(s) stuck in claimed state for >30 minutes"
      puts "   These jobs may have crashed. Consider restarting Solid Queue workers."
    end

    puts "=" * 60
  end

  desc "Clean up old completed and failed jobs (older than 7 days)"
  task cleanup_old_jobs: :environment do
    cutoff = 7.days.ago
    puts "Cleaning up completed/failed Solid Queue jobs older than #{cutoff}..."

    old_jobs = SolidQueue::Job.where("finished_at < ?", cutoff)
    count = old_jobs.count

    if count.zero?
      puts "✓ No old jobs to clean up"
    else
      old_jobs.delete_all
      puts "✓ Deleted #{count} old job record(s)"
    end
  end
end
