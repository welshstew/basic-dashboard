require 'logger'
require 'net/http'
require 'uri'
require 'json'
require 'logger'
require 'openssl'
require 'date'
require	'kubeclient'

stats = ['Uptime', 'State', 'MinProcessingTime', 'MaxProcessingTime', 'LastProcessingTime', 'TotalRoutes', 'TotalProcessingTime'] 
stat_values = Hash.new({ value: 0 })


label = "project=camel-springboot-logger"
server = "https://10.1.2.2"
port = 8443
namespace = "dashing"
tokenFilename = "/var/run/secrets/kubernetes.io/serviceaccount/token"

postBody = '''{"attribute": ["Uptime","State","MinProcessingTime","MaxProcessingTime","LastProcessingTime","TotalRoutes","TotalProcessingTime"],"mbean": "org.apache.camel:context=MyCamel,type=context,name=\"MyCamel\"","type": "read"}'''


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
SCHEDULER.every '15s' do  

  podName = ""
  #call kube api to get the pod name
  kubepods = client.get_pods(namespace: namespace, label_selector: label)
  metricValue = 0



  kubepods.each do | item |

    podName = item["metadata"]["name"]

    uri = URI.parse("#{server}/api/v1/namespaces/#{namespace}/pods/https:#{podName}:8778/proxy/jolokia/")
    http = Net::HTTP.new(uri.host, port)
    http.use_ssl = (uri.scheme == 'https')
    http.verify_mode = OpenSSL::SSL::VERIFY_NONE
    req = Net::HTTP::Post.new(uri.path, {'Authorization' => "Bearer #{token}", 'Content-Type' => 'application/json'})
    req.body = postBody
    res = http.request(req)

    log.info(res.body)

    j = JSON[res.body]

    stats.each do | stat |

      stat_values[stat] = { label: stat, value: j["value"][stat] }

    end

  end

  send_event('camelstats', { items: stat_values.values })

end