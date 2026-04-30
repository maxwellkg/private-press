threads_count = ENV.fetch("RAILS_MAX_THREADS", 3)
threads threads_count, threads_count

environment ENV.fetch("RAILS_ENV", "development")

port ENV.fetch("PORT", 3000)
plugin :tmp_restart

# Run the Solid Queue supervisor inside Puma for single-server deployments.
plugin :solid_queue if ENV["SOLID_QUEUE_IN_PUMA"]
