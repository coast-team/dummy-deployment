#!/usr/bin/ruby
# Import the Distem module
require 'distem'
# The path to the compressed filesystem image
# We can point to local file since our homedir is available from NFS
FSIMG="file:///home/qlaportechabasse/distem/dummy_image.tar.gz"
# raise 'This experiment requires at least two physical machines' unless pnodes.size >= 2
# The first argument of the script is the address (in CIDR format)
# of the virtual network to set-up in our platform
# This ruby hash table describes our virtual network
GATEWAY  = '10.147.255.254'
OUTPUT = '/tmp/ip_addresses.txt'

vnet = {
  'name' => 'testnet',
  'address' => ARGV[0]
}
ifname = 'if0'
nodelist = []
writer = 40

(1..writer).collect do |i|
    node = {
        'name' => "dummy#{i}",
        'address' => nil
    }
    nodelist.push(node)
end
# Read SSH keys
private_key = IO.readlines('/root/.ssh/id_rsa').join
public_key = IO.readlines('/root/.ssh/id_rsa.pub').join
sshkeys = {
  'private' => private_key,
  'public' => public_key
}
# Connect to the Distem server (on http://localhost:4567 by default)
Distem.client do |cl|
  # Put the physical machines that have been assigned to you
  # You can get that by executing: cat $OAR_NODE_FILE | uniq
  pnodes = cl.pnodes_info

  pnodes_list = pnodes.map{ |p| p[0]}

  if pnodes_list.length > nodelist.length then
      ratio = 1
      rest = 0
      pnodes_list = pnodes_list[0, nodelist.length]
  else
      ratio = nodelist.length / pnodes_list.length
      rest = nodelist.length % pnodes_list.length
  end

  # Create an array of number of virtual nodes deployed on each corresponding physical node
  last_index = (pnodes_list.length) -1
  pnodes_ratio_list = (0..last_index).collect{ratio}

  rest.times do
      pnodes_list
  end

  # Distribute fairly the rest of the ratio
  rest.times do |index|
      pnodes_ratio_list[index] += 1
  end

  cursor = 0

  puts '=== Creating virtual network ==='
  #Start by creating the virtual network
  cl.vnetwork_create(vnet['name'], vnet['address'])
  #Creating one virtual node per physical one
  puts '=== Creating virtual nodes ==='
  pnodes_ratio_list.each_with_index{ |ratio, index|
      ratio.times do
          nodename = nodelist[cursor]['name']
          puts "Creating node named #{nodename} -- #{pnodes_list[index]}"
          cl.vnode_create(nodename, { 'host' => pnodes_list[index] }, sshkeys)
          cl.vfilesystem_create(nodename, { 'image' => FSIMG })
          cl.viface_create(nodename, ifname, { 'vnetwork' => vnet['name'], 'default' => 'true' })
          cursor += 1
      end
  }

  puts '=== Starting virtual nodes ==='
  # Starting the virtual nodes using the asynchronous method
  nodenamelist = []
  nodelist.each { |node|
      nodenamelist.push(node['name'])
  }

  cl.vnodes_start!(nodenamelist)

  vnodes_state = nodenamelist.collect {|x| cl.vnode_info(x)["status"]}
  nb_running = vnodes_state.count("RUNNING")
  old_nb = -1
  while nb_running != vnodes_state.size do
    if old_nb < nb_running
      puts "Remain to be ran : #{vnodes_state.size-nb_running} left"
    end
    vnodes_state = nodenamelist.collect {|x| cl.vnode_info(x)["status"]}
    old_nb = nb_running
    nb_running = vnodes_state.count("RUNNING")
    sleep 1
  end

  puts "=== Running configuration scripts ==="
  nodelist.each { |node|
      node['address'] = cl.viface_info(node['name'], ifname)['address'].split('/')[0]
      cl.vnode_execute(node['name'], "/etc/init.d/ntp start")
      puts "NTP service is running on #{node['name']}"

      cl.vnode_execute(node['name'], "ifconfig #{ifname} #{node['address']} netmask 255.252.0.0")
      cl.vnode_execute(node['name'], "route add default gw #{GATEWAY} dev #{ifname}")
      cl.vnode_execute(node['name'], "cp /home/resolv.conf /etc/")
      cl.vnode_execute(node['name'], "echo \"127.0.0.1 localhost\" >> /etc/hosts")
      puts "Connection to www allowed for #{node['name']}"

  }
  puts "==== Deployment finished ==="

  File.open(OUTPUT, 'w') { |file|
      file.truncate(0)
      nodelist.each { |node|
          file.write("#{node['address']}\n")
      }
  }
  puts "=== Output is written in #{OUTPUT} ==="
end
