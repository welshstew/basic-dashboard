
require 'logger'
require 'date'

log = Logger.new(STDOUT)
log.level = Logger::INFO
milliseconds = DateTime.now.strftime('%Q') # "1384526946523" (milliseconds)

SCHEDULER.every '2s' do
	log.info(milliseconds)
end