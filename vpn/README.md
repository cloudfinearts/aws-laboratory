# VPN

## Site-to-site VPN
https://www.fosstechnix.com/aws-site-to-site-vpn-using-terraform/

Go to created VGW (private gateway) and download Openswan configuration sample

Follow steps for Tunnel 1 on on-prem VM

sudo systemctl start ipsec
sudo journalctl -u ipsec -f

sudo cat /etc/ipsec.d/aws.conf
conn Tunnel1
	authby=secret
	auto=start
	left=%defaultroute
	leftid=3.144.34.244
	right=18.184.229.111
	type=tunnel
	ikelifetime=8h
	keylife=1h
	#phase2alg=aes128-sha1;modp1024
	#ike=aes128-sha1;modp1024
	#auth=esp
	#keyingtries=%forever
	keyexchange=ike
	leftsubnet=192.168.1.0/24
	rightsubnet=10.0.1.0/24
	dpddelay=10
	dpdtimeout=30
	dpdaction=restart_by_peer

leftsubnet is on-prem cidr
righsubnet is cloud cidr
commented out params are a must, otherwise got an auth error

Got green on Tunnel 1 in VGW

VGW IP address can be found on Site-to-Site VPN connection -> Tunnel state -> Outside address