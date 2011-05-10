# = Jobs controller
#
# == States
# A job can be in one of the following states:
#
# scheduled::   Scheduled to be sent to the Transcoder instances
# accepted::    Accepted by a Transcoder instance, waiting to start processing
# processing::  Being processed by a Transcoder Instance
# \on_hold::    Waiting for a Transcoder to become responsive again
# success::     Successfully completed
# failed::      An error occured
#
# == Pagination
# For methods that use pagination, a <tt>page</tt> parameters can be sent to display that particular page of jobs.
# Jobs are paginated with 20 jobs per page.
# For example, to get the 5th page of successfully completed jobs, use:
#   http://host.com/api/jobs.json?page=5
class Api::JobsController < Api::ApiController
  # == Returns a list of recent jobs
  # This method uses pagination.
  def index;        jobs_index(Job.scoped); end
  # == Returns a list of scheduled jobs
  # Scheduled jobs are created, but not yet accepted by the transcoders.
  # This method uses pagination.
  def scheduled;    jobs_index(Job.scheduled); end
  # == Returns a list of accepted jobs
  # Accepted jobs are accepted by a \Transcoder, but have not yet begun transcoding.
  # This method uses pagination.
  def accepted;     jobs_index(Job.accepted); end
  # == Returns a list of jobs being processed.
  # Jobs being processed are being transcoded by a \Transcoder.
  # This method uses pagination.
  def processing;   jobs_index(Job.processing); end
  # == Returns a list of jobs that are on hold
  # Jobs will be put on hold when a \Transcoder instance is unavailable.
  # This method uses pagination.
  def on_hold;      jobs_index(Job.on_hold); end
  # == Returns a list of successfully completed jobs
  # These jobs have been successfully transcoded.
  # This method uses pagination.
  def success;      jobs_index(Job.success); end
  alias_method :completed, :success
  # == Returns a list of failed jobs
  # Jobs become failed if the \Transcoder reports an error.
  # This method uses pagination.
  def failed;       jobs_index(Job.failed); end
  
  # == Creates a job
  #
  # Creates a job using the specified parameters, which are all required. If the request was valid,
  # the created job is returned. If the request could not be completed, a list of errors will be returned.
  #
  # === Parameters
  # input:: Input file to process
  # output:: Output file to write to
  # preset:: Preset name to use
  #
  # === Response codes
  # success:: <tt>201 created</tt>
  # failed::  <tt>406 Unprocessable Entity</tt>
  #
  # === Example
  #   $ curl -d 'input=/tmp/foo.flv&output=/tmp/bar.mp4&preset=h264' http://localhost:3000/api/jobs
  #
  #   {
  #     "job": {
  #       "callback_url":"http://localhost:3000/api/jobs/26",
  #       "completed_at":null,
  #       "created_at":"2011-05-10T08:25:00Z",
  #       "destination_file":"/tmp/bar.mp4",
  #       "duration":null,
  #       "filesize":null,
  #       "host_id":1,
  #       "id":26,
  #       "message":null,
  #       "preset_id":1,
  #       "progress":null,
  #       "remote_job_id":"fa832776a64b6844fb9f1a244757734a9d83c00f",
  #       "source_file":"/tmp/foo.flv",
  #       "state":"accepted",
  #       "transcoding_started_at":"2011-05-10T08:25:03Z",
  #       "updated_at":"2011-05-10T08:25:03Z" 
  #     }
  #   }  
  def create
    job = Job.from_api(params, :callback_url => lambda { |job| api_job_url(job) })
    if job.valid?
      response.headers["X-State-Changes-Location"] = api_state_changes_url(job)
      respond_with job, :location => api_job_url(job) do |format|
        format.html { redirect_to jobs_path }
      end
    else
      respond_with job do |format|
        format.html { @job = job; render "/jobs/new"}
      end
    end
  end
  
  # == Updates a job with attributes from the transcoder
  #
  # This endpoint is specifically for updating a job from the transcoder and should not be called manually.
  def update #:nodoc:
    job = Job.find(params[:id])
    job.enter(params[:status], params)
    respond_with job, :location => api_job_url(job)
  end
  
  # == Shows a job
  #
  # The displayed job will have its status updated to provide an up-to-date view of attributes.
  #
  # === Parameters
  # id:: The id of the job to show
  #
  # === Example
  #   {
  #     "job": {
  #       "callback_url":"http://localhost:3000/api/jobs/26",
  #       "completed_at":null,
  #       "created_at":"2011-05-10T08:25:00Z",
  #       "destination_file":"/tmp/bar.mp4",
  #       "duration":null,
  #       "filesize":null,
  #       "host_id":1,
  #       "id":26,
  #       "message":null,
  #       "preset_id":1,
  #       "progress":null,
  #       "remote_job_id":"fa832776a64b6844fb9f1a244757734a9d83c00f",
  #       "source_file":"/tmp/foo.flv",
  #       "state":"accepted",
  #       "transcoding_started_at":"2011-05-10T08:25:03Z",
  #       "updated_at":"2011-05-10T08:25:03Z" 
  #     }
  #   }
  def show
    job = Job.find(params[:id])
    job.update_status
    respond_with job
  end
  
  private #:nodoc:
    def jobs_index(jobs)
      jobs = jobs.order("created_at DESC").page(params[:page]).per(20)
      jobs.select(&:unfinished?).map(&:update_status)
      respond_with jobs
    end
end
