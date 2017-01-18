require 'net/http'
require 'uri'
require 'json'

server = "https://10.1.2.2"
#server = "https://kubernetes.default.svc"
port = 8443
namespace = "dashing"
tokenFilename = "/var/run/secrets/kubernetes.io/serviceaccount/token"

log = Logger.new(STDOUT)
log.level = Logger::INFO

log.info("checking for token file")	
#get the token for kubernetes access in the pod..!
if File.exists?(tokenFilename) then 
	log.info("token file does exist")
	token = IO.read(tokenFilename) 
else
  # just putting my current token here to test
  token = "fodpW7RlF_TgMq4kUITGRNc-yrjQXXg6spmyk0vAnjI"
	log.info("token file does not exist")	
end

# setup table columns
hrows = [
  { cols: [ {value: 'PodName'}, {value: 'Status'}, {value: 'RestartCount'} ] }
]

# setup http
url = URI.parse("#{server}/api/v1/namespaces/#{namespace}/pods")
http = Net::HTTP.new(url.host, port)
http.use_ssl = (url.scheme == 'https')
http.verify_mode = OpenSSL::SSL::VERIFY_NONE

#every 10s
SCHEDULER.every '10s' do

  pods = []
  #query kube API
  response = http.request(Net::HTTP::Get.new(url.request_uri, {'Authorization' => "Bearer #{token}"}))

  # Convert to JSON
  j = JSON[response.body]

  j["items"].each do | item |
	#podname, phase, restarts
    thispod = { cols: [ {value: item["metadata"]["name"]}, {value: item["status"]["phase"]}, {value: item["status"]["containerStatuses"][0]["restartCount"].to_s}]}
    pods.push(thispod)
  end

  send_event('pods', { hrows: hrows, rows: pods } )
end