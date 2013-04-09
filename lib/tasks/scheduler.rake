desc 'Property: Retry not found'
task :property_retry_not_found => :environment do
  Property.delay.retry_not_found
end

desc 'Property: Queue next batch'
task :property_queue_next_batch => :environment do
  Property.delay.queue_download_for_next_batch
end
