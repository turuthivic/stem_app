class SolidQueueCleanupJob < ApplicationJob
  queue_as :default

  # This job runs periodically to clean up orphaned Solid Queue jobs
  # Orphaned jobs are jobs that exist in solid_queue_jobs but have no
  # corresponding execution records (scheduled/ready/claimed)

  def perform
    Rails.logger.info "SolidQueueCleanupJob: Starting orphaned job cleanup"

    # Find orphaned jobs (>5 minutes old, not finished, no execution records)
    orphaned_jobs = SolidQueue::Job.where(finished_at: nil)
                                    .where("scheduled_at <= ?", 5.minutes.ago)
                                    .select do |job|
      !SolidQueue::ScheduledExecution.exists?(job_id: job.id) &&
        !SolidQueue::ReadyExecution.exists?(job_id: job.id) &&
        !SolidQueue::ClaimedExecution.exists?(job_id: job.id)
    end

    if orphaned_jobs.empty?
      Rails.logger.info "SolidQueueCleanupJob: No orphaned jobs found"
      return
    end

    Rails.logger.info "SolidQueueCleanupJob: Found #{orphaned_jobs.count} orphaned jobs"

    cleaned_count = 0
    re_enqueued_count = 0

    orphaned_jobs.each do |job|
      begin
        # Extract resource from job arguments
        args = job.arguments["arguments"]&.first
        resource = nil

        if args.is_a?(Hash) && args["_aj_globalid"]
          gid = GlobalID.parse(args["_aj_globalid"])
          resource = gid.find rescue nil
        end

        # Delete the orphaned job
        job.delete
        cleaned_count += 1

        # Re-enqueue if resource exists and needs processing
        if resource.is_a?(AudioFile) && (resource.uploaded? || resource.processing?)
          active_jobs = resource.separation_jobs.active

          if active_jobs.empty?
            Rails.logger.info "SolidQueueCleanupJob: Re-enqueueing job for AudioFile ##{resource.id}"
            AudioSeparationJob.perform_later(resource)
            re_enqueued_count += 1
          end
        end

      rescue => e
        Rails.logger.error "SolidQueueCleanupJob: Error cleaning job #{job.id}: #{e.message}"
      end
    end

    Rails.logger.info "SolidQueueCleanupJob: Cleaned #{cleaned_count} jobs, re-enqueued #{re_enqueued_count}"
  end
end
