require 'logger'
require 'net/http'
require 'uri'
require 'json'
require 'logger'
require 'openssl'
require 'date'
require	'kubeclient'

current_exchanges_completed = 0

label = "project=camel-springboot-logger"
server = "https://10.1.2.2"
port = 8443
namespace = "dashing"
tokenFilename = "/var/run/secrets/kubernetes.io/serviceaccount/token"
mbean = URI::encode('org.apache.camel:context=MyCamel,type=routes,name="route1"/getExchangesCompleted()')

log = Logger.new(STDOUT)
log.level = Logger::INFO

log.info("checking for token file") 
#get the token for kubernetes access in the pod..!
if File.exists?(tokenFilename) then 
  log.info("token file does exist")
  token = IO.read(tokenFilename) 
else
  # just putting my current token here to test
  token = "sKxDTx5qvwQAKV9GJ8CxDn9nsM2kihTD6BTt_gWtf00"
  log.info("token file does not exist") 
end

# setup kube client
ssl_options = { verify_ssl: OpenSSL::SSL::VERIFY_NONE }
auth_options = {
    bearer_token: token
  }
client = Kubeclient::Client.new "#{server}:#{port}/api/" , 'v1',
                                  ssl_options: ssl_options, auth_options: auth_options
#every 10s
SCHEDULER.every '10s' do  

  last_exchanges_completed = current_exchanges_completed

  podName = ""
  #call kube api to get the pod name
  kubepods = client.get_pods(namespace: namespace, label_selector: label)
  metricValue = 0



  kubepods.each do | item |

    podName = item["metadata"]["name"]
    
    log.info("camel-springboot-data podname: #{podName}")

    # setup http
    url = URI.parse("#{server}/api/v1/namespaces/#{namespace}/pods/https:#{podName}:8778/proxy/jolokia/exec/#{mbean}")
    http = Net::HTTP.new(url.host, port)
    http.use_ssl = (url.scheme == 'https')
    http.verify_mode = OpenSSL::SSL::VERIFY_NONE
    response = http.request(Net::HTTP::Get.new(url.request_uri, {'Authorization' => "Bearer #{token}"}))
    j = JSON[response.body]
    current_exchanges_completed = j["value"]

    log.info("metricValue = #{current_exchanges_completed}")

  end

  send_event('camel-springboot-logger-exchanges', { current: current_exchanges_completed, last: last_exchanges_completed })

end