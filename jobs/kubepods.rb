require 'logger'
require 'net/http'
require 'uri'
require 'json'
require 'logger'
require 'openssl'
require 'date'
require	'kubeclient'

server = "https://10.1.2.2"
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


hrows = [
  { cols: [ {value: 'PodName'}, {value: 'Status'}, {value: 'RestartCount'} ] }
]

# setup kube client
ssl_options = { verify_ssl: OpenSSL::SSL::VERIFY_NONE }
auth_options = {
    bearer_token: token
  }
client = Kubeclient::Client.new "#{server}:#{port}/api/" , 'v1',
                                  ssl_options: ssl_options, auth_options: auth_options
#every 10s
SCHEDULER.every '10s' do  

  pods = []
  #call kube api
  kubepods = client.get_pods(namespace: namespace)
  
  kubepods.each do | item |
    thispod = { cols: [ {value: item["metadata"]["name"]}, {value: item["status"]["phase"]}, {value: item["status"]["containerStatuses"][0]["restartCount"].to_s}]}
    pods.push(thispod)
  end

  send_event('kubepods', { hrows: hrows, rows: pods } )
end