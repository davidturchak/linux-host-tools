#!/usr/bin/env python3

import krest
import requests
import argparse
import socket

requests.packages.urllib3.disable_warnings(requests.packages.urllib3.exceptions.InsecureRequestWarning)

def main(sdp_ip, password, vol_prefix, host_obj, vol_num):
    try:
        # Check if SDP IP is a valid IP address
        socket.inet_aton(sdp_ip)
    except socket.error:
        print("Invalid SDP IP address provided.")
        return

    try:
        ep = krest.EndPoint(sdp_ip, username='admin', password=password, ssl_validate=False)

        # creating vg
        vg = ep.new("volume_groups", name=vol_prefix, quota=0).save() # no limit
        
        # getting a host object
        hosts = ep.search('hosts', name=host_obj).hits

        # if host object is not exist on SDP create it
        if not hosts:
            host = ep.new("hosts", name=host_obj, type="Linux").save()
        else:
            host = hosts[0]
        # creating vols
        for i in range(vol_num):
            vol = ep.new("volumes", name="{}{}".format(vol_prefix, i+1), size=10*2**20, volume_group=vg).save()         
            mapping = ep.new("mappings", volume=vol, host=host).save()
    except Exception as e:
        print(f"An error occurred: {e}")

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description='Script to do something.')
    parser.add_argument('--sdp_ip', '-s', type=str, required=True, help='SDP floating or PMC IP to connect to')
    parser.add_argument('--password', '-p', type=str, required=True, help='Password to connect to SDP')
    parser.add_argument('--host_obj', '-o', type=str, required=False, default=socket.gethostname(), help='Host object to map volumes to [default: hostname]')
    parser.add_argument('--vol_prefix', '-f', type=str, required=False, default='DEMO', help='Prefix for created objects [default: DEMO]')
    parser.add_argument('--vol_num', '-n', type=int, required=False, default=4, help='Number of volumes to create [default: 4]')
    args = parser.parse_args()

    main(args.sdp_ip, args.password, args.vol_prefix, args.host_obj, args.vol_num)
